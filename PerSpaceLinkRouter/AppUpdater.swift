//
//  AppUpdater.swift
//  PerSpaceLinkRouter
//

import Foundation
import Sparkle

/// Keeps the app up to date with Sparkle.
///
/// Only a release build updates itself. `bin/release` passes the feed address
/// and the public signing key to the build, which writes them into Info.plist.
/// A plain Xcode build leaves both empty and has no updater, so a development
/// copy is never replaced.
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {

    /// Whether this build can update itself.
    let isAvailable: Bool
    /// False while a check is already running.
    @Published private(set) var canCheck = false

    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?

    override init() {
        let info = Bundle.main.infoDictionary
        let feed = info?["SUFeedURL"] as? String ?? ""
        let publicKey = info?["SUPublicEDKey"] as? String ?? ""
        isAvailable = !feed.isEmpty && !publicKey.isEmpty
        super.init()
        guard isAvailable else { return }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        // Sparkle changes this property on the main thread.
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial]) { [weak self] updater, _ in
            self?.canCheck = updater.canCheckForUpdates
        }
    }

    /// Whether Sparkle looks for, downloads and installs updates without asking.
    var updatesAutomatically: Bool {
        get {
            guard let updater = controller?.updater else { return false }
            return updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates
        }
        set {
            objectWillChange.send()
            controller?.updater.automaticallyChecksForUpdates = newValue
            controller?.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Checks now and shows Sparkle's own windows with the result.
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    // Sparkle normally installs a downloaded update when the app quits. A menu
    // bar agent stays open for weeks, so install and relaunch as soon as the
    // update is ready.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        immediateInstallHandler()
        return true
    }

    // A direct launch with a visible Dock icon shows the settings window. The
    // relaunch after an update is not the user opening the app, so mark it and
    // let AppDelegate keep the window closed.
    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        UserDefaults.standard.relaunchedAfterUpdate = true
    }

}
