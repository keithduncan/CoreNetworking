//
//  AFPacket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacket.h"

NSString *const AFPacketDidTimeoutNotificationName = @"AFPacketDidTimeoutNotification";
NSString *const AFPacketDidCompleteNotificationName = @"AFPacketDidCompleteNotification";
NSString *const AFPacketErrorKey = @"AFPacketError";

@implementation AFPacket

@dynamic buffer;

@synthesize context=_context;
@synthesize duration=_duration;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration {
	self = [self init];
	if (self == nil) return nil;
	
	_context = context;
	_duration = duration;
	
	return self;
}

- (void)dealloc {
	[self stopTimeout];
	
	[super dealloc];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" "];
	
	NSUInteger done = 0, total = 0;
	float fraction = [self currentProgressWithBytesDone:&done bytesTotal:&total];
	
	[description appendFormat:@"current progress %ld bytes of %ld total. %f%% done.", done, total, fraction, nil];
	
	return description;	
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {
	if (bytesDone != NULL) *bytesDone = 0;
	if (bytesTotal != NULL) *bytesTotal = 0;
	
	return 0.0;
}

- (void)_timeout:(NSTimer *)sender {
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidTimeoutNotificationName object:self userInfo:nil];
}

- (void)startTimeout {
	if (self.duration < 0) return;
	
	timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:_duration target:self selector:@selector(_timeout:) userInfo:nil repeats:NO] retain];
}

- (void)stopTimeout {
	[timeoutTimer invalidate];
	
	[timeoutTimer release];
	timeoutTimer = nil;
}

@end
