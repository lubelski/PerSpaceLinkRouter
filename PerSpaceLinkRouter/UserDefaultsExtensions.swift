//
//  UserDefaultsExtensions.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 8/6/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import Foundation

extension UserDefaults {

    private struct Keys {
        static let targetBrowserBundleIdentifier = "targetBrowserBundleIdentifier"
        static let timeOfLastActivation = "timeOfLastActivation"
        static let activationDelayInterval = "activationDelayInterval"
        static let hideDockIcon = "hideDockIcon"
        static let relaunchedAfterUpdate = "relaunchedAfterUpdate"
        static let enabledAppLinkRuleIdentifiers = "enabledAppLinkRuleIdentifiers"
    }

    private static let defaultValues: [String: Any] = [
        Keys.activationDelayInterval: 10
    ]

    var targetBrowserBundleIdentifier: String? {
        get {
            return string(forKey: Keys.targetBrowserBundleIdentifier)
        }
        set {
            set(newValue, forKey: Keys.targetBrowserBundleIdentifier)
            synchronize()
        }
    }

    var timeOfLastActivation: Date? {
        get {
            return value(forKey: Keys.timeOfLastActivation) as? Date
        }
        set {
            set(newValue, forKey: Keys.timeOfLastActivation)
            synchronize()
        }
    }

    var activationDelayInterval: TimeInterval {
        get {
            return double(forKey: Keys.activationDelayInterval)
        }
        set {
            set(newValue, forKey: Keys.activationDelayInterval)
            synchronize()
        }
    }

    var hideDockIcon: Bool {
        get {
            return bool(forKey: Keys.hideDockIcon)
        }
        set {
            set(newValue, forKey: Keys.hideDockIcon)
            synchronize()
        }
    }

    /// Set just before the updater relaunches the app, and cleared at the next launch.
    var relaunchedAfterUpdate: Bool {
        get {
            return bool(forKey: Keys.relaunchedAfterUpdate)
        }
        set {
            set(newValue, forKey: Keys.relaunchedAfterUpdate)
            synchronize()
        }
    }

    // Only user state is stored: which catalog rules are on. The rules
    // themselves live in code (AppLinkCatalog). Custom rules, if added later,
    // belong under their own key.
    var enabledAppLinkRuleIdentifiers: Set<String> {
        get {
            return Set(stringArray(forKey: Keys.enabledAppLinkRuleIdentifiers) ?? [])
        }
        set {
            set(newValue.sorted(), forKey: Keys.enabledAppLinkRuleIdentifiers)
            synchronize()
        }
    }

    func registerDefaultVales() {
        register(defaults: type(of: self).defaultValues)
    }
    
}
