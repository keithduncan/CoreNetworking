//
//  AFNetworkServiceBrowser.h
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkSchedulerProxy.h"

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceBrowser;
@class AFNetworkServiceSource;

/*!
	\brief
	Placeholder domain for AFNetworkServiceScope to browse for browsable domains
 */
AFNETWORK_EXTERN NSString *const AFNetworkServiceBrowserDomainBrowsable;

/*!
	\brief
	Placeholder domain for AFNetworkServiceScope to browse for publishable domains
 */
AFNETWORK_EXTERN NSString *const AFNetworkServiceBrowserDomainPublishable;

/*!
	\brief
	
 */
@protocol AFNetworkServiceBrowserDelegate <NSObject>

 @required

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didReceiveError:(NSError *)error;

 @optional

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didDiscoverScope:(AFNetworkServiceScope *)scope;

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didRemoveScope:(AFNetworkServiceScope *)scope;

@end

/*!
	\brief
	
 */
@interface AFNetworkServiceBrowser : NSObject <AFNetworkSchedulable> {
 @private
	AFNetworkServiceScope *_serviceScope;
	
	struct {
		AFNETWORK_STRONG __attribute__((NSObject)) CFTypeRef _runLoopSource;
		void *_dispatchSource;
	} _sources;
	
	id <AFNetworkServiceBrowserDelegate> _delegate;
	
	void *_service;
	AFNetworkServiceSource *_serviceSource;
	
	NSMutableSet *_scopes;
	NSMapTable *_scopeToBrowserMap;
}

/*!
	\brief
	Designated initialiser.
	
	\details
	Supported scopes are noted by `(domain, type, name)`.
	When creating a scope, use `AFNetworkServiceScopeWildcard` for the values you wish to have filled in by the browser.
	
	(*b, "", "") - find all browsable domain scopes
	(*r, "", "") - find all publishable domain scopes
	
	(**, **, "") - find all type scopes in every domain
	(X , **, "") - find all type scopes in domain X
	
	(**, **, **) - find all name scopes with any type in every domain
	(X , **, **) - find all name scopes with any type in domain X
	
	(**, Y , **) - find all name scopes with type Y in every domain
	(X , Y , **) - find all name scopes with type Y in domain X
	
	The last two modes are the browse operations supported by `NSNetServiceBrowser`.
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
@property (assign, nonatomic) id <AFNetworkServiceBrowserDelegate> delegate;

/*!
	\brief
	Receiver must be scheduled before receiving this message.
 */
- (void)searchForScopes;

/*!
	\brief
	
 */
- (void)invalidate;

@end
