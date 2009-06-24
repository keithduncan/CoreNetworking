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

- (id)initWithURL:(NSURL *)endpoint {
	self = (id)[super initWithURL:(NSURL *)endpoint];
	if (self == nil) return nil;
	
	_shouldStartTLS = ([AFNetworkSchemeHTTPS compare:[endpoint scheme] options:NSCaseInsensitiveSearch] == NSOrderedSame);
	
	return self;
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

- (void)performWrite:(CFHTTPMessageRef)message forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	NSString *agent = [[self class] userAgent];
	if (agent != nil) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageUserAgentHeader, (CFStringRef)agent);
	}
	
	if (self.authentication != NULL) {
		CFStreamError error;
		
		Boolean authenticated = NO;
		authenticated = CFHTTPMessageApplyCredentialDictionary(message, self.authentication, (CFDictionaryRef)self.authenticationCredentials, &error);
	}
	
	[super performWrite:message forTag:tag withTimeout:duration];
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
	if (CFGetTypeID([(id)self.lowerLayer peer]) == CFHostGetTypeID()) {
		return _shouldStartTLS;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine wether to start TLS.", __PRETTY_FUNCTION__, nil];
	return NO;
}

@end