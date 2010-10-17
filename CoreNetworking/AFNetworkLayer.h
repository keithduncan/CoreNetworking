//
//  AFNetworkLayer.h
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkService.h"
#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFNetworkTransportLayer.h"

/*!
	\brief
	This is the parent class for all the network stack objects. You are unlikely to use it directly.
	
	\details
	This class configures a bidirectional proxying system. Unimplemented methods are forwarded to the |lowerLayer|, and the delegate accessor returns a proxy that forwards messages up the delegate chain.
	CFHostRef and CFNetServiceRef are both first class citizens in Core Networking, and you can easily bring a stack online using either. (You should also consider NSURL/CFURL as a stand in for CFHostRef.)
	
	Core Networking layers are NOT automatically scheduled in the current run loop on creation.
	Two means of scheduling are available; run loop based and dispatch_queue_t based. You must schedule the layer appropriately to receive callbacks.
	Scheduling a layer in both a run loop and a queue is unsupported, results are undefined.
 */
@interface AFNetworkLayer : NSObject {
 @private
	id <AFNetworkTransportLayer> _lowerLayer;
	id _delegate;
	
	NSMutableDictionary *_transportInfo;
}

/*!
	\brief
	This method chains the layer classes.
 */
+ (Class)lowerLayer;

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer;

/*!
	\brief
	Data should be passed onto the lowerLayer for further processing.
 */
- (AFNetworkLayer *)lowerLayer;

/*!
	\brief
	Outbound Initialiser.
 
	\details
	You can provide either a host + transport details, or <AFNetServiceCommon> compilant class.
	
	If you provide a host, the details are captured and the host copied.
	If you provide an <AFNetServiceCommon> it will be used to create a CFNetService internally.
	
	The default implementation creates a lower-layer using <tt>+lowerLayerClass</tt> and calls the same initialiser on the new object.
 */
- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkSignature)signature;

/*!
	\brief
	When accessing this property, you will not recieve the same object you passed in, this method returns a transparent proxy that allows a caller to forward messages up the delegate stack.
 */
@property (assign) id delegate;

/*!
	\brief
	This isn't used by the framework, it is intended for use like <tt>-[NSThread threadDictionary]</tt> to store miscellaneous data.
	
	\details
	The network layers are KVC containers, much like a CALayer. Values for undefined keys are stored in this property.
	
	The dictionary returned is the result of reducing the |transportInfo| onto the |lowerLayer.transportInfo|. This takes place recursively.
 */
@property (readonly, retain) NSDictionary *transportInfo;

@end
