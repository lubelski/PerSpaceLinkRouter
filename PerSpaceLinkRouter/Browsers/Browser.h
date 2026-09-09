//
//  Browser.h
//  OpenHere
//
//  Created by Marc Schwieterman on 8/13/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// All rects are in top-left-origin global coordinates, which is what
// AppleScript window bounds and the Accessibility API report.

@protocol Browser <NSObject>

/// Opens the URL with the browser's own default behavior. Used when the
/// browser is not running.
- (void)openURL:(NSString*) url;

/// Opens the URL in a new tab of the frontmost window whose bounds equal one
/// of `windowBounds` (NSValue-wrapped NSRects), and raises that window inside
/// the browser. Returns NO, and opens nothing, when no window matches.
- (BOOL)openURL:(NSString*) url inNewTabOfWindowWithBounds:(NSArray<NSValue*>*) windowBounds andActivate:(BOOL) activate;

/// Opens the URL in a new window, moved to the center of `area`.
- (void)openURL:(NSString*) url inNewWindowCenteredIn:(NSRect) area andActivate:(BOOL) activate;

@end

/// Centers `bounds` in `area`, shrinking it when it does not fit.
static inline NSRect BrowserCenteredBounds(NSRect bounds, NSRect area) {
    NSSize size = NSMakeSize(MIN(bounds.size.width, area.size.width), MIN(bounds.size.height, area.size.height));
    return NSMakeRect(NSMidX(area) - size.width / 2, NSMidY(area) - size.height / 2, size.width, size.height);
}

/// Whether `bounds` equals one of `candidates`. Allows a point of slack for
/// rounding differences between AppleScript and the Accessibility API.
static inline BOOL BrowserBoundsMatch(NSRect bounds, NSArray<NSValue*>* candidates) {
    for (NSValue* candidate in candidates) {
        NSRect rect = candidate.rectValue;
        if (fabs(rect.origin.x - bounds.origin.x) <= 1 && fabs(rect.origin.y - bounds.origin.y) <= 1 &&
            fabs(rect.size.width - bounds.size.width) <= 1 && fabs(rect.size.height - bounds.size.height) <= 1) {
            return YES;
        }
    }
    return NO;
}

NS_ASSUME_NONNULL_END
