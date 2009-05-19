//
//  AFNetworkObject.h
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetService.h"
#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFTransportLayer.h"

/*!
	@brief
	This is the parent class for all the network stack objects. You are unlikely to use it directly.
	
	@detail
	This class configures a bidirectional proxying system. Unimplemented methods are forwarded to the |lowerLayer|, and the delegate accessor returns a proxy that forwards messages up the delegate chain.
	CFHostRef and CFNetServiceRef are both first class citizens in CoreNetworking, and you can easily bring a stack online using either.
	There are two designated outbound initialisers, each accepting one of the destination types.
 */
@interface AFNetworkLayer : NSObject {
 @private
	id <AFTransportLayer> _lowerLayer;
	id _delegate;
	
	NSMutableDictionary *_transportInfo;
}

/*!
	@brief
	The default implementation of this method raises an exception, if you don't handle scheme passed in you should defer to the superclass' implementation.
 
	@detail
	This is used by <tt>-initWithURL:</tt> to determine the socket type and port to use.
 */
+ (const AFNetworkTransportSignature *)transportSignatureForScheme:(NSString *)scheme;

/*!
	@brief
	Inbound Initialiser
	This is used when you have an accept socket that has spawned a new connection.
 */
- (id)initWithLowerLayer:(id <AFTransportLayer>)layer;

/*!
	@brief
	Outbound Initialiser.
	This initialiser is essentially a psudeonym for <tt>-initWithSignature:</tt> but using a well known scheme which implies a port number.
 
	@detail
	If the URL provides a port number that one is used instead of the scheme-implied port.
 */
- (id <AFTransportLayer>)initWithURL:(NSURL *)endpoint;

/*!
	@brief
	Outbound Initialiser.
	This initialiser is a sibling to <tt>-initWithNetService:</tt>.
 
	@detail
	This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef address values.
	The default implementation creates a lower-layer using <tt>+lowerLayerClass</tt> and calls the same initialiser on the new object.
 */
- (id <AFTransportLayer>)initWithPeerSignature:(const AFNetworkTransportPeerSignature *)signature;

/*!
	@brief
	Outbound Initialiser.
	This initialiser is a sibling to <tt>-initWithSignature:</tt>.
 
	@detail
	A net service - once resolved - encapsulates all the data from <tt>AFSocketPeerSignature</tt>.
	The default implementation creates a lower-layer using <tt>+lowerLayerClass</tt> and calls the same initialiser on the new object.
 
	@param	|netService| will be used to create a CFNetService internally.
 */
- (id <AFTransportLayer>)initWithNetService:(id <AFNetServiceCommon>)netService;

/*!
	@brief
	Data should be passed onto the lowerLayer for further processing.
 */
- (AFNetworkLayer *)lowerLayer;

/*!
	@brief
	When accessing this property, you will not recieve the same object you passed in, this method returns a transparent proxy that allows a caller to forward messages up the delegate stack.
 */
@property (assign) id delegate;

/*!
	@brief
	This isn't currently used by the framework, it is intended for use like <tt>-[NSThread threadDictionary]</tt> to store miscellaneous data.
 */
@property (readonly, retain) NSMutableDictionary *transportInfo;

@end
