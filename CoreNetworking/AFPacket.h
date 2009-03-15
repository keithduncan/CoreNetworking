//
//  AFPacket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	AFPacketNoError			= 0,
	AFPacketMaxedOutError	= 1,
};

@protocol AFPacketDelegate;

@interface AFPacket : NSObject {
	NSUInteger _tag;
	id <AFPacketDelegate> _delegate;
	
	NSTimer *timeoutTimer;
	NSTimeInterval _duration;
}

@property (readonly) NSUInteger tag;
- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration;

/*!
	@property
	@abstract	This is a dynamic property for subclasses to implement
 */
@property (readonly) NSData *buffer;

/*!
	@method
	@abstract	This is an override point
	@discussion	Appropriate values are [0.0, 1.0], this method returns 0.0 by default
	@param		|fraction| is required, calling with a NULL argument will raise an exception
 */
- (void)progress:(float *)fraction done:(NSUInteger *)bytesDone total:(NSUInteger *)bytesTotal;

@property (assign) id <AFPacketDelegate> delegate;

- (void)startTimeout;
- (void)cancelTimeout;

@end

@protocol AFPacketDelegate <NSObject>
- (void)packetDidTimeout:(AFPacket *)packet;
@end
