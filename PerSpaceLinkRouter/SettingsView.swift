//
//  SettingsView.swift
//  PerSpaceLinkRouter
//

import AppKit
import CoreServices
import ServiceManagement
import SwiftUI

class SettingsModel: ObservableObject {

    enum AutomationStatus {
        case granted
        case denied
        case notDetermined
        case unknown
    }

    private let browserManager: BrowserManager
    private let defaults = UserDefaults.standard

    // Set by AppDelegate: flipping the Dock icon needs an activation policy
    // change and re-fronting the window, which are app-level concerns.
    var onHideDockIconChange: (() -> Void)?

    @Published private(set) var browsers: [BrowserDescription] = []
    @Published private(set) var targetBrowserBundleIdentifier = ""
    @Published private(set) var isDefaultBrowser = false
    @Published private(set) var isAccessibilityGranted = false
    @Published private(set) var automationStatus = AutomationStatus.unknown
    @Published private(set) var hideDockIcon = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var activationDelay = 0
    @Published private(set) var appLinkRules: [AppLinkRuleDescription] = []

    init(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }

    var targetBrowserName: String {
        return browsers.first { $0.bundleIdentifier == targetBrowserBundleIdentifier }?.name ?? "the browser"
    }

    func refresh() {
        browsers = browserManager.browserDescriptions
        targetBrowserBundleIdentifier = defaults.targetBrowserBundleIdentifier
            ?? browsers.first { $0.isTargetBrowser }?.bundleIdentifier
            ?? browsers.first?.bundleIdentifier
            ?? ""
        isDefaultBrowser = browserManager.isDefaultBrowser
        isAccessibilityGranted = AXIsProcessTrusted()
        automationStatus = automationStatus(for: targetBrowserBundleIdentifier)
        hideDockIcon = defaults.hideDockIcon
        launchAtLogin = SMAppService.mainApp.status == .enabled
        activationDelay = Int(defaults.activationDelayInterval)
        appLinkRules = browserManager.appLinkRouter.installedRuleDescriptions
    }

    func setAppLinkRule(identifier: String, enabled: Bool) {
        browserManager.appLinkRouter.setRule(identifier: identifier, enabled: enabled)
        appLinkRules = browserManager.appLinkRouter.installedRuleDescriptions
    }

    func setTargetBrowser(bundleIdentifier: String) {
        browserManager.setTargetBrowser(bundleIdentifier: bundleIdentifier)
        refresh()
    }

    func setDefaultBrowser() {
        // Persist the current selection so a target browser is set by the time
        // links start arriving.
        browserManager.setTargetBrowser(bundleIdentifier: targetBrowserBundleIdentifier)
        browserManager.setDefaultBrowser { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func setHideDockIcon(_ hide: Bool) {
        defaults.hideDockIcon = hide
        hideDockIcon = hide
        onHideDockIconChange?()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update login item: \(error)")
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }

    func setActivationDelay(_ seconds: Int) {
        defaults.activationDelayInterval = TimeInterval(seconds)
        activationDelay = seconds
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    func openAutomationSettings() {
        openPrivacyPane("Privacy_Automation")
    }

    private func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // Automation grants are per target application, and the permission can
    // only be queried without prompting while that application is running.
    private func automationStatus(for bundleIdentifier: String) -> AutomationStatus {
        guard !bundleIdentifier.isEmpty,
              !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty,
              let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier).aeDesc else {
            return .unknown
        }
        switch AEDeterminePermissionToAutomateTarget(target, typeWildCard, typeWildCard, false) {
        case noErr:
            return .granted
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        default:
            return .denied
        }
    }

}

// The Settings window's pages. The sidebar and the window around them are in
// SettingsWindow.swift; the App Links page is in AppLinksSettingsView.swift.

struct GeneralSettingsView: View {

    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Open links with", selection: browserSelection) {
                    ForEach(model.browsers, id: \.bundleIdentifier) { browser in
                        HStack {
                            Image(nsImage: SettingsIcon.small(browser.image))
                            Text(browser.name)
                        }
                        .tag(browser.bundleIdentifier)
                    }
                }
                LabeledContent("Default browser") {
                    if model.isDefaultBrowser {
                        SettingsStatus.granted("PerSpaceLinkRouter")
                    } else {
                        Button("Set PerSpaceLinkRouter as Default…") {
                            model.setDefaultBrowser()
                        }
                    }
                }
            }
            Section {
                Stepper(value: activationDelay, in: 0...60, step: 5) {
                    LabeledContent("Activation delay", value: "\(model.activationDelay) s")
                }
            } footer: {
                SettingsFooter("When links open within this many seconds of the last one, the browser window isn't brought forward again.")
            }
            Section {
                Toggle("Hide Dock icon", isOn: Binding(
                    get: { model.hideDockIcon },
                    set: { model.setHideDockIcon($0) }))
                Toggle("Start at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }))
            }
        }
        .formStyle(.grouped)
    }

    private var browserSelection: Binding<String> {
        Binding(
            get: { model.targetBrowserBundleIdentifier },
            set: { model.setTargetBrowser(bundleIdentifier: $0) })
    }

    private var activationDelay: Binding<Int> {
        Binding(
            get: { model.activationDelay },
            set: { model.setActivationDelay($0) })
    }

}

struct PermissionsSettingsView: View {

    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility") {
                    if model.isAccessibilityGranted {
                        SettingsStatus.granted("Granted")
                    } else {
                        Button("Open System Settings…") {
                            model.openAccessibilitySettings()
                        }
                    }
                }
            } footer: {
                SettingsFooter("Used to find the browser's windows on the display under the pointer, so a link opens in a window in the current Space.")
            }
            Section {
                LabeledContent("Automation") {
                    automationStatusView
                }
            } footer: {
                SettingsFooter("Used to tell \(model.targetBrowserName) to open a link in a new tab of that window, or in a new window on that display. macOS asks the first time a link opens.")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var automationStatusView: some View {
        switch model.automationStatus {
        case .granted:
            SettingsStatus.granted("Granted")
        case .denied:
            Button("Open System Settings…") {
                model.openAutomationSettings()
            }
        case .notDetermined:
            SettingsStatus.text("Requested on first link")
        case .unknown:
            SettingsStatus.text("Checked while \(model.targetBrowserName) is running")
        }
    }

}

struct UpdatesSettingsView: View {

    @ObservedObject var updater: AppUpdater

    var body: some View {
        Form {
            if updater.isAvailable {
                Section {
                    Toggle("Install updates automatically", isOn: Binding(
                        get: { updater.updatesAutomatically },
                        set: { updater.updatesAutomatically = $0 }))
                    LabeledContent("Version \(appVersion)") {
                        Button("Check for Updates…") {
                            updater.checkForUpdates()
                        }
                        .disabled(!updater.canCheck)
                    }
                }
            } else {
                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    SettingsFooter("This build has no update feed and doesn't update itself. Builds from the releases page do.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

}

// MARK: - Shared pieces

/// Help text under a section.
struct SettingsFooter: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

}

enum SettingsStatus {

    static func granted(_ title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    static func text(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

}

enum SettingsIcon {

    /// An app icon at the size of a row's text.
    static func small(_ image: NSImage) -> NSImage {
        let icon = image.copy() as! NSImage
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

}
