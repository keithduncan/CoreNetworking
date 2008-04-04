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

#import "md5.h"
#import "NSData+Additions.h"

@implementation NSFileManager (VerificationAdditions)

- (BOOL)validatePath:(NSString *)path withMD5Hash:(NSString *)hash {
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (data == nil) return NO;
	
	md5_state_t md5_state;
	md5_init(&md5_state);
	md5_append(&md5_state, [data bytes], [data length]);
	unsigned char digest[16];
	md5_finish(&md5_state, digest);
	
	char hexDigest[32];
	for (int di = 0; di < 16; di++) sprintf(hexDigest + di*2, "%02x", digest[di]);
	
	return [hash isEqualToString:[NSString stringWithCString:hexDigest]];
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
