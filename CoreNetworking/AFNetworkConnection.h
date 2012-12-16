//
//  AFNetworkConnection.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

@class AFNetworkServiceScope;

@protocol AFNetworkConnectionControlDelegate <AFNetworkConnectionLayerControlDelegate>

@end

@protocol AFNetworkConnectionDataDelegate <AFNetworkConnectionLayerDataDelegate>

@end

/*!
	\brief
	Wrapper protocol.
 */
@protocol AFNetworkConnectionDelegate <AFNetworkConnectionLayerDelegate, AFNetworkConnectionControlDelegate, AFNetworkConnectionDataDelegate>

@end

/*!
	\brief
	Your subclass should encapsulate Application Layer data (as defined in IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122> and pass it to the superclass for further processing.
*/
@interface AFNetworkConnection : AFNetworkLayer <AFNetworkConnectionLayer, AFNetworkTransportLayerDataDelegate>

/*!
	\brief
	The default implementation of this method raises an exception, if you don't handle scheme passed in you should defer to the superclass' implementation.
	
	\details
	This is used by `-initWithURL:` to determine the socket type and port to use.
 */
+ (AFNetworkInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme;

/*!
	\brief
	Akin to `-transportSignatureForScheme:`, this method tells a client how to advertise an application layer
	
	\details
	The default implementation throws an exception.
	
	\return
	You only need to return the application type, excluding the transport type where @"_<application protocol>._<transport protocol>".
 */
+ (NSString *)serviceDiscoveryType;

/*!
	\brief
	Outbound Initialiser.
	This initialiser is essentially a psudeonym for `-initWithSignature:` but using either scheme-implied port number, or one provided in the URL.
	If you use this method, you are required to override `+transportSignatureForScheme:` to provide the `AFNetworkSocketSignature` even if a port number is provided in the URL.
	
	\details
	If the URL provides a port number that one is used instead of the scheme-implied port. Scheme implied ports are looked up in /etc/services.
 */
- (id <AFNetworkConnectionLayer>)initWithURL:(NSURL *)URL;

/*!
	\brief
	Outbound Initialiser.
	This initialiser is shorthand for creating a AFNetworkTransportServiceSignature.
 */
- (id <AFNetworkConnectionLayer>)initWithService:(AFNetworkServiceScope *)serviceScope;

- (AFNetworkLayer <AFNetworkConnectionLayer> *)lowerLayer;

@property (assign, nonatomic) id <AFNetworkConnectionDelegate> delegate;

/*!
	\brief
	This method returns nil for an inbound connection.
	Otherwise, this method returns the CFHostRef hostname, or the CFNetServiceRef fullname.
 */
@property (readonly, nonatomic) NSURL *peer;

@end
