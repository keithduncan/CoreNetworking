//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import "AFPacketWriteFromReadStream.h"

#import "AFPacketWrite.h"

#import "AFNetworkFunctions.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketWriteFromReadStream ()
@property (retain) AFPacketWrite *currentWrite;
@end

@implementation AFPacketWriteFromReadStream

@synthesize currentWrite=_currentWrite;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(CFReadStreamRef)readStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead {
	NSParameterAssert(CFReadStreamGetStatus(readStream) == kCFStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_readStream = (CFReadStreamRef)CFMakeCollectable(CFRetain(readStream));
	_numberOfBytesToRead = numberOfBytesToRead;
	
	return self;
}

- (void)dealloc {
	CFRelease(_readStream);

	[_currentWrite release];
	
	[super dealloc];
}

- (BOOL)performWrite:(CFWriteStreamRef)writeStream error:(NSError **)errorRef {
	if (!_opened) {
		_opened = YES;
		
		Boolean opened = CFReadStreamOpen(_readStream);
		if (!opened) {
			if (errorRef != NULL)
				*errorRef = AFErrorFromCFStreamError(CFReadStreamGetError(_readStream));
			return NO;
		}
	}
	
	do {
		if ([self currentWrite] == nil) {
			size_t bufferSize = (32 * 1024);
			if (_numberOfBytesToRead >= 0) {
				bufferSize = MIN(_numberOfBytesToRead, bufferSize);
				if (bufferSize == 0) break;
			}
			
			UInt8 *buffer = malloc(bufferSize);
			CFIndex bytesRead = CFReadStreamRead(_readStream, buffer, bufferSize);
			
			if (bytesRead < 0) {
				if (errorRef != NULL)
					*errorRef = AFErrorFromCFStreamError(CFReadStreamGetError(_readStream));
				
				free(buffer);
				
				return NO;
			}
			
			_numberOfBytesToRead -= bytesRead;
			
			AFPacketWrite *nextWrite = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:[NSData dataWithBytes:buffer length:bytesRead]] autorelease];
			
			free(buffer);
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_writePacketDidComplete:) name:AFPacketDidCompleteNotificationName object:nextWrite];
			[self setCurrentWrite:nextWrite];
		}
		
		BOOL writeSucceeded = [[self currentWrite] performWrite:writeStream error:errorRef];
		if (!writeSucceeded) return NO;
	} while ([self currentWrite] == nil);
	
	return YES;
}

- (void)_writePacketDidComplete:(NSNotification *)notification {
	AFPacketWrite *packet = [notification object];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	[self setCurrentWrite:nil];
	
	if ((_numberOfBytesToRead < 0 && CFReadStreamGetStatus(_readStream) == kCFStreamStatusAtEnd) || _numberOfBytesToRead == 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
		return;
	}
}

@end
