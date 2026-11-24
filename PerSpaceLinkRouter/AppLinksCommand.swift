//
//  AppLinksCommand.swift
//  PerSpaceLinkRouter
//
//  `PerSpaceLinkRouter app-links <command>`, answered before the app starts
//  its run loop: no window, menu bar item, updater, or default-browser
//  change. The commands only read; none writes the config file or
//  preferences.
//

import AppKit

enum AppLinksCommand {

    static let name = "app-links"

    static let usage = """
        Usage: PerSpaceLinkRouter app-links <command>

          list          Every rule in use, in match order: on/off, id, name,
                        built-in or custom, and whether its app is installed.
          gallery       The built-in rules that are not in use: id, name, and
                        whether its app is installed. Add one by putting its
                        id in "order" and "enabled".
          test <url>    Which rule catches the link and the URL the app receives,
                        or that it goes to the browser. Opens nothing.
          check         Validates the config file. Exits 1 and lists the errors
                        when it is invalid.
          path          Prints the config file's path.

        The config file is \(AppLinkConfigFile.fileName); set \(AppLinkConfigFile.environmentKey)
        to use another path.
        """

    /// The exit status when `arguments` is an app-links command, or nil to
    /// launch the app normally. Only `<binary> app-links ...` counts, so
    /// launches with arguments from macOS (`-psn_...`, `-NSDocumentRevisionsDebugMode YES`)
    /// are unaffected.
    static func run(arguments: [String]) -> Int32? {
        guard arguments.count >= 2, arguments[1] == name else {
            return nil
        }
        let rest = Array(arguments.dropFirst(2))
        let fileURL = AppLinkConfigFile.defaultURL()
        switch rest.first {
        case "list" where rest.count == 1:
            return list(fileURL: fileURL)
        case "gallery" where rest.count == 1:
            return gallery(fileURL: fileURL)
        case "test" where rest.count == 2:
            return test(rest[1], fileURL: fileURL)
        case "check" where rest.count == 1:
            return check(fileURL: fileURL)
        case "path" where rest.count == 1:
            print(fileURL.path)
            return 0
        case "help", "-h", "--help":
            print(usage)
            return 0
        default:
            printError(usage)
            return 2
        }
    }

    // MARK: - Commands

    private static func check(fileURL: URL) -> Int32 {
        switch AppLinkConfigFile.read(fileURL) {
        case .missing:
            print("\(fileURL.lastPathComponent): no file; the starting rules are in use")
            return 0
        case .unreadable(let message):
            printError("\(fileURL.lastPathComponent): can't be read: \(message)")
            return 1
        case .data(let data):
            do {
                let config = try AppLinkConfigParser.parse(data)
                let rules = config.resolvedRules()
                let custom = config.customRules.count
                let enabled = rules.filter(\.isEnabled).count
                print("\(fileURL.lastPathComponent): ok, \(custom) custom rule\(custom == 1 ? "" : "s"), \(enabled) of \(rules.count) rules on")
                return 0
            } catch let error as AppLinkConfigError {
                printError("\(fileURL.lastPathComponent): \(error.issues.count) error\(error.issues.count == 1 ? "" : "s")")
                for issue in error.issues {
                    printError("  \(issue)")
                }
                return 1
            } catch {
                printError("\(fileURL.lastPathComponent): \(error)")
                return 1
            }
        }
    }

    private static func list(fileURL: URL) -> Int32 {
        guard let rules = loadRules(fileURL: fileURL) else {
            return 1
        }
        let rows = rules.map { rule -> [String] in
            [rule.isEnabled ? "on" : "off",
             rule.id,
             rule.name,
             AppLinkCatalog.isBuiltIn(rule) ? "built-in" : "custom",
             AppLinkRouter.isInstalled(rule) ? "installed" : "not installed"]
        }
        printTable(rows)
        return 0
    }

    private static func gallery(fileURL: URL) -> Int32 {
        guard let rules = loadRules(fileURL: fileURL) else {
            return 1
        }
        let rows = AppLinkCatalog.galleryRules(notIn: rules).map { rule -> [String] in
            [rule.id, rule.name, AppLinkRouter.isInstalled(rule) ? "installed" : "not installed"]
        }
        printTable(rows)
        return 0
    }

    private static func test(_ urlString: String, fileURL: URL) -> Int32 {
        guard let rules = loadRules(fileURL: fileURL) else {
            return 1
        }
        switch AppLinkMatcher.match(urlString, rules: rules, isInstalled: AppLinkRouter.isInstalled, reportUnavailable: true) {
        case let .app(rule, url):
            print("\(rule.id) → \(url.absoluteString)")
        case .browser(unavailable: let rule?):
            print("browser")
            let reason = rule.isEnabled ? "its app is not installed" : "it is off"
            print("note: \(rule.id) matches, but \(reason)")
        case .browser(unavailable: nil):
            print("browser")
        }
        return 0
    }

    // MARK: - Helpers

    /// The rules the app uses with the file as it is now. An invalid file
    /// is reported instead, since the running app keeps its last good rules,
    /// which this process can't see.
    private static func loadRules(fileURL: URL) -> [AppLinkRule]? {
        switch AppLinkConfigFile.read(fileURL) {
        case .missing:
            // Before the file exists, the enabled set is in the app's
            // preferences.
            let enabled = UserDefaults.standard.enabledAppLinkRuleIdentifiers
            return AppLinkConfig.fallback(enabledIdentifiers: enabled).resolvedRules()
        case .unreadable(let message):
            printError("\(fileURL.lastPathComponent): can't be read: \(message)")
            return nil
        case .data(let data):
            do {
                return try AppLinkConfigParser.parse(data).resolvedRules()
            } catch {
                printError("\(fileURL.lastPathComponent) is invalid; run `app-links check` for the errors.")
                return nil
            }
        }
    }

    private static func printTable(_ rows: [[String]]) {
        guard let columns = rows.first?.count else {
            return
        }
        let widths = (0..<columns).map { column in rows.map { $0[column].count }.max() ?? 0 }
        for row in rows {
            let cells = row.enumerated().map { column, cell in
                column == columns - 1 ? cell : cell.padding(toLength: widths[column], withPad: " ", startingAt: 0)
            }
            print(cells.joined(separator: "  "))
        }
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

}
