//
//  AFPacket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFPacketDelegate;

/*!

 */
enum {
	AFPacketNoError			= 0,
	AFPacketMaxedOutError	= 1,
};
typedef NSInteger AFPacketError;

/*!
	@brief
	This is posted when a timeout occurs, the object is the packet
 */
extern NSString *const AFPacketTimeoutNotificationName;

/*!
	@brief
	This is an abstract packet superclass. It provides simple functionality such as tagging and timeouts.
 */
@interface AFPacket : NSObject {
 @package
	NSUInteger _tag;
	NSTimeInterval _duration;
 @private
	NSTimer *timeoutTimer;
}

@property (readonly) NSUInteger tag;

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration;

/*!
	@brief
	This is a dynamic property for subclasses to implement.
	This property is returned to the delegate in the -...didRead: and -...didWrite: callbacks.
 */
@property (readonly) id buffer;

/*!
	@brief
	This is an override point
	@result
	Values in the range [0.0, 1.0], this method returns 0.0 by default
 
	@param
	|fraction| is required, calling with a NULL argument will raise an exception
 */
- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal;

/*!
	@brief
	This method will start an NSTimer (it will be scheduled in the current run loop) if the duration the packet was created with is >0.
 */
- (void)startTimeout;

/*!
	@brief
	This method simply balances <tt>-startTimeout</tt>
 */
- (void)cancelTimeout;

@end

/*!
	@brief
	Any read packet you enqueue must conform to this protocol.
 */
@protocol AFPacketReading <NSObject>

/*!
	@brief
	This method is called to perform the read once the stream has signalled that it has bytes available.
 
	@result
	Return TRUE to indicate that the packet is complete. Once your packet is complete the <tt>buffer</tt> property should contain the read results.
 */
- (BOOL)performRead:(CFReadStreamRef)stream error:(NSError **)errorRef;

@end

/*!
	@brief
	Any write packet you enqueue must conform to this protocol.
 */
@protocol AFPacketWriting <NSObject>

/*!
	@brief
	This method is called to perform the write once the stream has signalled it has space available.
 
	@result
	Return TRUE to indicate that the packet is complete. Once your packet is complete the <tt>buffer</tt> property should contain the written data.
 */
- (BOOL)performWrite:(CFWriteStreamRef)writeStream error:(NSError **)errorRef;

@end
