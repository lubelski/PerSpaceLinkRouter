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
    /// The application's standard windows that are on an active Space and not
    /// minimized. The Accessibility API omits windows on inactive Spaces. With
    /// "Displays have separate Spaces" on, every display has an active Space,
    /// so this list spans all displays and the caller narrows it by display.
    var visibleStandardWindows: [AXUIElement] {
        return (windows ?? []).filter { $0.subrole == kAXStandardWindowSubrole && !$0.isMinimized }
    }

    /// The window frame in top-left-origin global coordinates.
    var frame: CGRect? {
        guard let positionValue = axValue(attributeName: kAXPositionAttribute),
              let sizeValue = axValue(attributeName: kAXSizeAttribute) else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    var isMinimized: Bool {
        return attributeValue(attributeName: kAXMinimizedAttribute) as? Bool ?? false
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
        guard let windows = attributeValue(attributeName: kAXWindowsAttribute) else {
            return .none
        }
        return windows as? [AXUIElement]
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

    private func axValue(attributeName: String) -> AXValue? {
        guard let value = attributeValue(attributeName: attributeName),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
    }
}
