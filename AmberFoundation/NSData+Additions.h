//
//  NSData+Additions.h
//  Amber
//
//  Created by Keith Duncan on 04/01/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\brief
	Wrapper around the CommonCrypto hashing functions.
	These data objects are unlikely to be used raw, there are a number of base conversion methods in the <tt>NSData (AFBaseConversion)</tt> category.
 */
@interface NSData (AFHashing)

- (NSData *)MD5Hash;
- (NSData *)SHA1Hash;

- (NSData *)HMACUsingSHA1_withSecretKey:(NSData *)secretKey;

@end

/*!
	\brief
	Allow a caller to convert a binary NSData to an NSString of required base.
	The methods are defined in pairs, allowing for the string to be reinterpreted as binary data again.
 */
@interface NSData (AFBaseConversion)

/*!
	\brief
	Decode a base64 string, this encoding is defined in IETF-RFC-4648 §4 http://tools.ietf.org/html/rfc4648#section-4
	
	\return
	nil if the <tt>base64String</tt> parameter is not a valid base64 encoding.
 */
+ (id)dataWithBase64String:(NSString *)base64String;

/*!
	\brief
	Encode the receiver into a base64 string, this encoding is defined in IETF-RFC-4648 §4 http://tools.ietf.org/html/rfc4648#section-4
 */
- (NSString *)base64String;

/*!
	\brief
	Decode a base32 string, this encoding is defined in IETF-RFC-4648 §6 http://tools.ietf.org/html/rfc4648#section-6
	
	\return
	nil if the <tt>base32String</tt> parameter is not a valid base32 encoding.
 */
+ (id)dataWithBase32String:(NSString *)base32String;

/*!
	\brief
	Encode the receiver into a base32 string, this encoding is defined in IETF-RFC-4648 §6 http://tools.ietf.org/html/rfc4648#section-8
 */
- (NSString *)base32String;

/*!
	\brief
	Decode a base16 string, this encoding is defined in IETF-RFC-4648 §8 http://tools.ietf.org/html/rfc4648#section-8
	
	\return
	nil if the <tt>base16String</tt> parameter is not a valid base16 encoding.
 */
+ (id)dataWithBase16String:(NSString *)base16String;

/*!
	\brief
	Encode the receiver into a base16 string, this encoding is defined in IETF-RFC-4648 §8 http://tools.ietf.org/html/rfc4648#section-8
 */
- (NSString *)base16String;

@end

/*!
	\brief
	Network packet terminators.
 */
@interface NSData (AFPacketTerminator)

+ (NSData *)CRLF;
+ (NSData *)CR;
+ (NSData *)LF;

@end
