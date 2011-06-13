//
//  AFPacket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacket.h"

NSString *const AFNetworkPacketDidTimeoutNotificationName = @"AFPacketDidTimeoutNotification";
NSString *const AFNetworkPacketDidCompleteNotificationName = @"AFPacketDidCompleteNotification";
NSString *const AFNetworkPacketErrorKey = @"AFPacketError";

@implementation AFNetworkPacket

@synthesize context=_context;
@synthesize duration=_duration;

- (void)dealloc {
	[self stopTimeout];
	
	[super dealloc];
}

- (id)buffer {
	return nil;
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" "];
	
	NSInteger done = 0, total = 0;
	float currentProgress = [self currentProgressWithBytesDone:&done bytesTotal:&total];
	[description appendFormat:@"current progress %ld bytes of %ld total. %.2f%% done.", done, total, (currentProgress * 100.)];
	
	return description;	
}

- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal {
	if (bytesDone != NULL) *bytesDone = 0;
	if (bytesTotal != NULL) *bytesTotal = 0;
	return 0.;
}

- (void)_timeout:(NSTimer *)sender {
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidTimeoutNotificationName object:self userInfo:nil];
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
