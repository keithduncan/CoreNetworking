//
//  AFNetworkConnection.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkConnection.h"

#import "AFNetworkTransport.h"

@implementation AFNetworkConnection

@dynamic delegate;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (AFInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
#warning this method should parse /etc/services to determine the default port mappings
	[NSException raise:NSInvalidArgumentException format:@"%s, cannot provide an AFNetworkTransportSignature for scheme (%@)", __PRETTY_FUNCTION__, scheme, nil];
	
	AFInternetTransportSignature signature;
	bzero(&signature, sizeof(signature));
	
	return signature;
}

+ (NSString *)serviceDiscoveryType {
	[NSException raise:NSInternalInconsistencyException format:@"%s, connot provide a service discovery type", __PRETTY_FUNCTION__, nil];
	return nil;
}

- (id <AFTransportLayer>)initWithURL:(NSURL *)endpoint {
	CFHostRef host = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)[endpoint host])) autorelease];
	
	AFInternetTransportSignature transportSignature = [[self class] transportSignatureForScheme:[endpoint scheme]];
	
	if ([endpoint port] != nil) {
		transportSignature.port = [[endpoint port] integerValue];
	}
	
	AFNetworkTransportHostSignature peerSignature = {
		.host = host,
		.transport = transportSignature,
	};
	
	return [self initWithPeerSignature:&peerSignature];
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
