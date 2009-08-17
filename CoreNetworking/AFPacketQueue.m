//
//  AFPacketQueue.m
//  Amber
//
//  Created by Keith Duncan on 02/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketQueue.h"

@interface AFPacketQueue ()
@property (retain) NSMutableArray *packets;
@property (readwrite, retain) id currentPacket;
@end

@implementation AFPacketQueue

@synthesize packets=_packets;
@synthesize currentPacket=_currentPacket;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_packets = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc {
	[_packets release];
	[_currentPacket release];
	
	[super dealloc];
}

- (NSUInteger)count {
	return [self.packets count];
}

- (void)enqueuePacket:(id)packet {
	[self.packets addObject:packet];
	[self tryDequeue];
}

- (BOOL)tryDequeue {
	if (self.currentPacket != nil) return NO;
	if ([self.packets count] == 0) return NO;
	
	// Note: the order of execution here is crucial, don't change it
	
	const NSUInteger newPacketIndex = 0;
	
	id newPacket = [[self.packets objectAtIndex:newPacketIndex] retain];
	
	[self.packets removeObjectAtIndex:newPacketIndex];
	self.currentPacket = newPacket;
	
	[newPacket release];
	
	return YES;
}

- (void)dequeued {
	self.currentPacket = nil;
}

- (void)emptyQueue {
	[self.packets removeAllObjects];
	[self dequeued];
}

@end
