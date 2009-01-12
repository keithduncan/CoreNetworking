//
//  NSBundle+AFAdditions.h
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const AFCompanyNameKey;

@interface NSBundle (AFAdditions)
- (NSString *)version;
- (NSString *)displayVersion;

- (NSString *)name;
- (NSString *)displayName;

// These return the Info.plist object for the respective key
- (NSString *)companyName;
@end

@interface NSBundle (AFPathAdditions)
- (NSString *)applicationSupportPath:(NSUInteger)domain;
@end

@protocol AFBundleDiscovery <NSObject>
- (NSBundle *)bundle;
@end
