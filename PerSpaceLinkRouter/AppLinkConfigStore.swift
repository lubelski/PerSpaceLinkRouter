//
//  AppLinkConfigStore.swift
//  PerSpaceLinkRouter
//
//  Loads, watches, and writes app-links.json. Foundation only, so
//  bin/check-app-link-rules can exercise it against a temporary file.
//

import Foundation

enum AppLinkConfigFile {

    static let fileName = "app-links.json"
    /// Overrides the file's location, for tests and for trying a config
    /// without touching the real one.
    static let environmentKey = "PERSPACELINKROUTER_APP_LINKS_FILE"

    /// `~/Library/Application Support/PerSpaceLinkRouter/app-links.json`, or
    /// the path in `PERSPACELINKROUTER_APP_LINKS_FILE`. The app is not
    /// sandboxed, so Application Support is the one in the home folder.
    static func defaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let path = environment[environmentKey], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("PerSpaceLinkRouter", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    enum Contents {
        case missing
        case data(Data)
        case unreadable(String)
    }

    static func read(_ url: URL) -> Contents {
        do {
            return .data(try Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            return .unreadable((error as NSError).localizedDescription)
        }
    }

    /// Writes atomically, creating the folder if needed. Refuses a config
    /// that would not read back, so the app never writes a file it would
    /// reject.
    static func write(_ config: AppLinkConfig, to url: URL) throws -> Data {
        let data = AppLinkConfigSerializer.data(for: config)
        _ = try AppLinkConfigParser.parse(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return data
    }

}

/// The app's live app link config. The file is the source of truth once it
/// exists. Before that, the built-in rules run with the enabled set from
/// UserDefaults, and the first write moves that set into the file.
///
/// A file that fails to parse or validate leaves the last good config in
/// place and records the issues. All work happens on `queue`.
final class AppLinkConfigStore {

    /// Posted on the store's queue when the rules or the issues change.
    static let didChangeNotification = Notification.Name("AppLinkConfigStoreDidChange")

    let fileURL: URL

    /// The config in effect: the last good file, or the fallback.
    private(set) var config: AppLinkConfig
    /// Every rule in match order with `isEnabled` set.
    private(set) var rules: [AppLinkRule]
    /// Whether `config` came from the file rather than the fallback.
    private(set) var isUsingFile = false
    /// Why the file on disk is not in effect, if it isn't. Empty when it is,
    /// or when there is no file.
    private(set) var issues: [AppLinkConfigIssue] = []

    private let fallbackEnabledIdentifiers: () -> Set<String>
    private let queue: DispatchQueue
    private var lastData: Data?
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    /// - Parameter fallbackEnabledIdentifiers: the enabled set kept in
    ///   UserDefaults. It is read only while there is no usable file.
    init(fileURL: URL = AppLinkConfigFile.defaultURL(), queue: DispatchQueue = .main,
         fallbackEnabledIdentifiers: @escaping () -> Set<String>) {
        self.fileURL = fileURL
        self.queue = queue
        self.fallbackEnabledIdentifiers = fallbackEnabledIdentifiers
        config = AppLinkConfig(order: [], enabled: [], customRules: [])
        rules = []
        load(isInitial: true)
    }

    deinit {
        directorySource?.cancel()
        fileSource?.cancel()
        pendingReload?.cancel()
    }

    var fileExists: Bool {
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Reads the file again. Posts `didChangeNotification` when anything changed.
    func reload() {
        load(isInitial: false)
    }

    private func load(isInitial: Bool) {
        let oldConfig = config, oldIssues = issues, oldIsUsingFile = isUsingFile
        switch AppLinkConfigFile.read(fileURL) {
        case .missing:
            lastData = nil
            apply(.fallback(enabledIdentifiers: fallbackEnabledIdentifiers()), fromFile: false)
            issues = []
        case .unreadable(let message):
            lastData = nil
            if isInitial {
                apply(.fallback(enabledIdentifiers: fallbackEnabledIdentifiers()), fromFile: false)
            }
            issues = [AppLinkConfigIssue("can't be read: \(message)")]
        case .data(let data):
            if data == lastData && !isInitial {
                return
            }
            lastData = data
            do {
                apply(try AppLinkConfigParser.parse(data), fromFile: true)
                issues = []
            } catch let error as AppLinkConfigError {
                // Keep the last good rules. At launch there are none yet, so
                // the app behaves as it did before the file existed.
                if isInitial {
                    apply(.fallback(enabledIdentifiers: fallbackEnabledIdentifiers()), fromFile: false)
                }
                issues = error.issues
            } catch {
                issues = [AppLinkConfigIssue("\(error)")]
            }
        }
        if !isInitial && (config != oldConfig || issues != oldIssues || isUsingFile != oldIsUsingFile) {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    private func apply(_ newConfig: AppLinkConfig, fromFile: Bool) {
        config = newConfig
        rules = newConfig.resolvedRules()
        isUsingFile = fromFile
    }

    /// Writes `newConfig` to the file and puts it in effect.
    func save(_ newConfig: AppLinkConfig) throws {
        let data = try AppLinkConfigFile.write(newConfig, to: fileURL)
        lastData = data
        apply(newConfig, fromFile: true)
        issues = []
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        // The write replaced the file, so watch the new one.
        if directorySource != nil {
            armFileSource()
        }
    }

    /// Writes the rules in effect when there is no file yet, which also
    /// moves the UserDefaults enabled set into it. Does nothing when a file
    /// exists, even an invalid one.
    func createFileIfNeeded() throws {
        if !fileExists {
            try save(config)
        }
    }

    // MARK: - Watching

    /// Reloads when the file changes, including when an editor replaces it
    /// with a new file. Watches the folder for files being added, removed,
    /// or renamed, and the file itself for writes in place.
    func startWatching() {
        guard directorySource == nil else {
            return
        }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directorySource = makeSource(path: directory.path, mask: [.write, .rename, .delete]) { [weak self] in
            self?.scheduleReload()
        }
        armFileSource()
        // Catch a change made between the first load and now.
        scheduleReload()
    }

    func stopWatching() {
        directorySource?.cancel()
        directorySource = nil
        fileSource?.cancel()
        fileSource = nil
        pendingReload?.cancel()
        pendingReload = nil
    }

    private func armFileSource() {
        fileSource?.cancel()
        fileSource = makeSource(path: fileURL.path, mask: [.write, .extend, .delete, .rename, .attrib]) { [weak self] in
            self?.scheduleReload()
        }
    }

    /// Changes come in bursts (write, rename, attributes), so reloads wait
    /// briefly for the burst to end. The file source is re-armed each time,
    /// since the file may now be a different one.
    private func scheduleReload() {
        pendingReload?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.directorySource != nil else {
                return
            }
            self.armFileSource()
            self.reload()
        }
        pendingReload = item
        queue.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    private func makeSource(path: String, mask: DispatchSource.FileSystemEvent, handler: @escaping () -> Void) -> DispatchSourceFileSystemObject? {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            return nil
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: mask, queue: queue)
        source.setEventHandler(handler: handler)
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

}
