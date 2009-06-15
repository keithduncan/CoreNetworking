//
//  AFHTTPClient.m
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPClient.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFNetworkConstants.h"

@interface AFHTTPClient (Private)
- (BOOL)_shouldStartTLS;
@end

@implementation AFHTTPClient

@synthesize authenticationCredentials=_authenticationCredentials;

static NSString *_AFHTTPConnectionUserAgentFromBundle(NSBundle *bundle) {
	return [NSString stringWithFormat:@"%@/%@", [[bundle displayName] stringByReplacingOccurrencesOfString:@" " withString:@"-"], [[bundle displayVersion] stringByReplacingOccurrencesOfString:@" " withString:@"-"], nil];
}

+ (void)initialize {
	NSBundle *application = [NSBundle mainBundle], *framework = [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier];
	NSString *userAgent = [NSString stringWithFormat:@"%@ %@", _AFHTTPConnectionUserAgentFromBundle(application), _AFHTTPConnectionUserAgentFromBundle(framework), nil];
	[self setUserAgent:userAgent];
}

static NSString *_AFHTTPConnectionUserAgent = nil;

+ (NSString *)userAgent {
	NSString *agent = nil;
	@synchronized ([AFHTTPConnection class]) {
		agent = [[_AFHTTPConnectionUserAgent retain] autorelease];
	}
	return agent;
}

+ (void)setUserAgent:(NSString *)userAgent {
	@synchronized ([AFHTTPConnection class]) {
		[_AFHTTPConnectionUserAgent release];
		_AFHTTPConnectionUserAgent = [userAgent copy];
	}
}

- (void)dealloc {
	[self setAuthentication:NULL];
	[_authenticationCredentials release];
	
	[super dealloc];
}

- (void)finalize {
	[self setAuthentication:NULL];
	
	[super finalize];
}

- (CFHTTPAuthenticationRef)authentication {
	return _authentication;
}

- (void)setAuthentication:(CFHTTPAuthenticationRef)authentication {
	if (_authentication != NULL) CFRelease(_authentication);
	
	_authentication = authentication;
	if (authentication == NULL) return;
	
	_authentication = (CFHTTPAuthenticationRef)CFRetain(authentication);
}

- (void)connectionWillPerformRequest:(CFHTTPMessageRef)request {
	[super connectionWillPerformRequest:request];
	
	NSString *agent = [[self class] userAgent];
	if (agent != nil) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageUserAgentHeader, (CFStringRef)agent);
	}
	
	if (self.authentication != NULL) {
		CFStreamError error;
		
		Boolean authenticated = NO;
		authenticated = CFHTTPMessageApplyCredentialDictionary(request, self.authentication, (CFDictionaryRef)self.authenticationCredentials, &error);
	}
}

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if ([self _shouldStartTLS]) {
		NSDictionary *securityOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										 (id)kCFStreamSocketSecurityLevelNegotiatedSSL, (id)kCFStreamSSLLevel,
										 nil];
		
		[self startTLS:securityOptions];
	}
	
	[self.delegate layerDidOpen:self];
}

@end

@implementation AFHTTPClient (Private)

- (BOOL)_shouldStartTLS {
	NSURL *peer = [self peer];
	
	if (CFGetTypeID([(id)self.lowerLayer peer]) == CFHostGetTypeID()) {
		return ([AFNetworkSchemeHTTPS compare:[peer scheme] options:NSCaseInsensitiveSearch] == NSOrderedSame);
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine wether to start TLS.", __PRETTY_FUNCTION__, nil];
	return NO;
}

@end
