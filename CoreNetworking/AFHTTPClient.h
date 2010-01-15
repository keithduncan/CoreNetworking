//
//  AFHTTPClient.h
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFHTTPConnection.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@interface AFHTTPClient : AFHTTPConnection {
	__strong CFHTTPAuthenticationRef _authentication;
	NSDictionary *_authenticationCredentials;
	
	BOOL _shouldStartTLS;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

@property (retain) CFHTTPAuthenticationRef authentication __attribute__((NSObject));
@property (copy) NSDictionary *authenticationCredentials;

@end
