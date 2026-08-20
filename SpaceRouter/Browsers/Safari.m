//
//  Safari.m
//  OpenHere
//
//  Created by Marc Schwieterman on 8/6/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "Safari.h"
#import "SafariSupport.h"

@interface Safari ()

@property (nonatomic, readonly) NSString* bundleIdentifier;

@end

@implementation Safari

- (instancetype)initWithBundleIdentifier:(NSString*) bundleIdentifier {
    if (self = [self init]) {
        _bundleIdentifier = bundleIdentifier;
    }
    return self;
}

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);
    [self openURL:url inBrowserTarget:browserTarget andActivate:false];
}

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget andActivate:(BOOL) activate {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);
    SafariApplication* application =
    [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];

    switch (browserTarget) {
        case BrowserTargetNewWindow: {
            SafariDocument* newDocument = [[[application classForScriptingClass:@"document"] alloc] init];
            [[application documents] addObject:newDocument];
            SafariWindow* frontWindow = [[application windows] firstObject];
            frontWindow.currentTab.URL = url;
            break;
        }
        case BrowserTargetNewTab: {
            SafariWindow* frontWindow = [[application windows] firstObject];
            SafariTab* newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
            [[frontWindow tabs] addObject:newTab];
            // don't touch `newTab` after adding it to `tabs` - it was causing a crash
            frontWindow.currentTab = frontWindow.tabs.lastObject;
            frontWindow.currentTab.URL = url;
            break;
        }
        default: {
            SafariWindow* frontWindow = [[application windows] firstObject];
            frontWindow.currentTab.URL = url;
            break;
        }
    }

    if (activate) {
        [application activate];
    }
}

@end
