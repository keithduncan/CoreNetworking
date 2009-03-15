//
//  AFPacket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacket.h"

@implementation AFPacket

@dynamic buffer;

@synthesize tag=_tag;
@synthesize delegate=_delegate;

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration {
	[self init];
	
	_tag = tag;
	_duration = duration;
	
	return self;
}

- (void)dealloc {
	[self cancelTimeout];
	
	[super dealloc];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	
	float fraction = 0.0;
	NSUInteger done = 0.0, total = 0.0;
	
	[self progress:&fraction done:&done total:&total];
	
	[description appendFormat:@"Currently progress %ld bytes (%ld total) %d%% done", done, total, fraction, nil];
	
	return description;	
}

- (void)progress:(float *)fraction done:(NSUInteger *)bytesDone total:(NSUInteger *)bytesTotal {
	NSParameterAssert(fraction != NULL);
	
	*fraction = 0.0;
	
	if (bytesDone != NULL) *bytesDone = 0;
	if (bytesTotal != NULL) *bytesTotal = 0;
}

- (void)_timeout:(NSTimer *)sender {
	[self.delegate packetDidTimeout:self];
}

- (void)startTimeout {
	timeoutTimer = [[NSTimer scheduledTimerWithTimeInterval:_duration target:self selector:@selector(_timeout:) userInfo:nil repeats:NO] retain];
}

- (void)cancelTimeout {
	[timeoutTimer invalidate];
	[timeoutTimer release];
}

@end
