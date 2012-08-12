//
//  AFPacket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Posted when the packet completed (successfully or otherwise).
	
	\details
	If the packet is completing because an error was encountered, return it under the <tt>AFPacketErrorKey</tt> key.
 */
AFNETWORK_EXTERN NSString *const AFNetworkPacketDidCompleteNotificationName;

	AFNETWORK_EXTERN NSString *const AFNetworkPacketErrorKey;

/*!
	\brief
	This is an abstract packet superclass. It provides simple functionality such as tagging and timeouts.
 */
@interface AFNetworkPacket : NSObject {
 @package
	void *_context;
	
	NSTimeInterval _idleTimeout;
	NSInteger _idleTimeoutDisableCount;
	NSTimer *_idleTimeoutTimer;
	
	NSMutableDictionary *_userInfo;
}

/*!
	\brief
	The context passed in at instantiation.
 */
@property (readonly, nonatomic) void *context;

/*!
	\brief
	The duration passed in at instantiation.
 */
@property (readonly, nonatomic) NSTimeInterval idleTimeout;

/*!
	\brief
	For storing additional properties, typically a higher layer context pointer.
 */
@property (readonly, nonatomic) NSMutableDictionary *userInfo;

/*!
	\brief
	Timeouts are enabled by default, disabling the timeout prevents the idle timer from starting.
 */
- (void)disableIdleTimeout;
/*!
	\brief
	Balances a previous `disbleTimeout` message, when the disabled count reaches zero, an idle timer is started.
	Must not be called more than `disableIdleTimeout`, an exception is thrown if the disable count becomes negative.
 */
- (void)enableIdleTimeout;

/*!
	\brief
	This is a dynamic property for subclasses to implement.
 */
@property (readonly, nonatomic) id buffer;

/*!
	\brief
	This is an override point
	\return
	Values in the range [0.0, 1.0], this method returns 0.0 by default
 */
- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal;

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
	
	\details
	If a value of `<0` is returned, an error must also have been posted via the `AFNetworkPacketDidCompleteNotificationName` notification.
	
	\return
	The number of bytes written, if greater than zero this is returned as part of the packet progress notification.
 */
- (NSInteger)performWrite:(NSOutputStream *)writeStream;

@end
