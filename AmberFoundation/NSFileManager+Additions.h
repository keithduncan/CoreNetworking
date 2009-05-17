//
//  NSFileManager+Additions.h
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (AFAdditions)

/*
	@brief
	Use <tt>-[NSFileManager validateURL:withMD5Hash:]</tt>.
	This method assumes the hash is hex encoded, this too, is flawed.
 */
- (BOOL)validatePath:(NSString *)path withMD5Hash:(NSString *)hash DEPRECATED_ATTRIBUTE;

/*
	@brief
	This method loads the URL into memory using NSData, hashes it, and compares it to the hash provided.
 */
- (BOOL)validateURL:(NSString *)location withMD5Hash:(NSData *)hash;

@end
