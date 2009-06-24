//
//  NSFileManager+Additions.h
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (AFAdditions)

/*!
	@brief
	This method loads the URL into memory using NSData, hashes it, and compares it to the hash provided.
 */
- (BOOL)validateURL:(NSURL *)location withMD5Hash:(NSData *)hash;

@end
