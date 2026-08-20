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

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);
    [self openURL:url inBrowserTarget:browserTarget andActivate:false];
}

- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget andActivate:(BOOL) activate {
    NSParameterAssert(url);
    NSParameterAssert(browserTarget);

    switch (browserTarget) {
        case BrowserTargetNewWindow: {
            [self openURL:url inNewWindowAndActivate:activate];
            break;
        }
        case BrowserTargetNewTab: {
            [self openURL:url inNewTabAndActivate:activate];
            break;
        }
        default: {
            [self openURL:url];
            break;
        }
    }
}

- (void)openURL:(NSString *)url inNewWindowAndActivate:(BOOL)activate {
    ChromeApplication* application =
    [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];
    ChromeWindow* newWindow = [[[application classForScriptingClass:@"window"] alloc] init];
    [[application windows] addObject:newWindow];
    newWindow.activeTab.URL = url;
    if (activate) {
        [application activate];
    }
}

- (void)openURL:(NSString *)url inNewTabAndActivate:(BOOL)activate {
    ChromeApplication* application =
    [SBApplication applicationWithBundleIdentifier:self.bundleIdentifier];
    ChromeWindow *frontWindow = [[application windows] firstObject];
    ChromeTab *newTab = [[[application classForScriptingClass:@"tab"] alloc] init];
    [frontWindow.tabs addObject:newTab];
    frontWindow.activeTab.URL = url;
    if (activate) {
        [application activate];
    }
}

- (void)openURL:(NSString *)url {
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

@end
