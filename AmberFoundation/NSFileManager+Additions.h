//
//  NSFileManager+Additions.h
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (AFAdditions)
- (BOOL)validatePath:(NSString *)path withMD5Hash:(NSString *)hash;

#if TARGET_OS_MAC && !TARGET_OS_IPHONE
- (BOOL)validatePath:(NSString *)path withDSASignature:(NSString *)signature publicDSAKey:(NSString *)publicKey;
#endif

@end
