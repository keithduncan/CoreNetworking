//
//  AFHTTPClient.h
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFHTTPConnection.h"

@interface AFHTTPClient : AFHTTPConnection {
	CFHTTPAuthenticationRef _authentication;
	NSDictionary *_authenticationCredentials;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

- (CFHTTPAuthenticationRef)authentication;
- (void)setAuthentication:(CFHTTPAuthenticationRef)authentication;

@property (copy) NSDictionary *authenticationCredentials;

@end
