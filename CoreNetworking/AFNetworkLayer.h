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
	@class
	@abstract	This is the parent class for all the network stack objects. You are unlikely to use it directly.
	@discussion	CFHostRef and CFNetServiceRef are both first class citizens in CoreNetworking, and you can easily bring a stack online using either.
				There are two designated outbound initialisers, each accepting one of the destination types.
 */
@interface AFNetworkLayer : NSObject {
 @private
	id <AFTransportLayer> _lowerLayer;
	id _delegate;
	
	NSMutableDictionary *_transportInfo;
}

/*
 *	Inbound Initialisers
 *		These are used when you have an accept socket that has spawned a new connection
 */

/*!
	@method
 */
- (id)initWithLowerLayer:(id <AFTransportLayer>)layer;

/*
 * Outbound Initialisers
 *	Perhaps the connection initialiser should be a class method a facade to a class cluster and return SOCK_STREAM/SOCK_DGRAM etc internal subclasses?
 *	These connections will need to be sent -open before they can be used, just like a stream
 */

/*!
	@method
	@abstract	You must override this method if you want to use the designated outbound initialisers.
				The default implementation raises an exception.
 */
+ (Class)lowerLayerClass;

/*!
	@method
	@abstract	This initialiser is a sibling to <tt>-initWithNetService:</tt>.
				This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef address values
				The default implementation creates a lower-layer using <tt>+lowerLayerClass</tt> and calls the same initialiser on the new object.
 */
- (id <AFTransportLayer>)initWithSignature:(const AFNetworkTransportPeerSignature *)signature;

/*!
	@method
	@abstract	This initialiser is a sibling to <tt>-initWithSignature:</tt>.
	@discussion	A net service - once resolved - encapsulates all the data from <tt>AFSocketPeerSignature</tt>
				The default implementation creates a lower-layer using <tt>+lowerLayerClass</tt> and calls the same initialiser on the new object.
	@param		|netService| will be used to create a CFNetService internally
 */
- (id <AFTransportLayer>)initWithNetService:(id <AFNetServiceCommon>)netService;

/*!
	@property
 */
@property (readonly) id <AFTransportLayer> lowerLayer;

/*!
	@method
	@abstract	When accessing this property, you will not recieve the object passed in, this method returns a proxy that allows a user to forward messages up the delegate stack.
 */
@property (assign) id delegate;

/*!
	@property
	@abstract	This isn't used by the framework, it is intended for use like <tt>-[NSThread threadDictionary]</tt> to store miscellaneous data.
 */
@property (readonly, retain) NSMutableDictionary *transportInfo;

@end
