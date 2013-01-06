//
//  AFNetworkServiceResolver.h
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkService-Constants.h"

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceResolver;
@class AFNetworkServiceSource;
@class AFNetworkSchedule;

@protocol AFNetworkServiceResolverDelegate <NSObject>

 @required

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didReceiveError:(NSError *)error;

 @optional

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didUpdateRecord:(AFNetworkDomainRecordType)recordType withData:(NSData *)recordData;

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didResolveAddress:(NSData *)address;

@end

/*!
	\brief
	Can resolve address records and monitor ephemeral record types such as TXT or NULL records.
 */
@interface AFNetworkServiceResolver : NSObject {
 @private
	AFNetworkServiceScope *_serviceScope;
	
	id <AFNetworkServiceResolverDelegate> _delegate;
	
	NSMapTable *_recordToQueryServiceMap;
	void *_resolveService;
	void *_getInfoService;
	
	AFNetworkSchedule *_schedule;
	NSMapTable *_serviceToServiceSourceMap;
	struct {
		AFNETWORK_STRONG CFTypeRef _runLoopTimer;
		void *_dispatchTimer;
	} _timers;
	
	NSMapTable *_recordToDataMap;
	NSMutableArray *_addresses;
}

/*
	\brief
	Designated initialiser.
	
	\param serviceScope
	Must be a fully qualified scope, with no wildcard or blank values for domain, type or name.
 */
- (id)initWithServiceScope:(AFNetworkServiceScope *)serviceScope;

/*
	Scheduling
 */

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*
 
 */

/*!
	\brief
	Updates are delivered in the scheduled environment.
 */
@property (assign, nonatomic) id <AFNetworkServiceResolverDelegate> delegate;

/*!
	\brief
	Start watching a record type, may start a long-lived query (LLQ)
 */
- (void)addMonitorForRecord:(AFNetworkDomainRecordType)record;
/*!
	\brief
	Remove a previously added monitor
 */
- (void)removeMonitorForRecord:(AFNetworkDomainRecordType)record;
/*!
	\brief
	Snapshot of the most recent record update, does not perform any I/O
 */
- (NSData *)dataForRecord:(AFNetworkDomainRecordType)record;

/*!
	\brief
	Applications are unlikely to need to resolve to raw addresses.
	Instead, applications should create a CFStream with a CFNetService, CFStream will resolve and try the best addresses in a system defined order.
	Only use this method if you absolutely need to lookup the remote socket addresses youself.
 */
- (void)resolveWithTimeout:(NSTimeInterval)timeout;
/*!
	\brief
	Accumulated discovered addresses, will return nil until the first address is resolved.
 */
@property (readonly, retain, nonatomic) NSArray *addresses;

/*!
	\brief
	The delegate will not receive any further messages, all queries are cancelled
 */
- (void)invalidate;

@end
