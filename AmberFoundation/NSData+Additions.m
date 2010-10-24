//
//  NSData+Additions.m
//  AMber
//
//  File created by Keith Duncan on 04/01/2007.
//

//
//	NB: Not all of this code is mine, I can't remember where I found it either
//		The copyright notice has been ammended to reflect this
//

#import "NSData+Additions.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@implementation NSData (AFHashing)

- (NSData *)MD5Hash {
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	
	CFRetain(self);
	CC_MD5([self bytes], [self length], digest);
	CFRelease(self);
	
	return [NSData dataWithBytes:&digest length:CC_MD5_DIGEST_LENGTH];
}

- (NSData *)SHA1Hash {
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	
	CFRetain(self);
	CC_SHA1([self bytes], [self length], digest);
	CFRelease(self);
	
	return [NSData dataWithBytes:&digest length:CC_SHA1_DIGEST_LENGTH];
}

- (NSData *)HMACUsingSHA1_withSecretKey:(NSData *)secretKey {
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	
	CFRetain(self); CFRetain(secretKey);
	
	CCHmac(kCCHmacAlgSHA1, [secretKey bytes], [secretKey length], [self bytes], [self length], &digest);
	
	CFRelease(self); CFRelease(secretKey);
	
	return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

@end

@implementation NSData (AFBaseConversion)

#warning the base conversion methods should check the padding occurs only at the end
#warning the base conversion methods should check that the number of padding characters is valid

static const char _base64Alphabet[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char _base64Padding[1] = "=";

+ (id)dataWithBase64String:(NSString *)base64String {
	if (([base64String length] % 4) != 0) return nil;
	
	NSMutableCharacterSet *base64CharacterSet = [[NSMutableCharacterSet alloc] init];
	[base64CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base64Alphabet length:64 encoding:NSASCIIStringEncoding]];
	[base64CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base64Padding length:1 encoding:NSASCIIStringEncoding]];
	if ([[base64String stringByTrimmingCharactersInSet:base64CharacterSet] length] != 0) return nil;
	
	NSUInteger paddingCharacters = 0; // 2, 1, 0 are allowed
	NSRange paddingRange = NSMakeRange(NSNotFound, 0);
	do {
		paddingRange = [base64String rangeOfString:@"=" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(0, ([base64String length] - paddingCharacters))];
		if (paddingRange.location != NSNotFound) paddingCharacters++;
	} while (paddingRange.location != NSNotFound);
	if (paddingCharacters > 2) return nil;
	if ([base64String rangeOfString:@"=" options:(NSStringCompareOptions)0 range:NSMakeRange(0, ([base64String length] - paddingCharacters))].location != NSNotFound) return nil;
	
	
	NSMutableData *data = [NSMutableData dataWithCapacity:(([base64String length] / 4) * 3)];
	
	NSString *base64Alphabet = [[NSString alloc] initWithBytes:_base64Alphabet length:64 encoding:NSASCIIStringEncoding];
	CFRetain(base64String);
	
	NSUInteger characterOffset = 0;
	while (characterOffset < [base64String length]) {
		uint8_t values[4] = {0};
		for (NSUInteger valueIndex = 0; valueIndex < 4; valueIndex++) {
			unichar currentCharacter = [base64String characterAtIndex:(characterOffset + valueIndex)];
			if (currentCharacter == _base64Padding[0]) {
				// Note: each value is a 6 bit quantity, UINT8_MAX is outside that range
				values[valueIndex] = UINT8_MAX;
				continue;
			}
			
			values[valueIndex] = (uint8_t)[base64Alphabet rangeOfString:[NSString stringWithFormat:@"%C", currentCharacter]].location;
		}
		
		uint8_t bytes[3] = {0};
		
		// Note: first byte
		{
			// Note: there will always be at least two non-padding characters
			bytes[0] = bytes[0] | ((values[0] & /* 0b111111 */ 63) << 2);
			bytes[0] = bytes[0] | ((values[1] & /* 0b110000 */ 48) >> 4);
		}
		
		// Note: second byte
		{
			bytes[1] = bytes[1] | ((values[1] & /* 0b001111 */ 15) << 4);
			bytes[1] = bytes[1] | (values[2] == UINT8_MAX ? 0 : ((values[2] & /* 0b111100 */ 60) >> 2));
		}
		
		// Note: third byte
		{
			bytes[2] = bytes[2] | (values[2] == UINT8_MAX ? 0 : ((values[2] & /* 0b000011 */ 3)  << 6));
			bytes[2] = bytes[2] | (values[3] == UINT8_MAX ? 0 : ((values[3] & /* 0b111111 */ 63) << 0));
		}
		
		NSUInteger byteCount = 3;
		if (values[3] == UINT8_MAX) byteCount--;
		if (values[2] == UINT8_MAX) byteCount--;
		[data appendBytes:bytes length:byteCount];
		
		characterOffset += 4;
	}
	
	CFRelease(base64String);
	
	return data;
}

- (NSString *)base64String {
	NSMutableString *string = [NSMutableString stringWithCapacity:(([self length] / 3) * 4)];
	
	CFRetain(self);
	
	const uint8_t *currentByte = [self bytes];
	NSUInteger byteOffset = 0;
	
	while (byteOffset < [self length]) {
		// Note: every 24 bits evaluates to 4 characters
		char characters[4] = "====";
		
		// Note: first six bits depends on first byte
		if (byteOffset < [self length]) {
			uint8_t bits = (*currentByte & /* 0b11111100 */ 252) >> 2;
			characters[0] = _base64Alphabet[bits];
		}
		
		// Note: second six bits depends on first byte
		if (byteOffset < [self length]) {
			uint8_t bits = ((*currentByte & /* 0b00000011 */ 3) << 4);
			bits = bits | (((byteOffset + 1) > [self length]) ? 0 : (*(currentByte + 1) & /* 0b11110000 */ 240) >> 4);
			characters[1] = _base64Alphabet[bits];
		}
		
		// Note: third six bits depends on second byte
		if ((byteOffset + 1) < [self length]) {
			uint8_t bits = ((*(currentByte + 1) & /* 0b00001111 */ 15) << 2);
			bits = bits | (((byteOffset + 2) > [self length]) ? 0 : (*(currentByte + 2) & /* 0b11000000 */ 192) >> 6);
			characters[2] = _base64Alphabet[bits];
		}
		
		// Note: fourth six bits depends on third byte
		if ((byteOffset + 2) < [self length]) {
			uint8_t bits = *(currentByte + 2) & /* 0b00111111 */ 63;
			characters[3] = _base64Alphabet[bits];
		}
		
		[string appendString:[[NSString alloc] initWithBytes:characters length:4 encoding:NSASCIIStringEncoding]];
		
		byteOffset += 3;
		currentByte += 3;
	}
	
	CFRelease(self);
	
	return string;
}

static const char _base32Alphabet[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
static const char _base32Padding[1] = "=";

+ (id)dataWithBase32String:(NSString *)base32String {
	if (([base32String length] % 8) != 0) return nil;
	
	NSMutableCharacterSet *base32CharacterSet = [[NSMutableCharacterSet alloc] init];
	[base32CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base32Alphabet length:32 encoding:NSASCIIStringEncoding]];
	[base32CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base32Padding length:1 encoding:NSASCIIStringEncoding]];
	if ([[base32String stringByTrimmingCharactersInSet:base32CharacterSet] length] != 0) return nil;
	
	NSUInteger paddingCharacters = 0; // 6, 4, 3, 1, 0 are allowed
	NSRange paddingRange = NSMakeRange(NSNotFound, 0);
	do {
		paddingRange = [base32String rangeOfString:@"=" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(0, ([base32String length] - paddingCharacters))];
		if (paddingRange.location != NSNotFound) paddingCharacters++;
	} while (paddingRange.location != NSNotFound);
	if (paddingCharacters > 6 || (paddingCharacters == 5 || paddingCharacters == 2)) return nil;
	if ([base32String rangeOfString:@"=" options:(NSStringCompareOptions)0 range:NSMakeRange(0, ([base32String length] - paddingCharacters))].location != NSNotFound) return nil;
	
	
	NSMutableData *data = [NSMutableData dataWithCapacity:(([base32String length] / 8) * 5)];
	
	NSString *base32Alphabet = [[NSString alloc] initWithBytes:_base32Alphabet length:32 encoding:NSASCIIStringEncoding];
	CFRetain(base32String);
	
	NSUInteger characterOffset = 0;
	while (characterOffset < [base32String length]) {
		uint8_t values[8] = {0};
		for (NSUInteger valueIndex = 0; valueIndex < 8; valueIndex++) {
			unichar currentCharacter = [base32String characterAtIndex:(characterOffset + valueIndex)];
			if (currentCharacter == _base32Padding[0]) {
				// Note: each value is a 5 bit quantity, UINT8_MAX is outside that range
				values[valueIndex] = UINT8_MAX;
				continue;
			}
			
			values[valueIndex] = (uint8_t)[base32Alphabet rangeOfString:[NSString stringWithFormat:@"%C", currentCharacter]].location;
		}
		
		// Note: there will always be at least two non-padding characters
		
		NSUInteger byteCount = 0;
		uint8_t bytes[5] = {0};
		
		do {
			// Note: first byte
			{
				bytes[0] = bytes[0] | ((values[0] & /* 0b11111 */ 31) << 3);
				bytes[0] = bytes[0] | ((values[1] & /* 0b11100 */ 28) >> 2);
			}
			byteCount++;
			
			// Note: second byte
			if (values[2] == UINT8_MAX) break;
			{
				bytes[1] = bytes[1] | ((values[1] & /* 0b00011 */ 3)  << 6);
				bytes[1] = bytes[1] | ((values[2] & /* 0b11111 */ 31) << 1);
				bytes[1] = bytes[1] | ((values[3] & /* 0b10000 */ 16) >> 4);
			}
			byteCount++;
			
			// Note: third byte
			if (values[4] == UINT8_MAX) break;
			{
				bytes[2] = bytes[2] | ((values[3] & /* 0b01111 */ 15) << 4);
				bytes[2] = bytes[2] | ((values[4] & /* 0b11110 */ 30) >> 1);
			}
			byteCount++;
			
			// Note: fourth byte
			if (values[5] == UINT8_MAX) break;
			{
				bytes[3] = bytes[3] | ((values[4] & /* 0b00001 */ 1)  << 7);
				bytes[3] = bytes[3] | ((values[5] & /* 0b11111 */ 31) << 2);
				bytes[3] = bytes[3] | ((values[6] & /* 0b11000 */ 24) >> 3);
			}
			byteCount++;
			
			// Note: fifth byte
			if (values[7] == UINT8_MAX) break;
			{
				bytes[4] = bytes[4] | ((values[6] & /* 0b00111 */ 7)  << 5);
				bytes[4] = bytes[4] | ((values[7] & /* 0b11111 */ 31) << 0);
			}
			byteCount++;
		} while (NO);
		
		[data appendBytes:bytes length:byteCount];
		characterOffset += 8;
	}
	
	CFRelease(base32String);
	
	return data;
}

- (NSString *)base32String {
	NSMutableString *string = [NSMutableString stringWithCapacity:(([self length] / 5) * 8)];
	
	CFRetain(self);
	
	const uint8_t *currentByte = [self bytes];
	NSUInteger byteOffset = 0;
	
	while (byteOffset < [self length]) {
		// Note: every 40 bits evaluates to 8 characters
		char characters[8] = "========";
		
		do {
			// Note: the first five bits depend on the first byte
			{
				uint8_t bits = ((*currentByte & /* 0b11111000 */ 248) >> 3);
				characters[0] = _base32Alphabet[bits];
			}
			
			// Note: the second five bits depend on the first byte
			{
				uint8_t bits = ((*currentByte & /* 0b00000111 */ 7) << 2); 
				bits = bits | (((byteOffset + 1) > [self length]) ? 0 : ((*(currentByte + 1) & /* 0b11000000 */ 192) >> 6));
				characters[1] = _base32Alphabet[bits];
			}
			
			// Note: the third five bits depend on the second byte
			if ((byteOffset + 2) > [self length]) break;
			{
				uint8_t bits = ((*(currentByte + 1) & /* 0b00111110 */ 62) >> 1);
				characters[2] = _base32Alphabet[bits];
			}
			
			// Note: the fourth five bits depend on the second byte
			{
				uint8_t bits = ((*(currentByte + 1) & /* 0b00000001 */ 1) << 4);
				bits = bits | ((byteOffset + 2 > [self length]) ? 0 : (((*(currentByte + 2)) & /* 0b11110000 */ 240) >> 4));
				characters[3] = _base32Alphabet[bits];
			}
			
			// Note: the fifth five bits depend on the third byte
			if ((byteOffset + 3) > [self length]) break;
			{
				uint8_t bits = ((*(currentByte + 2) & /* 0b00001111 */ 15) << 1);
				bits = bits | ((byteOffset + 3 > [self length]) ? 0 : ((*(currentByte + 3) & /* 0b1000000 */ 128) >> 7));
				characters[4] = _base32Alphabet[bits];
			}
			
			// Note: the sixth five bits depend on the fourth byte
			if ((byteOffset + 4) > [self length]) break;
			{
				uint8_t bits = ((*(currentByte + 3) & /* 0b01111100 */ 124) >> 2);
				characters[5] = _base32Alphabet[bits];
			}
			
			// Note: the seventh five bits depend on the fourth byte
			{
				uint8_t bits = ((*(currentByte + 3) & /* 0b00000011 */ 3) << 3);
				bits = bits | ((byteOffset + 4 > [self length]) ? 0 : ((*(currentByte + 4) & /* 0b11100000 */ 224) >> 5));
				characters[6] = _base32Alphabet[bits];
			}
			
			// Note: the eighth five bits depend on the fifth byte
			if ((byteOffset + 5) > [self length]) break;
			{
				uint8_t bits = *(currentByte + 4) & /* 0b00011111 */ 31;
				characters[7] = _base32Alphabet[bits];
			}
		} while (NO);
		
		[string appendString:[[NSString alloc] initWithBytes:characters length:8 encoding:NSASCIIStringEncoding]];
		
		byteOffset += 5;
		currentByte += 5;
	}
	
	CFRelease(self);
	
	return string;
}

static const char _base16Alphabet[16] = "0123456789ABCDEF";

+ (id)dataWithBase16String:(NSString *)base16String {
	if (([base16String length] % 2) != 0) return nil;
	
	NSMutableCharacterSet *base16CharacterSet = [[NSMutableCharacterSet alloc] init];
	[base16CharacterSet addCharactersInString:@"0123456789"];
	[base16CharacterSet addCharactersInString:@"abcdef"];
	[base16CharacterSet addCharactersInString:@"ABCDEF"];
	if ([[base16String stringByTrimmingCharactersInSet:base16CharacterSet] length] != 0) return nil;
	
	
	NSMutableData *data = [NSMutableData dataWithCapacity:([base16String length] / 2)];
	
	NSString *base16Alphabet = [[NSString alloc] initWithBytes:_base16Alphabet length:16 encoding:NSASCIIStringEncoding];
	CFRetain(base16String);
	
	NSUInteger characterOffset = 0;
	while (characterOffset < [base16String length]) {
		uint8_t values[2] = {0};
		for (NSUInteger valueIndex = 0; valueIndex < 2; valueIndex++) {
			unichar currentCharacter = [base16String characterAtIndex:(characterOffset + valueIndex)];
			values[valueIndex] = (uint8_t)[base16Alphabet rangeOfString:[NSString stringWithFormat:@"%C", currentCharacter] options:NSCaseInsensitiveSearch].location;
		}
		
		uint8_t byte = 0;
		byte = byte | (values[0] << 4);
		byte = byte | (values[1] << 0);
		
		[data appendBytes:&byte length:1];
		characterOffset += 2;
	}
	
	CFRelease(base16String);
	
	return data;
}

- (NSString *)base16String {
	NSMutableString *string = [NSMutableString stringWithCapacity:([self length] * 2)];
	
	CFRetain(self);
	
	const uint8_t *currentByte = [self bytes];
	NSUInteger byteOffset = 0;
	
	while (byteOffset < [self length]) {
		char characters[2] = {0};
		characters[0] = _base16Alphabet[(*(currentByte + byteOffset) & /* 0b11110000 */ 240) >> 4];
		characters[1] = _base16Alphabet[(*(currentByte + byteOffset) & /* 0b00001111 */ 15)  >> 0];
		
		[string appendString:[[NSString alloc] initWithBytes:characters length:2 encoding:NSASCIIStringEncoding]];
		byteOffset++;
	}
	
	CFRelease(self);
	
	return string;
}

@end
