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

 */
@interface AFPacket : NSObject {
 @private
	NSUInteger _tag;
	
	NSTimer *timeoutTimer;
	NSTimeInterval _duration;
}

@property (readonly) NSUInteger tag;

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration;

/*!
	@brief
	This is a dynamic property for subclasses to implement.
	This property is returned to the delegate in the -...didRead: and -...didWrite: callbacks.
 */
@property (readonly) NSData *buffer;

/*!
	@brief
	This is an override point
	@result
	Values in the range [0.0, 1.0], this method returns 0.0 by default
 
	@param
	|fraction| is required, calling with a NULL argument will raise an exception
 */
- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal;

- (void)startTimeout;
- (void)cancelTimeout;

@end
