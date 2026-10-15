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
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

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
            image.accessibilityDescription = "PerSpaceLinkRouter"
            item.button?.image = image
        } else {
            item.button?.title = "SR"
        }
        item.button?.toolTip = "PerSpaceLinkRouter"
        let menu = NSMenu()
        let browserItem = NSMenuItem(title: "Open Links With", action: nil, keyEquivalent: "")
        let browserMenu = NSMenu(title: browserItem.title)
        browserMenu.delegate = self
        browserItem.submenu = browserMenu
        menu.addItem(browserItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsFromMenu(_:)), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PerSpaceLinkRouter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Read the saved selection each time, including changes made in Settings.
        menu.removeAllItems()
        for browser in browserManager.browserDescriptions {
            let item = NSMenuItem(title: browser.name, action: #selector(selectBrowserFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.bundleIdentifier
            item.state = defaults.targetBrowserBundleIdentifier == browser.bundleIdentifier ? .on : .off
            let icon = browser.image.copy() as? NSImage
            icon?.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }
        if menu.items.isEmpty {
            let item = NSMenuItem(title: "No Supported Browsers Installed", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    @objc private func selectBrowserFromMenu(_ sender: NSMenuItem) {
        guard let bundleIdentifier = sender.representedObject as? String else { return }
        browserManager.setTargetBrowser(bundleIdentifier: bundleIdentifier)
        settingsModel?.refresh()
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
        window.title = "PerSpaceLinkRouter Settings"
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

    // Local HTML files opened via Finder ("Open With") arrive here rather
    // than as a GetURL event. The document type claim exists so the app is
    // listed in System Settings' default browser picker, which requires
    // public.html in addition to the http/https schemes.
    func application(_ application: NSApplication, open urls: [URL]) {
        launchedToOpenURL = true
        for url in urls {
            browserManager.openURL(url: url.absoluteString)
        }
    }

}
