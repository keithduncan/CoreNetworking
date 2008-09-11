//
//  NSBundle+Additions.h
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol AFBundleDiscoveryProtocol <NSObject>
- (NSBundle *)bundle;
@end

@interface NSBundle (AFAdditions)
- (NSImage *)icon;
- (NSImage *)alertIcon;

- (NSString *)version;
- (NSString *)displayVersion;

- (NSString *)name;
- (NSString *)displayName;

// These return the Info.plist object for the respective AF* key
- (NSString *)companyName;
@end

@interface NSBundle (AFPathAdditions)
- (NSString *)applicationSupportPath:(NSUInteger)domain;
@end

extern NSString *const AFAlertIconFileKey;
extern NSString *const AFCompanyNameKey;
