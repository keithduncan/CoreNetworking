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
	[self tryDequeue];
}

- (BOOL)tryDequeue {
	if (self.currentPacket != nil) return NO;
	if ([self.queue count] == 0) return NO;
	
	const NSUInteger newPacketIndex = 0;
	
	id newPacket = [[self.queue objectAtIndex:newPacketIndex] retain];
	
	[self.queue removeObjectAtIndex:newPacketIndex];
	self.currentPacket = newPacket;
	
	[newPacket release];
	
	return YES;
}

- (void)dequeued {
	self.currentPacket = nil;
}

- (void)emptyQueue {
	[self.queue removeAllObjects];
	[self dequeued];
}

@end
