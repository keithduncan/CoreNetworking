//
//  AFNetwork-Functions-Tests.m
//  CoreNetworking
//
//  Created by Keith Duncan on 03/03/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetwork-Functions-Tests.h"

#import "CoreNetworking/CoreNetworking.h"

@implementation AFNetwork_Functions_Tests

- (void)testPtonWithEmptyData
{
	NSError *presentationError = nil;
	NSString *presentation = AFNetworkSocketAddressToPresentation([NSData data], &presentationError);
	
	STAssertNil(presentation, @"empty data should fail to parse");
	STAssertNotNil(presentationError, @"empty data parse should return an error");
}

- (void)testPtonWithSingleByte
{
	NSError *presentationError = nil;
	NSString *presentation = AFNetworkSocketAddressToPresentation([NSData dataWithBytes:"\x1" length:1], &presentationError);
	
	STAssertNil(presentation, @"data with single byte should fail to parse");
	STAssertNotNil(presentationError, @"data with single byte should return error");
}

- (void)testPtonWithSingleByteButTenBytePrefix
{
	NSError *presentationError = nil;
	NSString *presentation = AFNetworkSocketAddressToPresentation([NSData dataWithBytes:"\xA" length:1], &presentationError);
	
	STAssertNil(presentation, @"data with single byte but internal length of ten should fail to parse");
	STAssertNotNil(presentationError, @"data with single byte but internal length of ten should return error");
}

@end
