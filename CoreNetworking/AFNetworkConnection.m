//
//  AFNetworkConnection.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkConnection.h"

#import "AFNetworkTransport.h"

#import "AFNetwork-Functions.h"

@implementation AFNetworkConnection

@dynamic delegate;

+ (Class)lowerLayerClass {
	return [AFNetworkTransport class];
}

+ (AFNetworkInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, cannot provide an AFNetworkInternetTransportSignature for scheme (%@)", __PRETTY_FUNCTION__, scheme] userInfo:nil];
}

+ (NSString *)serviceDiscoveryType {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, connot provide a service discovery type", __PRETTY_FUNCTION__] userInfo:nil];
}

- (id)initWithURL:(NSURL *)endpoint {
	CFHostRef host = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)[endpoint host])) autorelease];
	
	AFNetworkInternetTransportSignature transportSignature = [[self class] transportSignatureForScheme:[endpoint scheme]];
	
	if ([endpoint port] != nil) {
		transportSignature.port = [[endpoint port] integerValue];
	}
	
	AFNetworkHostSignature hostSignature = {
		.host = host,
		.transport = transportSignature,
	};
	
	return [self initWithTransportSignature:&hostSignature];
}

- (id)initWithService:(AFNetworkServiceScope *)serviceScope {
	CFNetServiceRef netService = (CFNetServiceRef)[NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)[serviceScope domain], (CFStringRef)[serviceScope type], (CFStringRef)[serviceScope name], 0)) autorelease];
	
	AFNetworkServiceSignature serviceSignature = {
		.service = netService,
	};
	
	return (id)[self initWithTransportSignature:&serviceSignature];
}

- (NSURL *)peer {
	CFTypeRef peer = [(id)self.lowerLayer peer];
	
	if (CFGetTypeID(peer) == CFHostGetTypeID()) {
		CFHostRef host = (CFHostRef)peer;
		
		NSArray *hostnames = (NSArray *)CFHostGetNames(host, NULL);
		if ([hostnames count] != 0) {
			return [NSURL URLWithString:[hostnames objectAtIndex:0]];
		}
		
		NSArray *addresses = (NSArray *)CFHostGetAddressing(host, NULL);
		if ([addresses count] != 0) {
			NSData *address = [addresses objectAtIndex:0];
			NSString *addressString = AFNetworkSocketAddressToPresentation(address, NULL);
			
			if (addressString != nil) {
				return [NSURL URLWithString:addressString];
			}
		}
		
		return nil;
	}
	else if (CFGetTypeID(peer) == CFNetServiceGetTypeID()) {
		CFNetServiceRef service = (CFNetServiceRef)peer;
		
		// Note: this is assuming that the service has already been resolved
		CFStringRef host = CFNetServiceGetTargetHost(service);
		SInt32 port = CFNetServiceGetPortNumber(service);
		
		return [NSURL URLWithString:[NSString stringWithFormat:@"%@:%lu", host, (unsigned long)port]];
	}
	
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, unsupported peer type %@", __PRETTY_FUNCTION__, peer] userInfo:nil];
	return nil;
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)packet context:(void *)context {
	if ([self.delegate respondsToSelector:@selector(networkLayer:didWrite:context:)]) {
		[self.delegate networkLayer:self didWrite:packet context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)packet context:(void *)context {
	if ([self.delegate respondsToSelector:@selector(networkLayer:didRead:context:)]) {
		[self.delegate networkLayer:self didRead:packet context:context];
	}
}

@end
