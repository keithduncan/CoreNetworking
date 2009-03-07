//
//  AFNetService.m
//  Bonjour
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "AFNetService.h"

#import <dns_sd.h>

#if TARGET_OS_MAC && TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

NSDictionary *AFNetServiceProcessTXTRecordData(NSData *TXTRecordData) {
	NSMutableDictionary *TXTDictionary = [[[NSNetService dictionaryFromTXTRecordData:TXTRecordData] mutableCopy] autorelease];
	
	for (NSString *currentKey in [TXTDictionary allKeys]) {
		NSData *currentValue = [TXTDictionary objectForKey:currentKey];
		[TXTDictionary setObject:[[[NSString alloc] initWithData:currentValue encoding:NSUTF8StringEncoding] autorelease] forKey:currentKey];
	}
	
	return TXTDictionary;
}

@interface AFNetService ()
@property (readwrite, retain) NSDictionary *presence;
@end

@implementation AFNetService

@synthesize delegate;
@synthesize presence;

+ (id)serviceWithNetService:(NSNetService *)service {
	return [[[AFNetService alloc] initWithDomain:[service valueForKey:@"domain"] type:[service valueForKey:@"type"] name:[service valueForKey:@"name"]] autorelease];
}

- (id)init {
	[super init];
		
	presence = [[NSMutableDictionary alloc] init];
	
	return self;
}

static void AFNetServiceMonitorClientCallBack(CFNetServiceMonitorRef monitor, CFNetServiceRef service, CFNetServiceMonitorType typeInfo, CFDataRef rdata, CFStreamError *error, void *info) {
	AFNetService *self = info;
	
	NSDictionary *values = AFNetServiceProcessTXTRecordData((NSData *)rdata);
	
	[self updatePresenceWithValuesForKeys:values];
}

static void AFNetServiceClientCallBack(CFNetServiceRef service, CFStreamError *error, void *info) {
	AFNetService *self = info;
	
	CFArrayRef resolvedAddresses = CFNetServiceGetAddressing(service);
	
	if (resolvedAddresses == NULL) {
		if ([self->delegate respondsToSelector:@selector(netService:didNotResolveAddress:)]) {
			[self->delegate netService:self didNotResolveAddress:NSLocalizedString(@"Couldn't resolve the remote player's address.", @"AFNetService ")];
		}
		
		return;
	}
	
	if ([self->delegate respondsToSelector:@selector(netServiceDidResolveAddress:)]) {
		[self->delegate netServiceDidResolveAddress:self];
	}
}

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name {
	[self init];
	
	context.info = self;
	
	service =  CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)domain, (CFStringRef)type, (CFStringRef)name, 0);
	monitor = CFNetServiceMonitorCreate(kCFAllocatorDefault, service, AFNetServiceMonitorClientCallBack, &context);
	
	return self;
}

- (void)dealloc {
	[self stop];
		
	[presence release];
	
	[super dealloc];
}

- (BOOL)isEqual:(id)object {
	NSArray *equalKeys = [NSArray arrayWithObjects:@"name", @"type", @"domain", nil];
	return [[self dictionaryWithValuesForKeys:equalKeys] isEqual:[object dictionaryWithValuesForKeys:equalKeys]];
}

- (NSUInteger)hash {
	return [[self name] hash];
}

- (NSString *)domain {
	return (id)CFNetServiceGetDomain(service);
}

- (NSString *)type {
	return (id)CFNetServiceGetType(service);
}

- (NSString *)name {
	return (id)CFNetServiceGetName(service);
}

- (void)startMonitoring {
	CFNetServiceMonitorScheduleWithRunLoop(monitor, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	CFNetServiceMonitorStart(monitor, kCFNetServiceMonitorTXT, NULL);
}

- (void)stopMonitoring {
	CFNetServiceMonitorStop(monitor, NULL);
	CFNetServiceMonitorUnscheduleFromRunLoop(monitor, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence {
	[presence setDictionary:newPresence];
}

- (void)resolveWithTimeout:(NSTimeInterval)delta {
	Boolean client = CFNetServiceSetClient(service, AFNetServiceClientCallBack, &context);
	
	if (!client) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, couldn't set service client", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	CFNetServiceScheduleWithRunLoop(service, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	CFNetServiceResolveWithTimeout(service, delta, NULL);
}

- (void)stopResolve {
	CFNetServiceUnscheduleFromRunLoop(service, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	CFNetServiceSetClient(service, NULL, NULL);
	
	CFNetServiceCancel(service);
}

- (void)stop {
	[self stopMonitoring];
	[self stopResolve];	
}

- (NSArray *)addresses {	
	return CFNetServiceGetAddressing(service);
}

- (NSString *)fullName {
	char *fullNameStr = (char *)malloc(kDNSServiceMaxDomainName); // Note: this size includes the NULL byte at the end
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceConstructFullName(fullNameStr, [[self name] UTF8String], [[self type] UTF8String], [[self domain] UTF8String]);
	
	if (error != kDNSServiceErr_NoError) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, could not form a full DNS name.", __PRETTY_FUNCTION__, NSStringFromClass([self class]), _cmd, nil];
		return nil;
	}
	
	NSString *fullName = [NSString stringWithUTF8String:fullNameStr];
	
	fullName = [fullName stringByReplacingOccurrencesOfString:@"\032" withString:@" "];
#warning this is a mild hack
	
	free(fullNameStr);
	
	return fullName;
}

@end
