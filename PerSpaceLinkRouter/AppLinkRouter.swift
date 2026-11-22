//
//  AppLinkRouter.swift
//  PerSpaceLinkRouter
//
//  Decides whether a link goes to a native app instead of the browser.
//  Never logs URLs or matched text.
//

import Cocoa

struct AppLinkDestination {
    let rule: AppLinkRule
    let url: URL
    let applicationURL: URL
}

struct AppLinkRuleDescription {
    let rule: AppLinkRule
    let appName: String
    let image: NSImage
}

class AppLinkRouter {

    private let defaults = UserDefaults.standard

    var rules: [AppLinkRule] {
        return AppLinkCatalog.rules(enabledIdentifiers: defaults.enabledAppLinkRuleIdentifiers)
    }

    /// Catalog rules whose app is installed, for the settings UI.
    var installedRuleDescriptions: [AppLinkRuleDescription] {
        return rules.compactMap { rule in
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier),
                  let values = try? applicationURL.resourceValues(forKeys: [.effectiveIconKey, .nameKey]),
                  let image = values.effectiveIcon as? NSImage else {
                return nil
            }
            let appName = values.name.map { ($0 as NSString).deletingPathExtension } ?? rule.name
            return AppLinkRuleDescription(rule: rule, appName: appName, image: image)
        }
    }

    func setRule(identifier: String, enabled: Bool) {
        var identifiers = defaults.enabledAppLinkRuleIdentifiers
        if enabled {
            identifiers.insert(identifier)
        } else {
            identifiers.remove(identifier)
        }
        defaults.enabledAppLinkRuleIdentifiers = identifiers
    }

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
        let enabledRules = rules.filter { $0.isEnabled }
        if enabledRules.isEmpty {
            return nil
        }
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        for rule in enabledRules {
            if rule.bundleIdentifier == sourceBundleIdentifier || rule.bundleIdentifier == frontmostBundleIdentifier {
                continue
            }
            guard let url = rule.destinationURL(for: urlString),
                  let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier) else {
                continue
            }
            return AppLinkDestination(rule: rule, url: url, applicationURL: applicationURL)
        }
        return nil
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
