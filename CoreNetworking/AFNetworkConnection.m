//
//  AFNetworkConnection.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkConnection.h"

#import "AFNetworkTransport.h"
#import "AFNetworkFunctions.h"

@implementation AFNetworkConnection

@dynamic delegate;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (AFNetworkInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
	[NSException raise:NSInvalidArgumentException format:@"%s, cannot provide an AFNetworkInternetTransportSignature for scheme (%@)", __PRETTY_FUNCTION__, scheme];
	
	AFNetworkInternetTransportSignature signature = {0};
	return signature;
}

+ (NSString *)serviceDiscoveryType {
	[NSException raise:NSInternalInconsistencyException format:@"%s, connot provide a service discovery type", __PRETTY_FUNCTION__];
	return nil;
}

- (id <AFNetworkConnectionLayer>)initWithURL:(NSURL *)endpoint {
	CFHostRef host = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)[endpoint host])) autorelease];
	
	AFNetworkInternetTransportSignature transportSignature = [[self class] transportSignatureForScheme:[endpoint scheme]];
	
	if ([endpoint port] != nil) {
		transportSignature.port = [[endpoint port] integerValue];
	}
	
	AFNetworkHostSignature hostSignature = {
		.host = host,
		.transport = transportSignature,
	};
	
	return (id)[self initWithTransportSignature:&hostSignature];
}

- (id <AFNetworkConnectionLayer>)initWithService:(id <AFNetworkServiceCommon>)service {
	CFNetServiceRef netService = (CFNetServiceRef)[NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)[(id)service valueForKey:@"domain"], (CFStringRef)[(id)service valueForKey:@"type"], (CFStringRef)[(id)service valueForKey:@"name"], 0)) autorelease];
	
	AFNetworkServiceSignature serviceSignature = {
		.service = netService,
	};
	
	return (id)[self initWithTransportSignature:&serviceSignature];
}

- (AFNetworkLayer <AFNetworkConnectionLayer> *)lowerLayer {
	return [super lowerLayer];
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
			NSString *addressString = AFNetworkSocketAddressToPresentation(address);
			
			if (addressString != nil) {
				return [NSURL URLWithString:addressString];
			}
		}
		
		return nil;
	} else if (CFGetTypeID(peer) == CFNetServiceGetTypeID()) {
		CFNetServiceRef service = (CFNetServiceRef)peer;
		
		// Note: this is assuming that the service has already been resolved
		CFStringRef host = CFNetServiceGetTargetHost(service);
		SInt32 port = CFNetServiceGetPortNumber(service);
		
		return [NSURL URLWithString:[NSString stringWithFormat:@"%@:%lu", host, (unsigned long)port]];
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, unsupported peer type %@", __PRETTY_FUNCTION__, peer];
	return nil;
}

@end
