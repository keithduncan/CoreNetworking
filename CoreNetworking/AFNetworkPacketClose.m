//
//  AFNetworkPacketClose.m
//  CoreNetworking
//
//  Created by Keith Duncan on 09/08/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkPacketClose.h"

@implementation AFNetworkPacketClose

- (NSInteger)_perform:(NSStream *)stream {
	[stream close];
	
	/*
		Note
		
		stream doesn't inform its delegate that it closed
	 */
	id <NSStreamDelegate> delegate = [stream delegate];
	if ([delegate respondsToSelector:@selector(stream:handleEvent:)]) {
		[delegate stream:stream handleEvent:NSStreamEventEndEncountered];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
	
	return 0;
}

- (NSInteger)performRead:(NSInputStream *)inputStream {
	return [self _perform:inputStream];
}

- (NSInteger)performWrite:(NSOutputStream *)outputStream {
	return [self _perform:outputStream];
}

@end
