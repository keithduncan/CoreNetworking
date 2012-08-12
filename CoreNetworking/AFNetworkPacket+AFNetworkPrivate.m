//
//  AFNetworkPacket+AFNetworkPrivate.m
//  CoreNetworking
//
//  Created by Keith Duncan on 07/02/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkPacket+AFNetworkPrivate.h"

#import "AFNetwork-Constants.h"

@implementation AFNetworkPacket (AFNetworkPrivate)

- (void)_packetDidTimeout:(NSTimer *)timer {
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   NSLocalizedStringFromTableInBundle(@"Couldn\u2019t connect to the server", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkPacket timeout error description"), NSLocalizedDescriptionKey,
							   NSLocalizedStringFromTableInBundle(@"The server stopped responding while dealing with your request, please try again later.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkPacket packet timeout error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
							   nil];
	NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorTimeout userInfo:errorInfo];
	
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFNetworkPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

- (NSTimeInterval)_calculateIdleTimeoutInterval {
	NSTimeInterval timeout = [self idleTimeout];
	if (timeout == -1) {
		timeout = 60.;
	}
	return timeout;
}

- (void)_resetIdleTimeoutTimer {
	if (self.idleTimeoutDisableCount > 0) {
		return;
	}
	
	NSTimeInterval timeout = [self _calculateIdleTimeoutInterval];
	if (timeout == 0) {
		return;
	}
	
	[self _stopIdleTimeoutTimer];
	self.idleTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(_packetDidTimeout:) userInfo:nil repeats:NO];
}

- (void)_stopIdleTimeoutTimer {
	[self.idleTimeoutTimer invalidate];
}

@end
