//
//  AppDelegate.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 7/30/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var browserPopUpButton: NSPopUpButton!
    @IBOutlet weak var setDefaultBrowserButton: NSButton!

    private let defaults = UserDefaults.standard
    private let browserManager = BrowserManager()

    private var isOpeningURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard browserManager.isAccessibilityEnabled else {
            NSRunningApplication.current.terminate()
            return
        }
        defaults.registerDefaultVales()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isOpeningURL else { return }
        browserManager.browserDescriptions.forEach { browser in
            add(browser: browser, toPopUpButton: browserPopUpButton)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        defer { isOpeningURL = false }
        guard !isOpeningURL else { return }
        if browserManager.isDefaultBrowser {
            setDefaultBrowserButton.isEnabled = false
        }
        window.makeKeyAndOrderFront(self)
    }

    private func add(browser: BrowserDescription, toPopUpButton: NSPopUpButton) {
        let image = browser.image
        let height = browserPopUpButton.fittingSize.height
        image.size = NSSize(width: height, height: height)

        browserPopUpButton.addItem(withTitle: browser.name)
        let item = browserPopUpButton.lastItem!
        item.image = image

        if browser.isTargetBrowser {
            browserPopUpButton.select(item)
        }
    }

    @IBAction func browserPopUpButtonChanged(button: NSPopUpButton) {
        setTargetBrowserToSelectedBrowser()
    }

    @IBAction func setDefaultBrowser(_ sender: NSButton) {
        setDefaultBrowserButton.isEnabled = false
        browserManager.setDefaultBrowser()
        setTargetBrowserToSelectedBrowser()
    }

    private func setTargetBrowserToSelectedBrowser() {
        browserManager.setTargetBrowser(index: browserPopUpButton.indexOfSelectedItem)
    }

    @objc private func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        isOpeningURL = true
        if let urlAsString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            browserManager.openURL(url: urlAsString)
            NSRunningApplication.current.terminate()
        }
    }

}
