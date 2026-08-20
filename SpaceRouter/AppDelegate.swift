//
//  AppDelegate.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 7/30/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private let defaults = UserDefaults.standard
    private let browserManager = BrowserManager()

    private var launchedToOpenURL = false
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var browserPopUpButton: NSPopUpButton?
    private var setDefaultBrowserButton: NSButton?
    private var hideDockIconCheckbox: NSButton?
    private var launchAtLoginCheckbox: NSButton?

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
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "SpaceRouter")
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
        refreshSettingsState()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(self)
    }

    private func makeSettingsWindow() -> NSWindow {
        let popUpButton = NSPopUpButton()
        popUpButton.target = self
        popUpButton.action = #selector(browserPopUpButtonChanged(button:))
        browserManager.browserDescriptions.forEach { browser in
            add(browser: browser, toPopUpButton: popUpButton)
        }
        browserPopUpButton = popUpButton

        let defaultBrowserButton = NSButton(
            title: "Set SpaceRouter as Default Browser",
            target: self,
            action: #selector(setDefaultBrowser(_:)))
        setDefaultBrowserButton = defaultBrowserButton

        let dockCheckbox = NSButton(
            checkboxWithTitle: "Hide Dock icon",
            target: self,
            action: #selector(hideDockIconChanged(_:)))
        hideDockIconCheckbox = dockCheckbox

        let loginCheckbox = NSButton(
            checkboxWithTitle: "Start at login",
            target: self,
            action: #selector(launchAtLoginChanged(_:)))
        launchAtLoginCheckbox = loginCheckbox

        let browserRow = NSStackView(views: [NSTextField(labelWithString: "Open links with:"), popUpButton])
        browserRow.orientation = .horizontal

        let stack = NSStackView(views: [browserRow, defaultBrowserButton, dockCheckbox, loginCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "SpaceRouter"
        window.isReleasedWhenClosed = false
        window.contentView = stack
        window.setContentSize(stack.fittingSize)
        window.center()
        return window
    }

    private func refreshSettingsState() {
        setDefaultBrowserButton?.isEnabled = !browserManager.isDefaultBrowser
        hideDockIconCheckbox?.state = defaults.hideDockIcon ? .on : .off
        launchAtLoginCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func add(browser: BrowserDescription, toPopUpButton popUpButton: NSPopUpButton) {
        let image = browser.image
        let height = popUpButton.fittingSize.height
        image.size = NSSize(width: height, height: height)

        popUpButton.addItem(withTitle: browser.name)
        let item = popUpButton.lastItem!
        item.image = image

        if browser.isTargetBrowser {
            popUpButton.select(item)
        }
    }

    // MARK: - Actions

    @objc private func browserPopUpButtonChanged(button: NSPopUpButton) {
        browserManager.setTargetBrowser(index: button.indexOfSelectedItem)
    }

    @objc private func setDefaultBrowser(_ sender: NSButton) {
        sender.isEnabled = false
        browserManager.setDefaultBrowser()
        if let popUpButton = browserPopUpButton {
            browserManager.setTargetBrowser(index: popUpButton.indexOfSelectedItem)
        }
    }

    @objc private func hideDockIconChanged(_ sender: NSButton) {
        defaults.hideDockIcon = sender.state == .on
        applyActivationPolicy()
        // The policy switch can drop the app out of focus; bring the window back.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(self)
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            if sender.state == .on {
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
        refreshSettingsState()
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
