//
//  AFCrypto.m
//  Encrypter
//
//  File created by Keith Duncan on 04/01/2007.
//

//
//	NB: Not all of this code is mine, I can't remember where I found it either
//		The copyright notice has been ammended to reflect this
//

#import "NSData+Additions.h"

#if (TARGET_OS_MAC && !(TARGET_OS_IPHONE))
#import <openssl/ssl.h>

#import <openssl/rsa.h>
#import <openssl/aes.h>
#import <openssl/md5.h>

#import <openssl/pem.h>
#import <openssl/bio.h>

#import <openssl/err.h> 
#import <openssl/engine.h>
#endif

#import <CommonCrypto/CommonDigest.h>


#if (TARGET_OS_MAC && !(TARGET_OS_IPHONE))
enum {
	ENCRYPT,
	DECRYPT
};
typedef NSUInteger AFAction;

@interface NSData (AFEncryption_Private)
- (NSData *)symmetrically:(AFAction)action withKey:(NSString *)key;
- (NSData *)asymmetrically:(AFAction)action withKey:(NSString *)key;
@end

@implementation NSData (AFEncryption)

- (NSData *)encryptWithPrivateKey:(NSString *)privateKey {
	return [self asymmetrically:ENCRYPT withKey:privateKey];
}

- (NSData *)decryptWithPublicKey:(NSString *)publicKey {
	return [self asymmetrically:DECRYPT withKey:publicKey];
}

- (NSData *)encryptWithSymmetricKey:(NSString *)key {
	return [self symmetrically:ENCRYPT withKey:key];
}

- (NSData *)decryptWithSymmetricKey:(NSString *)key {
	return [self symmetrically:DECRYPT withKey:key];
}

@end
#endif

#if (TARGET_OS_MAC && !(TARGET_OS_IPHONE))
@implementation NSData (AFEncryption_Private)

- (NSData *)symmetrically:(AFAction)action withKey:(NSString *)key {
	if (action == ENCRYPT) {
		// Create a random 128-bit initialization vector
		srand(time(NULL));
		unsigned char iv[16];
		for (int ivIndex = 0; ivIndex < 16; ivIndex++) iv[ivIndex] = arc4random() &0xff;
		
		// Calculate the 16-byte AES block padding
		int dataLength = [self length];
		int paddedLength = dataLength + (32 - (dataLength % 16));
		int totalLength = paddedLength + 16; // Data plus IV
		
		// Allocate enough space for the IV + ciphertext
		unsigned char *encryptedBytes = calloc(1, totalLength);
		// The first block of the ciphertext buffer is the IV
		memcpy(encryptedBytes, iv, 16);
		
		unsigned char *paddedBytes = calloc(1, paddedLength);
		memcpy(paddedBytes, [self bytes], dataLength);
		
		// The last 32-bit chunk is the size of the plaintext, which is encrypted with the plaintext
		int bigIntDataLength = NSSwapHostIntToBig(dataLength);
		memcpy(paddedBytes + (paddedLength - 4), &bigIntDataLength, 4);
		
		// Create the key from first 128-bits of the 160-bit password hash
		unsigned char passwordDigest[20];
		SHA1((const unsigned char *)[key UTF8String], strlen([key UTF8String]), passwordDigest);
		
		AES_KEY aesKey;
		AES_set_encrypt_key(passwordDigest, 128, &aesKey);
		
		// AES-128-cbc encrypt the data, filling in the buffer after the IV
		AES_cbc_encrypt(paddedBytes, encryptedBytes + 16, paddedLength, &aesKey, iv, AES_ENCRYPT);
		free(paddedBytes);
		
		return [NSData dataWithBytesNoCopy:encryptedBytes length:totalLength];
	} else {
		// Create the key from the password hash
		unsigned char passwordDigest[20];
		SHA1((const unsigned char *)[key UTF8String], strlen([key UTF8String]), passwordDigest);
		
		AES_KEY aesKey;
		AES_set_decrypt_key(passwordDigest, 128, &aesKey);
		
		// Total length = encrypted length + IV
		int totalLength = [self length];
		int encryptedLength = totalLength - 16;
		
		// Take the IV from the first 128-bit block
		unsigned char iv[16];
		memcpy(iv, [self bytes], 16);
		
		// Decrypt the data
		unsigned char *decryptedBytes = malloc(encryptedLength);
		AES_cbc_encrypt([self bytes] + 16, decryptedBytes, encryptedLength, &aesKey, iv, AES_DECRYPT);
		
		// If decryption was successful, these blocks will be zeroed
		if ((unsigned int *)decryptedBytes + ((encryptedLength / 4) - 4) != 0) return nil;
		if ((unsigned int *)decryptedBytes + ((encryptedLength / 4) - 3) != 0) return nil;
		if ((unsigned int *)decryptedBytes + ((encryptedLength / 4) - 2) != 0) return nil;
		
		// Get the size of the data from the last 32-bit chunk
		int bigIntDataLength = *((unsigned int *)decryptedBytes + ((encryptedLength / 4) - 1));
		int dataLength = NSSwapBigIntToHost(bigIntDataLength);
		
		return [NSData dataWithBytesNoCopy:decryptedBytes length:dataLength];
	}
}

- (NSData *)asymmetrically:(AFAction)action withKey:(NSString *)key {
	if (key == nil) [NSException raise:NSInvalidArgumentException format:@"-[NSData(PrivateEncryption) %s] was passed an nil argument.", _cmd];
	
	NSInteger inlen = [self length];
	unsigned char *input = (unsigned char *)[self bytes];
	
	OpenSSL_add_all_algorithms();
	ERR_load_crypto_strings();
	
	NSData *keyData = [NSData dataWithBytes:[key cStringUsingEncoding:NSASCIIStringEncoding] length:[key lengthOfBytesUsingEncoding:NSASCIIStringEncoding]];
	
	BIO *keyBIO = NULL; RSA *keyRSA = NULL;
	
	if (!(keyBIO = BIO_new_mem_buf((unsigned char *)[keyData bytes], [keyData length]))) {
		NSLog(@"BIO_new_mem_buf(); failed");
		return nil;
	}
	
	BOOL encrypting = (action == ENCRYPT);
	if (encrypting) {
		if (!PEM_read_bio_RSAPrivateKey(keyBIO, &keyRSA, NULL, NULL)) {
			NSLog(@"PEM_read_bio_RSAPrivateKey(); failed");
			return nil;
		}
		
		// RSA_check_key() returns 1 if rsa is a valid RSA key, and 0 otherwise.
		unsigned long check = RSA_check_key(keyRSA);
		if (check != 1) {
			NSLog(@"RSA_check_key(); returned %d", check);
			return nil;
		}
	} else {
		if (!PEM_read_bio_RSA_PUBKEY(keyBIO, &keyRSA, NULL, NULL)) {
			NSLog(@"PEM_read_bio_RSA_PUBKEY(); failed");
			return nil;
		}
	}
	
	NSInteger outlen;
	unsigned char *outbuf = (unsigned char *)malloc(RSA_size(keyRSA));
	
	if (encrypting) {
		if(!(outlen = RSA_private_encrypt(inlen, input, outbuf, keyRSA, RSA_PKCS1_PADDING))) {
			NSLog(@"RSA_private_encrypt(); failed");
			return nil;
		}
	} else {
		if (!(outlen = RSA_public_decrypt(inlen, input, outbuf, keyRSA, RSA_PKCS1_PADDING))) {
			NSLog(@"RSA_public_decrypt(); failed");
			return nil;
		}
	}
	
	if (outlen == -1) {
		NSLog(@"%@ error: %s (%s)", (encrypting ? @"Encrypt" : @"Decrypt"), ERR_error_string(ERR_get_error(), NULL), ERR_reason_error_string(ERR_get_error()));
		return nil;
	}
	
	EVP_cleanup();
	ERR_free_strings();
	
	if (keyBIO != NULL) BIO_free(keyBIO); if (keyRSA != NULL) RSA_free(keyRSA);
	
	return [NSData dataWithBytesNoCopy:outbuf length:outlen];
}

@end
#endif

@implementation NSData (AFHashing)

- (NSData *)MD5Hash {	
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5([self bytes], [self length], digest);
	
	return [NSData dataWithBytes:&digest length:CC_MD5_DIGEST_LENGTH];
}

- (NSData *)SHA1Hash {
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1([self bytes], [self length], digest);
	
	return [NSData dataWithBytes:&digest length:CC_SHA1_DIGEST_LENGTH];
}

@end

@implementation NSData (AFBaseConversion)

+ (id)dataWithBase32String:(NSString *)encoded {
	// First valid character that can be indexed in decode lookup table
	static int charDigitsBase = '2';
	
	// Lookup table used to decode() characters in encoded strings
	static int charDigits[] = {
		26,27,28,29,30,31,-1,-1,-1,-1,-1,-1,-1,-1,		 // 23456789:;<=>?
		-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14, // @ABCDEFGHIJKLMNO
		15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1, // PQRSTUVWXYZ[\]^_
		-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14, // `abcdefghijklmno
		15,16,17,18,19,20,21,22,23,24,25				 // pqrstuvwxyz
	};
	
	if (![encoded canBeConvertedToEncoding:NSASCIIStringEncoding]) return nil;
	const char *chars = [encoded cStringUsingEncoding:NSASCIIStringEncoding]; // avoids using characterAtIndex.
	int charsLen = [encoded length];
	
	// Note that the code below could detect non canonical Base32 length within the loop. However canonical Base32 length can be tested before entering the loop.
	// A canonical Base32 length modulo 8 cannot be:
	// 1 (aborts discarding 5 bits at STEP n=0 which produces no byte),
	// 3 (aborts discarding 7 bits at STEP n=2 which produces no byte),
	// 6 (aborts discarding 6 bits at STEP n=1 which produces no byte).
	switch (charsLen & 7) { // test the length of last subblock
		case 1: //  5 bits in subblock:  0 useful bits but 5 discarded
		case 3: // 15 bits in subblock:  8 useful bits but 7 discarded
		case 6: // 30 bits in subblock: 24 useful bits but 6 discarded
			return nil; // non-canonical length
	}
	
	int bytesOffset = 0, charsOffset = 0;
	int charDigitsLen = sizeof(charDigits);
	
	int bytesLen = ((charsLen * 5) >> 3);
	Byte bytes[bytesLen];
	
	// Also the code below does test that other discarded bits
	// (1 to 4 bits at end) are effectively 0.
	while (charsLen > 0) {
		int digit, lastDigit;
		// STEP n = 0: Read the 1st Char in a 8-Chars subblock
		// Leave 5 bits, asserting there's another encoding Char
		if ((digit = (int)chars[charsOffset] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		lastDigit = digit << 3;
		// STEP n = 5: Read the 2nd Char in a 8-Chars subblock
		// Insert 3 bits, leave 2 bits, possibly trailing if no more Char
		if ((digit = (int)chars[charsOffset + 1] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		bytes[bytesOffset] = (Byte)((digit >> 2) | lastDigit);
		lastDigit = (digit & 3) << 6;
		if (charsLen == 2) {
			if (lastDigit != 0) return nil; // non-canonical end
			break; // discard the 2 trailing null bits
		}
		// STEP n = 2: Read the 3rd Char in a 8-Chars subblock
		// Leave 7 bits, asserting there's another encoding Char
		if ((digit = (int)chars[charsOffset + 2] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		lastDigit |= (Byte)(digit << 1);
		// STEP n = 7: Read the 4th Char in a 8-chars Subblock
		// Insert 1 bit, leave 4 bits, possibly trailing if no more Char
		if ((digit = (int)chars[charsOffset + 3] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		bytes[bytesOffset + 1] = (Byte)((digit >> 4) | lastDigit);
		lastDigit = (Byte)((digit & 15) << 4);
		if (charsLen == 4) {
			if (lastDigit != 0) return nil; // non-canonical end
			break; // discard the 4 trailing null bits
		}
		// STEP n = 4: Read the 5th Char in a 8-Chars subblock
		// Insert 4 bits, leave 1 bit, possibly trailing if no more Char
		if ((digit = (int)chars[charsOffset + 4] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		bytes[bytesOffset + 2] = (Byte)((digit >> 1) | lastDigit);
		lastDigit = (Byte)((digit & 1) << 7);
		if (charsLen == 5) {
			if (lastDigit != 0) return nil; // non-canonical end
			break; // discard the 1 trailing null bit
		}
		// STEP n = 1: Read the 6th Char in a 8-Chars subblock
		// Leave 6 bits, asserting there's another encoding Char
		if ((digit = (int)chars[charsOffset + 5] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		lastDigit |= (Byte)(digit << 2);
		// STEP n = 6: Read the 7th Char in a 8-Chars subblock
		// Insert 2 bits, leave 3 bits, possibly trailing if no more Char
		if ((digit = (int)chars[charsOffset + 6] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		bytes[bytesOffset + 3] = (Byte)((digit >> 3) | lastDigit);
		lastDigit = (Byte)((digit & 7) << 5);
		if (charsLen == 7) {
			if (lastDigit != 0) return nil; // non-canonical end
			break; // discard the 3 trailing null bits
		}
		// STEP n = 3: Read the 8th Char in a 8-Chars subblock
		// Insert 5 bits, leave 0 bit, next encoding Char may not exist
		if ((digit = (int)chars[charsOffset + 7] - charDigitsBase) < 0 || digit >= charDigitsLen || (digit = charDigits[digit]) == -1)
			return nil; // invalid character
		bytes[bytesOffset + 4] = (Byte)(digit | lastDigit);
		//// This point is always reached for chars.length multiple of 8
		charsOffset += 8;
		bytesOffset += 5;
		charsLen -= 8;
	}
	// On loop exit, discard the n trailing null bits
	return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

- (NSString *)base32String {
	// Lookup table used to canonically encode() groups of data bits
	static char canonicalChars[32] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M', // 00..12
		'N','O','P','Q','R','S','T','U','V','W','X','Y','Z', // 13..25
		'2','3','4','5','6','7'                              // 26..31
	};
	
	const Byte *bytes = [self bytes];
	int bytesLen = [self length];
	
	int bytesOffset = 0, charsOffset = 0;
	
	int charsLen = ((bytesLen << 3) + 4)/5;
	char chars[charsLen];
	
	while (bytesLen != 0) {
		int digit, lastDigit;
		// INVARIANTS FOR EACH STEP n in [0..5[; digit in [0..31[;
		// The remaining n bits are already aligned on top positions
		// of the 5 least bits of digit, the other bits are 0.
		////// STEP n = 0: insert new 5 bits, leave 3 bits
		digit = bytes[bytesOffset] & 255;
		chars[charsOffset] = canonicalChars[digit >> 3];
		lastDigit = (digit & 7) << 2;
		if (bytesLen == 1) { // put the last 3 bits
			chars[charsOffset + 1] = canonicalChars[lastDigit];
			break;
		}
		////// STEP n = 3: insert 2 new bits, then 5 bits, leave 1 bit
		digit = bytes[bytesOffset + 1] & 255;
		chars[charsOffset + 1] = canonicalChars[(digit >> 6) | lastDigit];
		chars[charsOffset + 2] = canonicalChars[(digit >> 1) & 31];
		lastDigit = (digit & 1) << 4;
		if (bytesLen == 2) { // put the last 1 bit
			chars[charsOffset + 3] = canonicalChars[lastDigit];
			break;
		}
		////// STEP n = 1: insert 4 new bits, leave 4 bit
		digit = bytes[bytesOffset + 2] & 255;
		chars[charsOffset + 3] = canonicalChars[(digit >> 4) | lastDigit];
		lastDigit = (digit & 15) << 1;
		if (bytesLen == 3) { // put the last 1 bits
			chars[charsOffset + 4] = canonicalChars[lastDigit];
			break;
		}
		////// STEP n = 4: insert 1 new bit, then 5 bits, leave 2 bits
		digit = bytes[bytesOffset + 3] & 255;
		chars[charsOffset + 4] = canonicalChars[(digit >> 7) | lastDigit];
		chars[charsOffset + 5] = canonicalChars[(digit >> 2) & 31];
		lastDigit = (digit & 3) << 3;
		if (bytesLen == 4) { // put the last 2 bits
			chars[charsOffset + 6] = canonicalChars[lastDigit];
			break;
		}
		////// STEP n = 2: insert 3 new bits, then 5 bits, leave 0 bit
		digit = bytes[bytesOffset + 4] & 255;
		chars[charsOffset + 6] = canonicalChars[(digit >> 5) | lastDigit];
		chars[charsOffset + 7] = canonicalChars[digit & 31];
		//// This point is always reached for bytes.length multiple of 5
		bytesOffset += 5;
		charsOffset += 8;
		bytesLen -= 5;
	}
	
	return [NSString stringWithCString:chars length:sizeof(chars)];
}

//
// Base64 methods copyright notice
// Taken from MGTwitterEngine, original copyright notice below
//
// NSData+Base64.m
//
// Derived from http://colloquy.info/project/browser/trunk/NSDataAdditions.h?rev=1576
// Created by khammond on Mon Oct 29 2001.
// Formatted by Timothy Hatcher on Sun Jul 4 2004.
// Copyright (c) 2001 Kyle Hammond. All rights reserved.
// Original development by Dave Winer.
//

+ (id)dataWithBase64String:(NSString *)encoded {
	NSParameterAssert(encoded != nil);
	
	unsigned long ixtext = 0;
	unsigned char ch = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0, ixinbuf = 0;
	BOOL flignore = NO;
	BOOL flendtext = NO;
	
	NSData *base64Data = [encoded dataUsingEncoding:NSASCIIStringEncoding];
	const unsigned char *base64Bytes = [base64Data bytes];
	
	NSMutableData *mutableData = [NSMutableData dataWithCapacity:[base64Data length]];
	unsigned long lentext = [base64Data length];
	
	while (YES) {
		if(ixtext >= lentext) break;
		ch = base64Bytes[ixtext++];
		flignore = NO;
		
		if( ( ch >= 'A' ) && ( ch <= 'Z' ) ) ch = ch - 'A';
		else if( ( ch >= 'a' ) && ( ch <= 'z' ) ) ch = ch - 'a' + 26;
		else if( ( ch >= '0' ) && ( ch <= '9' ) ) ch = ch - '0' + 52;
		else if( ch == '+' ) ch = 62;
		else if( ch == '=' ) flendtext = YES;
		else if( ch == '/' ) ch = 63;
		else flignore = YES; 
		
		if( ! flignore ) {
			short ctcharsinbuf = 3;
			BOOL flbreak = NO;
			
			if( flendtext ) {
				if( ! ixinbuf ) break;
				if( ( ixinbuf == 1 ) || ( ixinbuf == 2 ) ) ctcharsinbuf = 1;
				else ctcharsinbuf = 2;
				ixinbuf = 3;
				flbreak = YES;
			}
			
			inbuf [ixinbuf++] = ch;
			
			if( ixinbuf == 4 ) {
				ixinbuf = 0;
				outbuf [0] = ( inbuf[0] << 2 ) | ( ( inbuf[1] & 0x30) >> 4 );
				outbuf [1] = ( ( inbuf[1] & 0x0F ) << 4 ) | ( ( inbuf[2] & 0x3C ) >> 2 );
				outbuf [2] = ( ( inbuf[2] & 0x03 ) << 6 ) | ( inbuf[3] & 0x3F );
				
				for( i = 0; i < ctcharsinbuf; i++ ) 
					[mutableData appendBytes:&outbuf[i] length:1];
			}
			
			if( flbreak )  break;
		}
	}
	
	return mutableData;
}

- (NSString *)base64String {
	static char encodingTable[64] = {
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
		'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
	'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };
	
	const unsigned char	*bytes = [self bytes];
	NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
	unsigned long ixtext = 0;
	unsigned long lentext = [self length];
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;
	
	while( YES ) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;
		
		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}
		
		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;
		
		switch( ctremaining ) {
			case 1: 
				ctcopy = 2; 
				break;
			case 2: 
				ctcopy = 3; 
				break;
		}
		
		for( i = 0; i < ctcopy; i++ )
			[result appendFormat:@"%c", encodingTable[outbuf[i]]];
		
		for( i = ctcopy; i < 4; i++ )
			[result appendFormat:@"%c",'='];
		
		ixtext += 3;
		charsonline += 4;
	}
	
	return result;
}

+ (id)dataWithHexString:(NSString *)string {
	[self doesNotRecognizeSelector:_cmd];
}

- (NSString *)hexString {
	NSMutableString *hexString = [[NSMutableString alloc] initWithCapacity:[self length]];
	
	const void *bytes = [self bytes];
	for (NSUInteger index = 0; index < [self length]; index++)
		[hexString appendFormat:@"%02x", *(uint8_t **)(bytes+index), nil];
	
	NSString *value = [[hexString copy] autorelease];
	[hexString release];
	
	return value;
}

@end
