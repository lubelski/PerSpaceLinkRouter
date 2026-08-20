//
//  SafariTechnologyPreview.h
//  OpenHere
//
//  Created by Marc Schwieterman on 11/25/16.
//  Copyright © 2016 Marc Schwieterman. All rights reserved.
//

#import "Browser.h"

@interface SafariTechnologyPreview : NSObject<Browser>

NS_ASSUME_NONNULL_BEGIN
- (instancetype)initWithBundleIdentifier:(NSString*) bundleIdentifier;
NS_ASSUME_NONNULL_END

@end
