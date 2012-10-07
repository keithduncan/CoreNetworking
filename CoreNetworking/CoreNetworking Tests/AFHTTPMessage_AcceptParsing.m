//
//  AFHTTPMessage_AcceptParsing.m
//  CoreNetworking
//
//  Created by Keith Duncan on 06/10/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFHTTPMessage_AcceptParsing.h"

#import "AFHTTPMessageAccept.h"

@implementation AFHTTPMessage_AcceptParsing

- (void)testAcceptWithBlank {
	NSArray *accepts = AFHTTPMessageParseAcceptHeader(@",text/plain,text/plain;level=1");
	STAssertTrue([accepts count] == 2, @"two types expected");
}

@end
