//
//  AFNetworkServiceBrowser.h
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceBrowser;
@class AFNetworkServiceSource;
@class AFNetworkSchedule;

/*!
	\brief
	Placeholder domain for AFNetworkServiceScope to browse for browsable
	domains.
 */
AFNETWORK_EXTERN NSString *const AFNetworkServiceBrowserDomainBrowsable;

/*!
	\brief
	Placeholder domain for AFNetworkServiceScope to browse for publishable
	domains.
 */
AFNETWORK_EXTERN NSString *const AFNetworkServiceBrowserDomainPublishable;

@protocol AFNetworkServiceBrowserDelegate <NSObject>

 @required

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didReceiveError:(NSError *)error;

 @optional

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didDiscoverScope:(AFNetworkServiceScope *)scope;

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didRemoveScope:(AFNetworkServiceScope *)scope;

@end

/*!
	\brief
	Query DNS (including link-local multicast) for services matching a pattern.
 */
@interface AFNetworkServiceBrowser : NSObject {
 @private
	AFNetworkServiceScope *_serviceScope;
	
	AFNetworkSchedule *_schedule;
	
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
	
	The first two and last two modes are the browse operations supported by
	`NSNetServiceBrowser`, the others are composite searches.
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
@property (assign, nonatomic) id <AFNetworkServiceBrowserDelegate> delegate;

/*!
	\brief
	Receiver must be scheduled before receiving this message.
 */
- (void)searchForScopes;

/*!
	\brief
	Cancel the search.
 */
- (void)invalidate;

@end
