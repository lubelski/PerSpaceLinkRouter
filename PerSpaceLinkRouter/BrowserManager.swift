//
//  BrowserManager.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 8/13/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Cocoa

struct BrowserDescription {
    let bundleIdentifier: String
    let name: String
    let image: NSImage
    let isTargetBrowser: Bool
}

class BrowserManager {

    lazy var browserDescriptions: [BrowserDescription] = {
        return self.supportedBrowserOrder.compactMap { bundleIdentifier -> BrowserDescription? in
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                return nil
            }
            let resourceValues = try! applicationURL.resourceValues(forKeys: [.effectiveIconKey, .nameKey])
            let name = (resourceValues.name! as NSString).deletingPathExtension
            let image = resourceValues.effectiveIcon as! NSImage
            return BrowserDescription(bundleIdentifier: bundleIdentifier, name: name, image: image, isTargetBrowser: self.isTargetBrowser(bundleIdentifier))
        }
    }()

    private func isTargetBrowser(_ bundleIdentifier: String) -> Bool {
        if isDefaultBrowser {
            // we *should* have a target browser, but not selecting one is better than crashing with a forced unwrap
            return defaults.targetBrowserBundleIdentifier.map { bundleIdentifier == $0 } ?? false
        } else {
            return bundleIdentifier == defaultBrowserBundleIdentifier
        }
    }

    var isDefaultBrowser: Bool {
        return defaultBrowserBundleIdentifier == Bundle.main.bundleIdentifier!
    }

    var isAccessibilityEnabled: Bool {
        let options: NSDictionary = [String(kAXTrustedCheckOptionPrompt.takeUnretainedValue()): true]
        return AXIsProcessTrustedWithOptions(options)
    }

    private struct BrowserBundleIdentifier {
        static let safari = "com.apple.Safari"
        static let safariTechnologyPreview = "com.apple.SafariTechnologyPreview"
        static let chrome = "com.google.Chrome"
    }

    private typealias BBI = BrowserBundleIdentifier

    private let supportedBrowsers: [String:Browser] = [
        BBI.safariTechnologyPreview: SafariTechnologyPreview(bundleIdentifier: BBI.safariTechnologyPreview),
        BBI.safari: Safari(bundleIdentifier: BBI.safari),
        BBI.chrome: Chrome(bundleIdentifier: BBI.chrome)
    ]

    // Display order for the browser popup. Dictionary key order is randomized
    // per launch, so the popup must never be built from supportedBrowsers.keys.
    private let supportedBrowserOrder = [BBI.safari, BBI.safariTechnologyPreview, BBI.chrome]

    // Computed, not cached: the app is resident now, and the system default
    // browser can change while it runs.
    private var defaultBrowserBundleIdentifier: String {
        let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http:")!)!
        let bundle = Bundle(url: url)!
        return bundle.bundleIdentifier!
    }

    private let defaults = UserDefaults.standard

    func setDefaultBrowser(completion: ((Error?) -> Void)? = nil) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http") { error in
            if let error = error {
                NSLog("Failed to set default browser: \(error)")
            }
            completion?(error)
        }
    }

    func setTargetBrowser(bundleIdentifier: String) {
        defaults.targetBrowserBundleIdentifier = bundleIdentifier
    }

    func openURL(url: String) {
        guard let bundleIdentifier = defaults.targetBrowserBundleIdentifier,
              let browser = supportedBrowsers[bundleIdentifier] else {
            NSLog("No supported target browser is selected")
            return
        }

        defer { defaults.timeOfLastActivation = Date() }

        // A browser that is not running has no windows to route to. Let it
        // launch and open the link its own way.
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier else {
            browser.openURL(url)
            return
        }

        let layout = DisplayLayout()
        guard let display = layout.displayUnderCursor else {
            browser.openURL(url)
            return
        }

        // Windows on an active Space, narrowed to the cursor's display. The
        // browser matches these frames against its own window list, which is
        // ordered front to back, so the frontmost one on that display wins.
        let windowBounds = AXUIElementCreateApplication(pid).visibleStandardWindows
            .compactMap { $0.frame }
            .filter { layout.display(holdingMostOf: $0) == display }
            .map { NSValue(rect: $0) }

        let activate = shouldActivate
        if !windowBounds.isEmpty,
           browser.openURL(url, inNewTabOfWindowWithBounds: windowBounds, andActivate: activate) {
            return
        }
        browser.openURL(url, inNewWindowCenteredIn: display.visibleFrame, andActivate: activate)
    }

    private var shouldActivate: Bool {
        let timeOfLastActivation = defaults.timeOfLastActivation
        let timeSinceLastActivation = abs(timeOfLastActivation?.timeIntervalSinceNow ?? 0)
        let activate = timeSinceLastActivation > defaults.activationDelayInterval
        return activate
    }

}
