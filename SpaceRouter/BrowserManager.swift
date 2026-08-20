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
            let name = resourceValues.name!
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

    func setDefaultBrowser() {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http") { error in
            if let error = error {
                NSLog("Failed to set default browser: \(error)")
            }
        }
    }

    func setTargetBrowser(index: Int) {
        defaults.targetBrowserBundleIdentifier = browserDescriptions[index].bundleIdentifier
    }

    func openURL(url: String) {
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: defaults.targetBrowserBundleIdentifier!).first?.processIdentifier
        let browser = supportedBrowsers[defaults.targetBrowserBundleIdentifier!]

        defer { defaults.timeOfLastActivation = Date() }

        let hasWindowInCurrentSpace = pid.map { AXUIElementCreateApplication($0).hasWindowInCurrentSpace }
        switch hasWindowInCurrentSpace {
        case true?:
            browser?.openURL(url, in: .newTab, andActivate: shouldActivate)
        case false?:
            browser?.openURL(url, in: .newWindow, andActivate: shouldActivate)
        default:
            browser?.openURL(url, in: .default)
        }
    }

    private var shouldActivate: Bool {
        let timeOfLastActivation = defaults.timeOfLastActivation
        let timeSinceLastActivation = abs(timeOfLastActivation?.timeIntervalSinceNow ?? 0)
        let activate = timeSinceLastActivation > defaults.activationDelayInterval
        return activate
    }

}
