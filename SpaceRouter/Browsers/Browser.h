//
//  Browser.h
//  OpenHere
//
//  Created by Marc Schwieterman on 8/13/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BrowserTarget) {
    BrowserTargetDefault = 1,
    BrowserTargetNewWindow,
    BrowserTargetNewTab
};

@protocol Browser <NSObject>

NS_ASSUME_NONNULL_BEGIN
- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget;
- (void)openURL:(NSString*) url inBrowserTarget:(BrowserTarget) browserTarget andActivate:(BOOL) activate;
NS_ASSUME_NONNULL_END

@end
