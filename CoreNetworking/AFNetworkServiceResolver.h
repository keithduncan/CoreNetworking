//
//  AFNetworkServiceResolver.h
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkSchedulerProxy.h"

#import "CoreNetworking/AFNetworkService-Constants.h"
#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceResolver;
@class AFNetworkServiceSource;

@protocol AFNetworkServiceResolverDelegate <NSObject>

 @required

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didReceiveError:(NSError *)error;

 @optional

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didUpdateRecord:(AFNetworkServiceRecordType)recordType withData:(NSData *)recordData;

- (void)networkServiceResolver:(AFNetworkServiceResolver *)networkServiceResolver didResolveAddress:(NSData *)address;

@end

/*!
	\brief
	Can resolve address records and monitor ephemeral record types such as TXT or NULL records.
 */
@interface AFNetworkServiceResolver : NSObject <AFNetworkSchedulable> {
 @private
	AFNetworkServiceScope *_serviceScope;
	
	struct {
		AFNETWORK_STRONG __attribute__((NSObject)) CFTypeRef _runLoopSource;
		void *_dispatchSource;
	} _sources;
	
	id <AFNetworkServiceResolverDelegate> _delegate;
	
	NSMapTable *_recordToQueryServiceMap;
	
	struct {
		AFNETWORK_STRONG __attribute__((NSObject)) CFTypeRef _runLoopTimer;
		void *_dispatchTimer;
	} _timers;
	void *_resolveService;
	void *_getInfoService;
	
	NSMapTable *_serviceToServiceSourceMap;
	
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
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue;

#endif

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
- (void)addMonitorForRecord:(AFNetworkServiceRecordType)record;
/*!
	\brief
	Remove a previously added monitor
 */
- (void)removeMonitorForRecord:(AFNetworkServiceRecordType)record;
/*!
	\brief
	Snapshot of the most recent record update, does not perform any I/O
 */
- (NSData *)dataForRecord:(AFNetworkServiceRecordType)record;

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
