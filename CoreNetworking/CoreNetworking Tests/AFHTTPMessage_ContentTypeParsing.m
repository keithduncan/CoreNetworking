//
//  AFHTTPMessage_ContentTypeParsing.m
//  CoreNetworking
//
//  Created by Keith Duncan on 09/10/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFHTTPMessage_ContentTypeParsing.h"

#import "AFHTTPMessageMediaType.h"

@implementation AFHTTPMessage_ContentTypeParsing

- (void)testNilContentType {
	STAssertNoThrow(AFHTTPMessageParseContentTypeHeader(nil), @"nil content-type headers should be supported");
}

@end
