//
//  AppDelegate.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 7/30/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private let defaults = UserDefaults.standard
    private let browserManager = BrowserManager()

    private var launchedToOpenURL = false
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var settingsModel: SettingsModel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        defaults.registerDefaultVales()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        setUpStatusItem()
        _ = browserManager.isAccessibilityEnabled
        // A URL launch or a hidden Dock icon means the app is running as a
        // background agent; only a direct launch with a visible Dock icon
        // shows the window unprompted.
        if !launchedToOpenURL && !defaults.hideDockIcon {
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return false
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.accessibilityDescription = "SpaceRouter"
            item.button?.image = image
        } else {
            item.button?.title = "SR"
        }
        item.button?.toolTip = "SpaceRouter"
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsFromMenu(_:)), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpaceRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    @objc private func showSettingsFromMenu(_ sender: NSMenuItem) {
        showSettings()
    }

    // MARK: - Settings window

    private func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        settingsModel?.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(self)
    }

    private func makeSettingsWindow() -> NSWindow {
        let model = SettingsModel(browserManager: browserManager)
        model.onHideDockIconChange = { [weak self] in
            self?.applyActivationPolicy()
            // The policy switch can drop the app out of focus; bring the window back.
            NSApp.activate(ignoringOtherApps: true)
            self?.settingsWindow?.makeKeyAndOrderFront(self)
        }
        settingsModel = model

        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "SpaceRouter Settings"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(defaults.hideDockIcon ? .accessory : .regular)
    }

    // MARK: - URL handling

    @objc private func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        launchedToOpenURL = true
        if let urlAsString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            browserManager.openURL(url: urlAsString)
        }
    }

}
