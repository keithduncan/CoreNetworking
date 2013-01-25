//
//  AFNetworkPortMapper.m
//  CoreNetworking
//
//  Created by Keith Duncan on 16/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkPortMapper.h"

#import <sys/socket.h>
#import <arpa/inet.h>
#import <netinet/in.h>

#import "AFNetworkSchedule.h"
#import "AFNetworkServiceSource.h"
#import "AFNetworkService-PrivateFunctions.h"

#import "AFNetwork-Functions.h"

@interface AFNetworkPortMapper ()
@property (assign, nonatomic) AFNetworkSocketSignature socketSignature;
@property (copy, nonatomic) NSData *localAddress;
@property (copy, nonatomic) NSData *suggestedExternalAddress;

@property (retain, nonatomic) AFNetworkSchedule *schedule;
@property (retain, nonatomic) AFNetworkServiceSource *source;

@property (assign, nonatomic) DNSServiceRef service;
@end

@implementation AFNetworkPortMapper

- (id)initWithSocketSignature:(AFNetworkSocketSignature const)socketSignature localAddress:(NSData *)localAddress suggestedExternalAddress:(NSData *)suggestedExternalAddress {
	NSParameterAssert(localAddress != nil);
	
	self = [self init];
	if (self == nil) return nil;
	
	_socketSignature = socketSignature;
	_localAddress = [localAddress copy];
	_suggestedExternalAddress = [suggestedExternalAddress copy];
	
	return self;
}

- (void)dealloc {
	[_localAddress release];
	[_suggestedExternalAddress release];
	
	[_schedule release];
	
	[_source invalidate];
	[_source release];
	
	if (_service != NULL) {
		DNSServiceRefDeallocate(_service);
	}
	
	[super dealloc];
}

- (BOOL)_isScheduled {
	return (self.schedule != nil);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

static BOOL _AFNetworkPortMapperCheckAndForwardError(AFNetworkPortMapper *self, DNSServiceErrorType errorCode) {
	return _AFNetworkServiceCheckAndForwardError(self, self.delegate, @selector(portMapper:didReceiveError:), errorCode);
}

static void _AFNetworkPortMapperNATPortMappingReply(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, uint32_t externalAddress, DNSServiceProtocol protocol, uint16_t internalPort, uint16_t externalPort, uint32_t ttl, void *context) {
	@autoreleasepool {
		AFNetworkPortMapper *self = context;
		
		if (!_AFNetworkPortMapperCheckAndForwardError(self, errorCode)) {
			return;
		}
		
		struct sockaddr_in address = {
			.sin_len = sizeof(address),
			.sin_family = AF_INET,
			.sin_port = externalPort,
			.sin_addr = {
				.s_addr = externalAddress,
			},
		};
		NSData *addressData = [NSData dataWithBytes:&address length:address.sin_len];
		
		[self.delegate portMapper:self didMapExternalAddress:addressData];
	}
}

- (void)start {
	NSParameterAssert(self.delegate != nil);
	
	struct SocketProtocolToServiceProtocol {
		int socketProtocol;
		DNSServiceProtocol serviceProtocol;
	} const socketToServiceMap[] = {
		{
			.socketProtocol = IPPROTO_TCP,
			.serviceProtocol = kDNSServiceProtocol_TCP,
		},
		{
			.socketProtocol = IPPROTO_UDP,
			.serviceProtocol = kDNSServiceProtocol_UDP,
		},
	};
	AFNetworkSocketSignature socketSignature = self.socketSignature;
	DNSServiceProtocol protocol = 0;
	for (size_t idx = 0; idx < sizeof(socketToServiceMap)/sizeof(*socketToServiceMap); idx++) {
		if (socketSignature.protocol != socketToServiceMap[idx].socketProtocol) {
			continue;
		}
		
		protocol = socketToServiceMap[idx].serviceProtocol;
		break;
	}
	NSParameterAssert(protocol != 0);
	
	struct sockaddr_storage localAddress = {};
	NSData *localAddressData = self.localAddress;
	NSParameterAssert([localAddressData length] <= sizeof(localAddress));
	[localAddressData getBytes:&localAddress length:[localAddressData length]];
	uint16_t localPort = af_sockaddr_in_read_port(&localAddress);
	
	uint16_t externalPort = 0;
	NSData *suggestedExternalAddressData = self.suggestedExternalAddress;
	if (suggestedExternalAddressData != nil) {
		struct sockaddr_storage suggestedExternalAddress = {};
		NSParameterAssert([suggestedExternalAddressData length] <= sizeof(suggestedExternalAddress));
		[suggestedExternalAddressData getBytes:&suggestedExternalAddress length:[suggestedExternalAddressData length]];
		externalPort = af_sockaddr_in_read_port(&suggestedExternalAddress);
	}
	
	DNSServiceRef newService = NULL;
	DNSServiceErrorType newServiceError = DNSServiceNATPortMappingCreate(&newService, (DNSServiceFlags)0, kDNSServiceInterfaceIndexAny, protocol, htons(localPort), htons(externalPort), 0, _AFNetworkPortMapperNATPortMappingReply, self);
	if (!_AFNetworkPortMapperCheckAndForwardError(self, newServiceError)) {
		return;
	}
	self.service = newService;
	
	AFNetworkServiceSource *newSource = _AFNetworkServiceSourceForSchedule(newService, self.schedule);
	self.source = newSource;
	[newSource resume];
}

- (void)invalidate {
	[self.source invalidate];
}

@end
