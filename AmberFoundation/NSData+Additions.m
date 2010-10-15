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

static const char _base64Alphabet[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrztuvwxyz0123456789+/";
static const char _base64Padding[1] = "=";

- (NSData *)dataWithBase64String:(NSString *)base64String {
	if (([base64String length] % 4) != 0) return nil;
	
	NSMutableCharacterSet *base64CharacterSet = [[NSMutableCharacterSet alloc] init];
	[base64CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base64Alphabet length:64 encoding:NSASCIIStringEncoding]];
	[base64CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base64Padding length:1 encoding:NSASCIIStringEncoding]];
	if ([[base64String stringByTrimmingCharactersInSet:base64CharacterSet] length] != 0) return nil;
	
	
	NSString *base64Alphabet = [[NSString alloc] initWithBytes:_base64Alphabet length:64 encoding:NSASCIIStringEncoding];
	
	NSMutableData *data = [NSMutableData dataWithCapacity:(([base64String length] / 4) * 3)];
	
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

+ (id)dataWithBase32String:(NSString *)encoded {
	
}

- (NSString *)base32String {
	
}

+ (id)dataWithBase16String:(NSString *)encoded {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSString *)base16String {
	NSMutableString *hexString = [NSMutableString stringWithCapacity:[self length]];
	
	const void *bytes = [self bytes];
	for (NSUInteger index = 0; index < [self length]; index++)
		[hexString appendFormat:@"%02x", *(uint8_t *)(bytes+index), nil];
	
	return hexString;
}

@end

@implementation NSData (AFPacketTerminator)

+ (NSData *)CRLF {
	return [NSData dataWithBytes:"\x0D\x0A" length:2];
}

+ (NSData *)CR {
	return [NSData dataWithBytes:"\x0D" length:1];
}

+ (NSData *)LF {
	return [NSData dataWithBytes:"\x0A" length:1];
}

@end
