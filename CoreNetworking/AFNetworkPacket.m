//
//  AFPacket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacket.h"

#import "AFNetworkPacket+AFNetworkPrivate.h"

NSString *const AFNetworkPacketDidCompleteNotificationName = @"AFNetworkPacketDidCompleteNotification";
NSString *const AFNetworkPacketErrorKey = @"AFNetworkPacketError";

@implementation AFNetworkPacket

@synthesize context=_context;

@synthesize idleTimeout=_idleTimeout, idleTimeoutDisableCount=_idleTimeoutDisableCount, idleTimeoutTimer=_idleTimeoutTimer;

@synthesize userInfo=_userInfo;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_userInfo = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_idleTimeoutTimer invalidate];
	[_idleTimeoutTimer release];
	
	[_userInfo release];
	
	[super dealloc];
}

- (void)disableIdleTimeout {
	self.idleTimeoutDisableCount++;
	
	[self _stopIdleTimeoutTimer];
}

- (void)enableIdleTimeout {
	self.idleTimeoutDisableCount--;
	NSParameterAssert(self.idleTimeoutDisableCount >= 0);
	
	if (self.idleTimeoutDisableCount > 0) {
		return;
	}
	
	[self _resetIdleTimeoutTimer];
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
	if (bytesDone != NULL) {
		*bytesDone = 0;
	}
	if (bytesTotal != NULL) {
		*bytesTotal = 0;
	}
	return 0.;
}

@end
