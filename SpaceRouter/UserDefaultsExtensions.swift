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

    func registerDefaultVales() {
        register(defaults: type(of: self).defaultValues)
    }
    
}
