//
//  AFNetService.m
//  Amber
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 software. All rights reserved.
//

#import "AFNetService.h"

#import <dns_sd.h>

#if TARGET_OS_MAC && TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#import "AFNetworkConstants.h"

NSDictionary *AFNetServicePropertyDictionaryFromTXTRecordData(NSData *TXTRecordData) {
	NSMutableDictionary *TXTDictionary = [[[NSNetService dictionaryFromTXTRecordData:TXTRecordData] mutableCopy] autorelease];
	
	for (NSString *currentKey in [TXTDictionary allKeys]) {
		NSData *currentValue = [TXTDictionary objectForKey:currentKey];
		[TXTDictionary setObject:[[[NSString alloc] initWithData:currentValue encoding:NSUTF8StringEncoding] autorelease] forKey:currentKey];
	}
	
	return TXTDictionary;
}

NSData *AFNetServiceTXTRecordDataFromPropertyDictionary(NSDictionary *TXTRecordDictionary) {
	NSMutableDictionary *dataDictionary = [NSMutableDictionary dictionaryWithCapacity:[TXTRecordDictionary count]];
	
	for (NSString *currentKey in [TXTRecordDictionary allKeys]) {
		id currentValue = [TXTRecordDictionary objectForKey:currentKey];
		currentValue = [currentValue dataUsingEncoding:NSUTF8StringEncoding];
		
		[dataDictionary setObject:currentValue forKey:currentKey];
	}
	
	return [NSNetService dataFromTXTRecordDictionary:dataDictionary];
}

@interface AFNetService ()
@property (readwrite, retain) NSDictionary *presence;
@end

@implementation AFNetService

@synthesize delegate;
@synthesize presence;

- (id)initWithNetService:(id <AFNetServiceCommon>)service {
	return [self initWithDomain:[(id)service valueForKey:@"domain"] type:[(id)service valueForKey:@"type"] name:[(id)service valueForKey:@"name"]];
}

static void AFNetServiceMonitorClientCallBack(CFNetServiceMonitorRef monitor, CFNetServiceRef service, CFNetServiceMonitorType typeInfo, CFDataRef rdata, CFStreamError *error, AFNetService *self) {
	NSDictionary *values = AFNetServicePropertyDictionaryFromTXTRecordData((NSData *)rdata);
	[self updatePresenceWithValuesForKeys:values];
}

static void AFNetServiceClientCallBack(CFNetServiceRef service, CFStreamError *error, AFNetService *self) {
	NSArray *resolvedAddresses = [self addresses];
	
	if (resolvedAddresses == nil) {
		if ([self->delegate respondsToSelector:@selector(netService:didNotResolveAddress:)]) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  NSLocalizedString(@"Couldn't resolve the remote client's address.", @"AFNetService resolve failure"), NSLocalizedDescriptionKey,
									  nil];
			
			NSError *error = [[[NSError alloc] initWithDomain:AFCoreNetworkingBundleIdentifier code:0 userInfo:userInfo] autorelease];
			
			[self->delegate netService:self didNotResolveAddress:error];
		}
		
		return;
	}
	
	if ([self->delegate respondsToSelector:@selector(netServiceDidResolveAddress:)])
		[self->delegate netServiceDidResolveAddress:self];
}

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceClientContext context = {0};
	context.info = self;
	
	_service =  (CFNetServiceRef)CFMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)domain, (CFStringRef)type, (CFStringRef)name, 0));
	Boolean client = CFNetServiceSetClient(_service, (CFNetServiceClientCallBack)AFNetServiceClientCallBack, &context);
	
	if (!client) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, couldn't set service client", __PRETTY_FUNCTION__, nil];
		
		[self release];
		return nil;
	}
	
	_monitor = (CFNetServiceMonitorRef)CFMakeCollectable(CFNetServiceMonitorCreate(kCFAllocatorDefault, _service, (CFNetServiceMonitorClientCallBack)AFNetServiceMonitorClientCallBack, &context));
	
	return self;
}

- (void)dealloc {
	[self stop];
	
	CFNetServiceMonitorInvalidate(_monitor);
	CFRelease(_monitor);
	
	CFRelease(_service);
	
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
	return (id)CFNetServiceGetDomain(_service);
}

- (NSString *)type {
	return (id)CFNetServiceGetType(_service);
}

- (NSString *)name {
	return (id)CFNetServiceGetName(_service);
}

- (void)startMonitoring {
	CFNetServiceMonitorScheduleWithRunLoop(_monitor, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	CFNetServiceMonitorStart(_monitor, kCFNetServiceMonitorTXT, NULL);
}

- (void)stopMonitoring {
	CFNetServiceMonitorStop(_monitor, NULL);
	CFNetServiceMonitorUnscheduleFromRunLoop(_monitor, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence {	
	self.presence = newPresence;
}

- (void)resolveWithTimeout:(NSTimeInterval)delta {
	CFNetServiceScheduleWithRunLoop(_service, CFRunLoopGetMain(), kCFRunLoopCommonModes);
	CFNetServiceResolveWithTimeout(_service, delta, NULL);
}

- (void)stopResolve {
	CFNetServiceCancel(_service);
	CFNetServiceUnscheduleFromRunLoop(_service, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

- (void)stop {
	[self stopMonitoring];
	[self stopResolve];	
}

- (NSArray *)addresses {
	return (id)CFNetServiceGetAddressing(_service);
}

- (NSString *)fullName {
	NSMutableString *fullName = [NSMutableString string];
	
	[fullName appendString:[self name]];
	if (![fullName hasSuffix:@"."]) [fullName appendString:@"."];
	
	[fullName appendString:[self type]];
	if (![fullName hasSuffix:@"."]) [fullName appendString:@"."];
	
	[fullName appendString:[self domain]];
	if (![fullName hasSuffix:@"."]) [fullName appendString:@"."];
	
	return fullName;
}

@end

@implementation NSNetService (_AFAdditions)

- (id)initWithNetService:(id <AFNetServiceCommon>)service {
	return (id)(*[AFNetService instanceMethodForSelector:_cmd])(self, _cmd, service);
}

- (NSString *)fullName {
	return (id)(*[AFNetService instanceMethodForSelector:_cmd])(self, _cmd);
}

@end
