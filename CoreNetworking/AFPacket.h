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
	@enum
 */
enum {
	AFPacketNoError			= 0,
	AFPacketMaxedOutError	= 1,
};
typedef NSInteger AFPacketError;

/*!
	@constant
	@abstract	This is posted when a timeout occurs, the object is the packet
 */
extern NSString *const AFPacketTimeoutNotificationName;

/*!
	@class
 */
@interface AFPacket : NSObject {
 @private
	NSUInteger _tag;
	
	NSTimer *timeoutTimer;
	NSTimeInterval _duration;
}

/*!
	@property
 */
@property (readonly) NSUInteger tag;

/*!
	@method
 */
- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration;

/*!
	@property
	@abstract	This is a dynamic property for subclasses to implement
 */
@property (readonly) NSData *buffer;

/*!
	@method
	@abstract	This is an override point
	@result		Vaules in the range [0.0, 1.0], this method returns 0.0 by default
	@param		|fraction| is required, calling with a NULL argument will raise an exception
 */
- (void)progress:(float *)fraction done:(NSUInteger *)bytesDone total:(NSUInteger *)bytesTotal;

/*!
	@method
 */
- (void)startTimeout;

/*!
	@method
 */
- (void)cancelTimeout;

@end
