//
//  AFNetworkConnection.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFConnectionLayer.h"

/*!
	@brief	Your subclass should encapsulate Application Layer data (as defined in RFC 1122) and pass it to the superclass for further processing.
*/
@interface AFNetworkConnection : AFNetworkLayer <AFConnectionLayer>

/*!
	@brief
	The default implementation of this method raises an exception, if you don't handle scheme passed in you should defer to the superclass' implementation.
 
	@detail
	This is used by <tt>-initWithURL:</tt> to determine the socket type and port to use.
 */
+ (AFInternetTransportSignature *)transportSignatureForScheme:(NSString *)scheme;

/*!
	@brief
	Akin to <tt>-transportSignatureForScheme:</tt>, this method tells a client how to advertise an application layer
 
	@detail
	The default implementation throws an exception.
 
	@result
	Make sure you return the whole type, including the transport layer, @"<application type>.<transport type>"
 */
+ (NSString *)serviceDiscoveryType;

/*!
	@brief
	Outbound Initialiser.
	This initialiser is essentially a psudeonym for <tt>-initWithSignature:</tt> but using either scheme-implied port number, or one provided in the URL.
	If you use this method, you are required to override <tt>+transportSignatureForScheme:</tt> to provide the <tt>AFNetworkSocketSignature</tt> even if a port number is provided in the URL.
 
	@detail
	If the URL provides a port number that one is used instead of the scheme-implied port. Scheme implied ports are looked up in /etc/services.
 */
- (id <AFConnectionLayer>)initWithURL:(NSURL *)endpoint;

/*!
 
 */
- (AFNetworkLayer <AFConnectionLayer> *)lowerLayer;

/*!
 
 */
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

/*!
	@brief
	This method returns nil for an inbound connection.
	Otherwise, this method returns the CFHostRef hostname, or the CFNetServiceRef fullname.
 */
@property (readonly) NSURL *peer;

@end
