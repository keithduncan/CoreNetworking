//
//  NSFileManager+Verification.m
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import "NSFileManager+Additions.h"

#import <openssl/dsa.h>
#import <openssl/evp.h>
#import <openssl/pem.h>

#import <CommonCrypto/CommonDigest.h>

#import "NSData+Additions.h"

@implementation NSFileManager (AFVerificationAdditions)

- (BOOL)validatePath:(NSString *)path withMD5Hash:(NSString *)hash {
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (data == nil) return NO;
	
	int error = 0;
	
	CC_MD5_CTX state;
	error = CC_MD5_Init(&state);
	
	error = CC_MD5_Update(&state, [data bytes], [data length]);
	
	unsigned char cDigest[CC_MD5_DIGEST_LENGTH];
	error = CC_MD5_Final(cDigest, &state);
	
	NSMutableString *digest = [NSMutableString string];
	for (NSUInteger index = 0; index < CC_MD5_DIGEST_LENGTH; index++) [digest appendFormat:@"%02x", cDigest[index], nil];
	
	return [hash isEqualToString:digest];
}

- (BOOL)validatePath:(NSString *)path withDSASignature:(NSString *)encodedSignature publicDSAKey:(NSString *)publicKey {	
	if (path == nil || encodedSignature == nil || publicKey == nil) return NO;
	
	NSData *pathData = [NSData dataWithContentsOfFile:path];
	if (pathData == nil) return NO;
	
	NSData *signature = [NSData dataWithBase64String:encodedSignature];
	if (signature == nil) return NO;
	
	
	EVP_PKEY *publicDSAKey = NULL;
	
	DSA *dsa_key = NULL;
	BIO *bio = BIO_new_mem_buf((void *)[publicKey cStringUsingEncoding:NSUTF8StringEncoding], [publicKey lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
	
	if (PEM_read_bio_DSA_PUBKEY(bio, &dsa_key, NULL, NULL)) {
		publicDSAKey = EVP_PKEY_new();
		
		if (EVP_PKEY_assign_DSA(publicDSAKey, dsa_key) != 1) {
			EVP_PKEY_free(publicDSAKey);
			publicDSAKey = NULL;
		}
	}
	
	BIO_free(bio);
	
	if (publicDSAKey == NULL) return NO;
	
	unsigned char md[SHA_DIGEST_LENGTH];
	SHA1([pathData bytes], [pathData length], md);
	
	EVP_MD_CTX ctx;
	BOOL result = false;
	
	if (EVP_VerifyInit(&ctx, EVP_dss1()) == 1) {
		EVP_VerifyUpdate(&ctx, md, SHA_DIGEST_LENGTH);
		result = (EVP_VerifyFinal(&ctx, (void *)[signature bytes], [signature length], publicDSAKey) == 1);
	}
	
	EVP_MD_CTX_cleanup(&ctx);
	EVP_PKEY_free(publicDSAKey);
	
	return result;
}

@end
