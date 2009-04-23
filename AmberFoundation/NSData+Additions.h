//
//  AFCrypto.h
//  Encrypter
//
//  Created by Keith Duncan on 04/01/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC && !TARGET_OS_IPHONE
@interface NSData (AFEncryption)
// Note: these probably need revising anyway...
- (NSData *)encryptWithPrivateKey:(NSString *)privateKey;
- (NSData *)decryptWithPublicKey:(NSString *)publicKey;

- (NSData *)encryptWithSymmetricKey:(NSString *)key;
- (NSData *)decryptWithSymmetricKey:(NSString *)key;
@end
#endif

@interface NSData (AFHashing)
- (NSData *)MD5Hash;
- (NSData *)SHA1Hash;
@end

@interface NSData (AFBaseConversion)
+ (id)dataWithBase32String:(NSString *)string;
- (NSString *)base32String;

+ (id)dataWithBase64String:(NSString *)string;
- (NSString *)base64String;

+ (id)dataWithHexString:(NSString *)string;
- (NSString *)hexString;
@end

@interface NSData (AFPacketTerminator)
+ (NSData *)CRLF;
+ (NSData *)CR;
+ (NSData *)LF;
@end
