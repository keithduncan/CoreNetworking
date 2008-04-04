//
//  NSBundle+Additions.h
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol KDBundleDiscoveryProtocol <NSObject>
- (NSBundle *)bundle;
@end

@interface NSBundle (Additions)
- (NSImage *)alertImage;
- (NSImage *)bundleImage;

- (NSString *)version;
- (NSString *)displayVersion;

- (NSString *)name;
- (NSString *)displayName;

// These return the Info.plist object for the respective AF* key
- (NSString *)companyName;
- (NSString *)companySite;
@end

@interface NSBundle (PathAdditions)
- (NSString *)applicationSupportPath:(NSUInteger)domain;
@end

extern NSString *const AFAlertImageNameKey;
extern NSString *const AFCompanyNameKey;
extern NSString *const AFCompanySiteKey;
