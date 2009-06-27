//
//  AFStreamPacketQueue.m
//  Amber
//
//  Created by Keith Duncan on 25/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFStreamPacketQueue.h"

@interface AFStreamPacketQueue ()
@property (readonly) id <AFStreamPacketQueueDelegate> delegate;
@property (assign) BOOL dequeuing;
@end

@implementation AFStreamPacketQueue

@synthesize delegate=_delegate;
@synthesize stream=_stream;

@synthesize dequeuing=_dequeuing;
@synthesize flags=_flags;

- (id)initWithStream:(id)stream delegate:(id <AFStreamPacketQueueDelegate>)delegate {
	NSParameterAssert(delegate != nil);
	
	self = [self init];
	if (self == nil) return nil;
	
	_delegate = delegate;
	_stream = (id)CFMakeCollectable(CFRetain(stream));
	
	return self;
}

- (void)dealloc {
	CFRelease(_stream);
	
	[super dealloc];
}

- (void)tryDequeuePackets {
	if (self.dequeuing) return;
	
	if (![self.delegate streamQueueCanDequeuePackets:self]) return;
	
	self.dequeuing = YES;
	
	do {
		if ([self.delegate streamQueue:self shouldTryDequeuePacket:self.currentPacket]) [self dequeued];
	} while ([self tryDequeue]);
	
	self.dequeuing = NO;
}

@end
