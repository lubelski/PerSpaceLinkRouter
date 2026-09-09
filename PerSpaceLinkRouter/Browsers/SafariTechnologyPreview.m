//
//  SafariTechnologyPreview.m
//  OpenHere
//
//  Created by Marc Schwieterman on 11/25/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "SafariTechnologyPreview.h"
#import "SafariTechnologyPreviewSupport.h"

@interface SafariTechnologyPreview ()

@property (nonatomic, readonly) NSString* bundleIdentifier;

@end

@implementation SafariTechnologyPreview

- (instancetype)initWithBundleIdentifier:(NSString*) bundleIdentifier {
    if (self = [self init]) {
        _bundleIdentifier = bundleIdentifier;
    }
    return self;
}

- (SafariTechnologyPreviewApplication*)application {
    return [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];
}

- (void)openURL:(NSString*) url {
    NSParameterAssert(url);
    SafariTechnologyPreviewWindow* frontWindow = [[self.application windows] firstObject];
    frontWindow.currentTab.URL = url;
}

- (BOOL)openURL:(NSString*) url inNewTabOfWindowWithBounds:(NSArray<NSValue*>*) windowBounds andActivate:(BOOL) activate {
    NSParameterAssert(url);
    SafariTechnologyPreviewApplication* application = self.application;

    // `windows` is ordered front to back, so the first match is the frontmost
    // window on the target display.
    SafariTechnologyPreviewWindow* window = nil;
    for (SafariTechnologyPreviewWindow* candidate in [application windows]) {
        if (!candidate.miniaturized && BrowserBoundsMatch(candidate.bounds, windowBounds)) {
            window = candidate;
            break;
        }
    }
    if (!window) {
        return NO;
    }

    SafariTechnologyPreviewTab* newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
    [[window tabs] addObject:newTab];
    // don't touch `newTab` after adding it to `tabs` - it was causing a crash
    window.currentTab = window.tabs.lastObject;
    window.currentTab.URL = url;
    // `window` addresses its position in the front-to-back order. Raising it
    // changes that order, so this must be the last use of `window`.
    window.index = 1;

    if (activate) {
        [application activate];
    }
    return YES;
}

- (void)openURL:(NSString*) url inNewWindowCenteredIn:(NSRect) area andActivate:(BOOL) activate {
    NSParameterAssert(url);
    SafariTechnologyPreviewApplication* application = self.application;

    SafariTechnologyPreviewDocument* newDocument = [[[application classForScriptingClass:@"document"] alloc] init];
    [[application documents] addObject:newDocument];
    // Safari opens the new document in a new window and puts it in front.
    SafariTechnologyPreviewWindow* window = [[application windows] firstObject];
    window.bounds = BrowserCenteredBounds(window.bounds, area);
    window.currentTab.URL = url;

    if (activate) {
        [application activate];
    }
}

@end
