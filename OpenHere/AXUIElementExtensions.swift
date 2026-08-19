//
//  AXUIElementExtensions.swift
//  OpenHere
//
//  Created by Marc Schwieterman on 8/6/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

import ApplicationServices
import Foundation

extension AXUIElement {
    var hasWindowInCurrentSpace: Bool {
        return windows?.first(where: { $0.subrole == "AXStandardWindow" }) != nil
    }

    var attributeNames: [String]? {
        var attributeNames: CFArray?
        let error = withUnsafeMutablePointer(to: &attributeNames) { pointer -> AXError in
            AXUIElementCopyAttributeNames(self, pointer)
        }
        if error == .success {
            return attributeNames as AnyObject as? [String]
        }
        return .none
    }

    var windows: [AXUIElement]? {
        var windows: CFArray?
        let error = withUnsafeMutablePointer(to: &windows) { pointer -> AXError in
            AXUIElementCopyAttributeValues(self, kAXWindowsAttribute as CFString, 0, 10, pointer)
        }
        if error == .success {
            return windows as AnyObject as? [AXUIElement]
        }
        return .none
    }

    var role: String? {
        return attributeValue(attributeName: kAXRoleAttribute) as? String
    }

    var subrole: String? {
        return attributeValue(attributeName: kAXSubroleAttribute) as? String
    }

    private func attributeValue(attributeName: String) -> AnyObject? {
        var value: AnyObject?
        let error = withUnsafeMutablePointer(to: &value) { pointer -> AXError in
            AXUIElementCopyAttributeValue(self, attributeName as CFString, pointer)
        }
        if error == .success {
            return value
        }
        return .none
    }
}
