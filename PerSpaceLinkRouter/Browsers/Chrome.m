//
//  Chrome.m
//  OpenHere
//
//  Created by Marc Schwieterman on 8/13/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "Chrome.h"
#import "ChromeSupport.h"

@interface Chrome ()

@property (nonatomic, readonly) NSString* bundleIdentifier;

@end

@implementation Chrome

- (instancetype)initWithBundleIdentifier:(NSString*) bundleIdentifier {
    if (self = [self init]) {
        _bundleIdentifier = bundleIdentifier;
    }
    return self;
}

- (ChromeApplication*)application {
    return [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];
}

- (void)openURL:(NSString*) url {
    NSParameterAssert(url);
    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    NSURL* applicationURL = [workspace URLForApplicationWithBundleIdentifier:self.bundleIdentifier];
    NSURL* urlToOpen = [NSURL URLWithString:url];
    if (!applicationURL || !urlToOpen) {
        NSLog(@"Failed to launch Chrome for URL: %@", url);
        return;
    }

    NSWorkspaceOpenConfiguration* configuration = [NSWorkspaceOpenConfiguration configuration];
    [workspace openURLs:@[urlToOpen]
        withApplicationAtURL:applicationURL
               configuration:configuration
           completionHandler:^(NSRunningApplication* app, NSError* error) {
        if (error) {
            NSLog(@"Failed to launch Chrome: %@", error);
        }
    }];
}

- (BOOL)openURL:(NSString*) url inNewTabOfWindowWithBounds:(NSArray<NSValue*>*) windowBounds andActivate:(BOOL) activate {
    NSParameterAssert(url);
    ChromeApplication* application = self.application;

    // `windows` is ordered front to back, so the first match is the frontmost
    // window on the target display.
    ChromeWindow* window = nil;
    for (ChromeWindow* candidate in [application windows]) {
        if (!candidate.minimized && BrowserBoundsMatch(candidate.bounds, windowBounds)) {
            window = candidate;
            break;
        }
    }
    if (!window) {
        return NO;
    }

    ChromeTab* newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
    [window.tabs addObject:newTab];
    window.activeTab.URL = url;
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
    ChromeApplication* application = self.application;

    ChromeWindow* newWindow = [[[application classForScriptingClass:@"window"] alloc] init];
    [[application windows] addObject:newWindow];
    newWindow.bounds = BrowserCenteredBounds(newWindow.bounds, area);
    newWindow.activeTab.URL = url;

    if (activate) {
        [application activate];
    }
}

@end
