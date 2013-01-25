//
//  AFHTTPMessage_RequestURIParsing.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/12/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFHTTPMessage_RequestURIParsing.h"

#import "AFHTTPMessagePacket.h"

@implementation AFHTTPMessage_RequestURIParsing

- (void)testAbsoluteURIRequest {
	NSData *requestData = [@"GET http://example.com/ HTTP/1.1\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
	NSInputStream *requestStream = [NSInputStream inputStreamWithData:requestData];
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease];
	
	__block NSNotification *completionNotification = nil;
	id completionListener = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkPacketDidCompleteNotificationName object:messagePacket queue:nil usingBlock:^ (NSNotification *notification) {
		completionNotification = [notification retain];
	}];
	completionNotification = [completionNotification autorelease];
	
	[requestStream open];
	NSInteger readLength = [messagePacket performRead:requestStream];
	[requestStream close];
	
	[[NSNotificationCenter defaultCenter] removeObserver:completionListener];
	
	STAssertEquals((NSUInteger)readLength, (NSUInteger)[requestData length], @"read packet should read all input data");
	STAssertNotNil(completionNotification, @"read packet should complete in a single pass");
	
	NSError *readError = [completionNotification userInfo][AFNetworkPacketErrorKey];
	STAssertNil(readError, @"read packet should complete successfully");
	
	CFHTTPMessageRef message = (CFHTTPMessageRef)[messagePacket buffer];
	
	STAssertEqualObjects(@"GET", [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(message)) autorelease], @"request method should be GET");
	STAssertEqualObjects([NSURL URLWithString:@"http://example.com/"], [NSMakeCollectable(CFHTTPMessageCopyRequestURL(message)) autorelease], @"request URL should be http://example.com/");
	STAssertEqualObjects(@"HTTP/1.1", [NSMakeCollectable(CFHTTPMessageCopyVersion(message)) autorelease], @"request version should be 1.1");
}

@end
