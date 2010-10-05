//
//  AFNetworkConnection.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 software. All rights reserved.
//

#import "AFNetworkConnection.h"

#import "AFNetworkTransport.h"

@implementation AFNetworkConnection

@dynamic delegate;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (AFInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
	[NSException raise:NSInvalidArgumentException format:@"%s, cannot provide an AFNetworkTransportSignature for scheme (%@)", __PRETTY_FUNCTION__, scheme, nil];
	
	AFInternetTransportSignature signature = {0};
	return signature;
}

+ (NSString *)serviceDiscoveryType {
	[NSException raise:NSInternalInconsistencyException format:@"%s, connot provide a service discovery type", __PRETTY_FUNCTION__, nil];
	return nil;
}

- (id <AFConnectionLayer>)initWithURL:(NSURL *)endpoint {
	CFHostRef host = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)[endpoint host])) autorelease];
	
	AFInternetTransportSignature transportSignature = [[self class] transportSignatureForScheme:[endpoint scheme]];
	
	if ([endpoint port] != nil) {
		transportSignature.port = [[endpoint port] integerValue];
	}
	
	AFNetworkTransportHostSignature hostSignature = {
		.host = host,
		.transport = transportSignature,
	};
	
	return (id)[self initWithTransportSignature:&hostSignature];
}

- (id <AFConnectionLayer>)initWithService:(id <AFNetServiceCommon>)service {
	CFNetServiceRef netService = (CFNetServiceRef)[NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)[(id)service valueForKey:@"domain"], (CFStringRef)[(id)service valueForKey:@"type"], (CFStringRef)[(id)service valueForKey:@"name"], 0)) autorelease];
	
	AFNetworkTransportServiceSignature serviceSignature = {
		.service = netService,
	};
	
	return (id)[self initWithTransportSignature:&serviceSignature];
}

- (AFNetworkLayer <AFConnectionLayer> *)lowerLayer {
	return [super lowerLayer];
}

- (NSURL *)peer {
	CFTypeRef peer = [(id)self.lowerLayer peer];
	
	if (CFGetTypeID(peer) == CFHostGetTypeID()) {
		CFHostRef host = (CFHostRef)peer;
		
		NSArray *hostnames = (NSArray *)CFHostGetNames(host, NULL);
		NSParameterAssert([hostnames count] == 1);
		
		return [NSURL URLWithString:[hostnames objectAtIndex:0]];
	} else if (CFGetTypeID(peer) == CFNetServiceGetTypeID()) {
		CFNetServiceRef service = (CFNetServiceRef)peer;
		
		// Note: this is assuming that the service has already been resolved
		CFStringRef host = CFNetServiceGetTargetHost(service);
		SInt32 port = CFNetServiceGetPortNumber(service);
		
		return [NSURL URLWithString:[NSString stringWithFormat:@"%@:%ld", host, port, nil]];
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine the peer name.", __PRETTY_FUNCTION__, nil];
	return nil;
}

@end
