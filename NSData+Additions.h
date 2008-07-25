//
//  AFCrypto.h
//  Encrypter
//
//  Created by Keith Duncan on 04/01/2007.
//  Copyright 2007 dAX development. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Encryption)
- (NSData *)encryptWithPrivateKey:(NSString *)privateKey;
- (NSData *)decryptWithPublicKey:(NSString *)publicKey;

- (NSData *)encryptWithSymmetricKey:(NSString *)key;
- (NSData *)decryptWithSymmetricKey:(NSString *)key;
@end

@interface NSData (Hashing)
- (NSData *)MD5Hash;
- (NSData *)SHA1Hash;
@end

@interface NSData (BaseConversion)
+ (id)dataWithBase32String:(NSString *)string;
- (NSString *)base32String;

+ (id)dataWithBase64String:(NSString *)string;
- (NSString *)base64String;
@end
