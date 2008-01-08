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
- (NSImage *)bundleImage;

- (NSString *)version;
- (NSString *)displayVersion;

- (NSString *)name;
- (NSString *)displayName;
@end
