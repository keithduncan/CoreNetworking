//
//  AFNetworkService-Functions.m
//  CoreNetworking
//
//  Created by Keith Duncan on 22/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkService-Functions.h"

#import <objc/message.h>
#import <dns_sd.h>

#import "AFNetwork-Constants.h"

NSData *AFNetworkServiceTXTRecordDataFromPropertyDictionary(NSDictionary *TXTRecordDictionary) {
	/*
		Note:
		
		`CFNetServiceCreateTXTDataWithDictionary()` purports to implement this flattening behaviour too
		
		we provide both transforms, and so we implement this function ourselves for completeness sake
	 */
	
	TXTRecordRef TXTRecord = {};
	TXTRecordCreate(&TXTRecord, 0, NULL);
	
	for (NSString *currentKey in [TXTRecordDictionary allKeys]) {
		NSCParameterAssert([currentKey canBeConvertedToEncoding:NSASCIIStringEncoding]);
		
		NSString *currentValue = [TXTRecordDictionary objectForKey:currentKey];
		NSCParameterAssert([currentValue isKindOfClass:[NSString class]]);
		
		if (![currentValue canBeConvertedToEncoding:NSUTF8StringEncoding]) {
			continue;
		}
		NSData *encodedCurrentValue = [currentValue dataUsingEncoding:NSUTF8StringEncoding];
		if ([encodedCurrentValue length] > UINT8_MAX) {
			continue;
		}
		
		CFRetain(encodedCurrentValue);
		TXTRecordSetValue(&TXTRecord, [currentKey cStringUsingEncoding:NSASCIIStringEncoding], [encodedCurrentValue length], [encodedCurrentValue bytes]);
		CFRelease(encodedCurrentValue);
	}
	
	NSData *TXTRecordData = [NSData dataWithBytes:TXTRecordGetBytesPtr(&TXTRecord) length:TXTRecordGetLength(&TXTRecord)];
	TXTRecordDeallocate(&TXTRecord);
	
	return TXTRecordData;
}

NSDictionary *AFNetworkServicePropertyDictionaryFromTXTRecordData(NSData *TXTRecordData) {
	if ([TXTRecordData length] > UINT16_MAX) {
		return nil;
	}
	
	CFRetain(TXTRecordData);
	
	uint16_t TXTRecordCount = TXTRecordGetCount([TXTRecordData length], [TXTRecordData bytes]);
	
	NSMutableDictionary *TXTRecordDictionary = [NSMutableDictionary dictionaryWithCapacity:TXTRecordCount];
	
	for (NSUInteger idx = 0; idx < TXTRecordCount; idx++) {
		size_t currentKeyLength = 256;
		char *currentKey = alloca(currentKeyLength);
		
		uint8_t valueLength = 0;
		void *value = NULL;
		
		TXTRecordGetItemAtIndex([TXTRecordData length], [TXTRecordData bytes], idx, currentKeyLength, currentKey, &valueLength, (void const **)&value);
		
		NSString *keyString = [NSString stringWithCString:currentKey encoding:NSASCIIStringEncoding];
		if (keyString == nil) {
			continue;
		}
		
		NSString *valueString = nil;
		if (value != NULL) {
			if (valueLength > 0) {
				valueString = [[[NSString alloc] initWithBytes:value length:valueLength encoding:NSUTF8StringEncoding] autorelease];
			}
			else {
				valueString = @"";
			}
		}
		else {
			valueString = (id)[NSNull null];
		}
		
		if ([TXTRecordDictionary objectForKey:keyString] != nil) {
			continue;
		}
		[TXTRecordDictionary setObject:valueString forKey:keyString];
	}
	
	CFRelease(TXTRecordData);
	
	return TXTRecordDictionary;
}
