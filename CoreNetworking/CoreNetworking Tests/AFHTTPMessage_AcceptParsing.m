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

- (void)testAcceptWithParametersAndAcceptParameters {
	NSArray *accepts = AFHTTPMessageParseAcceptHeader(@"text/plain;level=1;foo=bar;q=1;baz=qux");
	STAssertTrue([accepts count] == 1, @"only one accept should be found");
	
	AFHTTPMessageAccept *accept = [accepts lastObject];
	STAssertEqualObjects([accept type], @"text/plain", @"type should be text/plain");
	
	STAssertEqualObjects([accept parameters], ([NSDictionary dictionaryWithObjectsAndKeys:@"1", @"level", @"bar", @"foo", nil]), @"parameters should only include 'level' and 'foo' keys");
	STAssertEqualObjects([accept acceptParameters], ([NSDictionary dictionaryWithObjectsAndKeys:@"1", @"q", @"qux", @"baz", nil]), @"accept parameters should only include 'q' and 'baz' keys");
}

- (void)testAcceptWithBlank {
	NSArray *accepts = AFHTTPMessageParseAcceptHeader(@",text/plain,text/plain;level=1,,");
	STAssertTrue([accepts count] == 2, @"two types expected");
}

- (void)testAcceptChooseWithAcceptable {
	NSArray *accepts = AFHTTPMessageParseAcceptHeader(@"image/png;q=0.2,text/plain;q=1,text/*;q=0.8,*/*;q=0.1");
	
	NSString *provideType = @"image/jpeg";
	NSString *chosenType = AFHTTPMessageChooseContentTypeForAccepts(accepts, [NSArray arrayWithObject:provideType]);
	STAssertEqualObjects(chosenType, provideType, @"accept header and server provider intersection not met");
}

- (void)testAcceptChooseWithNotAcceptable {
	NSArray *accepts = AFHTTPMessageParseAcceptHeader(@"image/png;q=0.2,text/plain;q=1,text/*;q=0.8");
	
	NSString *provideType = @"image/jpeg";
	NSString *chosenType = AFHTTPMessageChooseContentTypeForAccepts(accepts, [NSArray arrayWithObject:provideType]);
	STAssertNil(chosenType, @"no intersection between client accept preference and server availability should return nil");
}

@end
