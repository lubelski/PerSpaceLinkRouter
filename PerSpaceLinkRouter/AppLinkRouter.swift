//
//  AppLinkRouter.swift
//  PerSpaceLinkRouter
//
//  Decides whether a link goes to a native app instead of the browser.
//  Never logs URLs or matched text.
//

import Cocoa
import UniformTypeIdentifiers

struct AppLinkDestination {
    let rule: AppLinkRule
    let url: URL
    let applicationURL: URL
}

/// A rule as the settings window shows it.
struct AppLinkRuleDescription: Identifiable {
    let rule: AppLinkRule
    /// The app's name on this Mac, or the rule's name when not installed.
    let appName: String
    /// The app's icon, or a generic app icon when not installed.
    let image: NSImage
    let isInstalled: Bool
    let isBuiltIn: Bool
    let summary: String

    var id: String { rule.id }
}

class AppLinkRouter {

    let store: AppLinkConfigStore

    init(store: AppLinkConfigStore = AppLinkConfigStore(fallbackEnabledIdentifiers: {
        UserDefaults.standard.enabledAppLinkRuleIdentifiers
    })) {
        self.store = store
    }

    /// Every rule in match order, built-in and custom, with `isEnabled` set.
    var rules: [AppLinkRule] {
        return store.rules
    }

    static func applicationURL(for rule: AppLinkRule) -> URL? {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier)
    }

    static func isInstalled(_ rule: AppLinkRule) -> Bool {
        return applicationURL(for: rule) != nil
    }

    /// Every rule in match order, for the settings window. Rules whose app
    /// is not installed are included and marked.
    var ruleDescriptions: [AppLinkRuleDescription] {
        return rules.map(Self.describe)
    }

    static func describe(_ rule: AppLinkRule) -> AppLinkRuleDescription {
        let isBuiltIn = AppLinkCatalog.isBuiltIn(rule.id)
        let summary = AppLinkCatalog.summary(for: rule)
        if let applicationURL = applicationURL(for: rule),
           let values = try? applicationURL.resourceValues(forKeys: [.effectiveIconKey, .nameKey]),
           let image = values.effectiveIcon as? NSImage {
            let appName = values.name.map { ($0 as NSString).deletingPathExtension } ?? rule.name
            return AppLinkRuleDescription(rule: rule, appName: appName, image: image, isInstalled: true,
                                          isBuiltIn: isBuiltIn, summary: summary)
        }
        return AppLinkRuleDescription(rule: rule, appName: rule.name, image: genericApplicationIcon, isInstalled: false,
                                      isBuiltIn: isBuiltIn, summary: summary)
    }

    static let genericApplicationIcon: NSImage = NSWorkspace.shared.icon(for: .applicationBundle)

    /// The first enabled rule that matches and whose app is installed, or nil
    /// to use the browser.
    ///
    /// `sourceBundleIdentifier` is the app that sent the link. A link coming
    /// from a rule's own app (Figma's "Open in Browser", say) skips that rule
    /// so it reaches the browser instead of looping back. The frontmost app is
    /// checked too, in case the sender resolves to a system process rather
    /// than the app the user clicked in. Holding Option bypasses every rule.
    func destination(for urlString: String, sourceBundleIdentifier: String?) -> AppLinkDestination? {
        if NSEvent.modifierFlags.contains(.option) {
            return nil
        }
        let rules = self.rules
        if !rules.contains(where: \.isEnabled) {
            return nil
        }
        let skipping = Set([sourceBundleIdentifier, NSWorkspace.shared.frontmostApplication?.bundleIdentifier].compactMap { $0 })
        guard case let .app(rule, url) = AppLinkMatcher.match(urlString, rules: rules, isInstalled: Self.isInstalled,
                                                              skippingBundleIdentifiers: skipping),
              let applicationURL = Self.applicationURL(for: rule) else {
            return nil
        }
        return AppLinkDestination(rule: rule, url: url, applicationURL: applicationURL)
    }

    /// Where a link would go, for "Test a link". The same matching as
    /// `destination`, without the Option key or the sending app. Opens
    /// nothing and logs nothing.
    func test(_ urlString: String) -> AppLinkMatch {
        return AppLinkMatcher.match(urlString, rules: rules, isInstalled: Self.isInstalled, reportUnavailable: true)
    }

    func open(_ destination: AppLinkDestination, activate: Bool, completion: @escaping (Bool) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        NSWorkspace.shared.open([destination.url], withApplicationAt: destination.applicationURL, configuration: configuration) { _, error in
            if let error = error as NSError? {
                // Domain and code only: the error's description and user info
                // can contain the URL.
                NSLog("Failed to open link in \(destination.rule.name): \(error.domain) \(error.code)")
            }
            DispatchQueue.main.async { completion(error == nil) }
        }
    }

}
