//
//  AFPacket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\brief
	Posted when a timeout occurs, the object is the packet
 */
extern NSString *const AFNetworkPacketDidTimeoutNotificationName;

/*!
	\brief
	Posted when the packet completed (successfully or otherwise).
	
	\details
	If the packet is completing because an error was encountered, return it under the <tt>AFPacketErrorKey</tt> key.
 */
extern NSString *const AFNetworkPacketDidCompleteNotificationName;

	extern NSString *const AFNetworkPacketErrorKey;

/*!
	\brief
	This is an abstract packet superclass. It provides simple functionality such as tagging and timeouts.
 */
@interface AFNetworkPacket : NSObject {
 @package
	void *_context;
	NSTimeInterval _duration;
 @private
	NSTimer *timeoutTimer;
}

/*!
	\brief
	The context passed in at instantiation.
 */
@property (readonly) void *context;

/*!
	\brief
	The duration passed in at instantiation.
 */
@property (readonly) NSTimeInterval duration;

/*!
	\brief
	This method will start an NSTimer (it will be scheduled in the current run loop) if the duration the packet was created with is >0.
 */
- (void)startTimeout;

/*!
	\brief
	This method balances <tt>-startTimeout</tt>
 */
- (void)stopTimeout;

/*!
	\brief
	This is a dynamic property for subclasses to implement.
	This property is returned to an <tt>AFNetworkLayer</tt> delegate in the -...didRead: and -...didWrite: callbacks.
 */
@property (readonly) id buffer;

/*!
	\brief
	This is an override point
	\return
	Values in the range [0.0, 1.0], this method returns 0.0 by default
 */
- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal;

@end

/*!
	\brief
	Any read packet you enqueue must conform to this protocol.
 */
@protocol AFNetworkPacketReading <NSObject>

/*!
	\brief
	Called to perform the read once the stream has signalled that it has bytes available.
	
	\return
	The number of bytes read, if greater than zero this is returned as part of the packet progress notification.
 */
- (NSInteger)performRead:(NSInputStream *)readStream;

@end

/*!
	\brief
	Any write packet you enqueue must conform to this protocol.
 */
@protocol AFNetworkPacketWriting <NSObject>

/*!
	\brief
	Called to perform the write once the stream has signalled that it can accept bytes.
 
	\return
	The number of bytes written, if greater than zero this is returned as part of the packet progress notification.
 */
- (NSInteger)performWrite:(NSOutputStream *)writeStream;

@end
