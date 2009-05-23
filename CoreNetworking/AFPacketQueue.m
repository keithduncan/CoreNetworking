//
//  AFPacketQueue.m
//  Amber
//
//  Created by Keith Duncan on 02/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketQueue.h"

@interface AFPacketQueue ()
@property (retain) NSMutableArray *queue;
@property (readwrite, retain) id currentPacket;
@end

@implementation AFPacketQueue

@synthesize queue=_queue;
@synthesize currentPacket=_currentPacket;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.queue = [NSMutableArray array];
	
	return self;
}

- (void)dealloc {
	self.queue = nil;
	self.currentPacket = nil;
	
	[super dealloc];
}

- (NSUInteger)count {
	return [self.queue count];
}

- (void)enqueuePacket:(id)packet {
	[self.queue addObject:packet];
	
	if (self.currentPacket != nil) return;
	[self dequeuePacket];
}

- (void)dequeuePacket {
	if ([self.queue count] > 0) {
		self.currentPacket = [self.queue objectAtIndex:0];
		[self.queue removeObjectAtIndex:0];
	} else {
		self.currentPacket = nil;
	}
}

- (void)emptyQueue {
	[self.queue removeAllObjects];
	[self dequeuePacket];
}

@end
