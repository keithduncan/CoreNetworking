//
//  AFPacketReadToWriteStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import "AFPacketReadToWriteStream.h"

#import "AFPacketRead.h"

#import "AFNetworkFunctions.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketReadToWriteStream ()
@property (retain) AFPacketRead *currentRead;
@property (retain) NSData *writeBuffer;
@end

@implementation AFPacketReadToWriteStream

@synthesize currentRead=_currentRead, writeBuffer=_writeBuffer;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration writeStream:(CFWriteStreamRef)writeStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite {
	NSParameterAssert(CFWriteStreamGetStatus(writeStream) == kCFStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_writeStream = (CFWriteStreamRef)CFMakeCollectable(CFRetain(writeStream));
	_numberOfBytesToWrite = numberOfBytesToWrite;
	
	return self;
}

- (void)dealloc {
	CFRelease(_writeStream);
	
	[_currentRead release];
	[_writeBuffer release];
	
	[super dealloc];
}

- (BOOL)performRead:(CFReadStreamRef)readStream error:(NSError **)errorRef {
	if (!_opened) {
		_opened = YES;
		
		Boolean opened = CFWriteStreamOpen(_writeStream);
		if (!opened) {
			if (errorRef != NULL)
				*errorRef = AFErrorFromCFStreamError(CFWriteStreamGetError(_writeStream));
			return NO;
		}
	}
	
	do {
		if ([self currentRead] == nil) {
			size_t bufferSize = (32 * 1024);
			if (_numberOfBytesToWrite >= 0) {
				bufferSize = MIN(_numberOfBytesToWrite, bufferSize);
				if (bufferSize == 0) break;
			}
			
			AFPacketRead *newReadPacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:bufferSize]] autorelease];
			_numberOfBytesToWrite -= bufferSize;
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newReadPacket];
			self.currentRead = newReadPacket;
			
			BOOL readSuccessful = [[self currentRead] performRead:readStream error:errorRef];
			if (!readSuccessful) return NO;
			
			if (self.writeBuffer != nil) {
				const UInt8 *bytes = [self.writeBuffer bytes];
				NSUInteger byteCount = [self.writeBuffer length];
				
				while (byteCount != 0) {
					CFIndex bytesWritten = CFWriteStreamWrite(_writeStream, bytes, byteCount);
					
					if (bytesWritten == -1) {
						if (errorRef != NULL)
							*errorRef = AFErrorFromCFStreamError(CFWriteStreamGetError(_writeStream));
						return NO;
					}
					
					byteCount -= bytesWritten;
					bytes += bytesWritten;
				}
				
				self.writeBuffer = nil;
			}
		}
	} while (self.currentRead == nil);
	
	return YES;
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *readPacket = [notification object];
	self.writeBuffer = readPacket.buffer;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:readPacket];
	self.currentRead = nil;
}

@end
