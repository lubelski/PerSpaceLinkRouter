//
//  Display.swift
//  PerSpaceLinkRouter
//

import AppKit

/// A connected display, in the top-left-origin coordinate space that the
/// Accessibility API and AppleScript window bounds use.
struct Display: Equatable {
    let frame: CGRect
    /// `frame` minus the menu bar and the Dock.
    let visibleFrame: CGRect
}

/// A snapshot of the connected displays.
///
/// NSScreen reports bottom-left-origin Cocoa coordinates. Every rect and point
/// is flipped here, once, so the rest of the app compares like with like.
struct DisplayLayout {
    let displays: [Display]
    private let primaryHeight: CGFloat

    init(screens: [NSScreen] = NSScreen.screens) {
        // The primary display has its Cocoa origin at (0, 0), so its height is
        // the flip axis for every screen.
        let primaryHeight = screens.first?.frame.height ?? 0
        self.primaryHeight = primaryHeight
        displays = screens.map { screen in
            Display(frame: Self.flipped(screen.frame, primaryHeight: primaryHeight),
                    visibleFrame: Self.flipped(screen.visibleFrame, primaryHeight: primaryHeight))
        }
    }

    /// The display under the mouse cursor, or the primary display when the
    /// cursor is on none of them.
    var displayUnderCursor: Display? {
        let cursor = NSEvent.mouseLocation
        let point = CGPoint(x: cursor.x, y: primaryHeight - cursor.y)
        // The cursor can rest on the far edge of a display, which `contains`
        // treats as outside. Widen the test by a point.
        return displays.first { $0.frame.insetBy(dx: -1, dy: -1).contains(point) } ?? displays.first
    }

    /// The display that holds the largest part of `rect`, or nil when `rect`
    /// is off every display.
    func display(holdingMostOf rect: CGRect) -> Display? {
        let ranked = displays.map { (display: $0, area: Self.area(of: $0.frame.intersection(rect))) }
        guard let best = ranked.max(by: { $0.area < $1.area }), best.area > 0 else {
            return nil
        }
        return best.display
    }

    private static func flipped(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func area(of rect: CGRect) -> CGFloat {
        return rect.isNull ? 0 : rect.width * rect.height
    }
}
