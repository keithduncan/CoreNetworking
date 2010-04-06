//
//  NSData+Additions.h
//  Amber
//
//  Created by Keith Duncan on 04/01/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	Wrapper around the CommonCrypto hashing functions.
	These data objects are unlikely to be used raw, there are a number of base conversion methods in the <tt>AFBaseConversion</tt> NSData category.
 */
@interface NSData (AFHashing)
- (NSData *)MD5Hash;
- (NSData *)SHA1Hash;
@end

/*!
	@brief
	Allow a caller to convert a binary NSData to an NSString of required base.
	The methods are defined in pairs, allowing for the string to be reinterpreted as binary data again.
 */
@interface NSData (AFBaseConversion)

+ (id)dataWithBase32String:(NSString *)string;
- (NSString *)base32String;

+ (id)dataWithBase64String:(NSString *)string;
- (NSString *)base64String;

+ (id)dataWithHexString:(NSString *)string;
- (NSString *)hexString;

@end

/*!
	@brief
	Network packet terminators.
 */
@interface NSData (AFPacketTerminator)
+ (NSData *)CRLF;
+ (NSData *)CR;
+ (NSData *)LF;
@end
