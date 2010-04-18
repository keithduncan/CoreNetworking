//
//  AFXMLElementPacket.m
//  Amber
//
//  Created by Keith Duncan on 28/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFXMLElementPacket.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFPacketRead.h"

@interface AFXMLElementPacket ()
@property (retain) AFPacketRead *currentRead;
@property (readonly) NSMutableData *xmlBuffer;
@end

@implementation AFXMLElementPacket

@synthesize currentRead=_currentRead, xmlBuffer=_xmlBuffer;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_xmlBuffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithStringEncoding:(NSStringEncoding)encoding {
	self = [self init];
	if (self == nil) return nil;
	
	_encoding = encoding;
	
	return self;
}

- (void)dealloc {
	[_currentRead release];
	[_xmlBuffer release];
	
	[super dealloc];
}

- (NSString *)buffer {
	return [[[NSString alloc] initWithData:_xmlBuffer encoding:_encoding] autorelease];
}

- (AFPacketRead *)_nextReadPacket {
	id terminator = [@">" dataUsingEncoding:_encoding];
	return [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:terminator] autorelease];
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) {
			AFPacketRead *newPacket = [self _nextReadPacket];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newPacket];
			self.currentRead = newPacket;
		}
		
		[self.currentRead performRead:readStream];
	} while (self.currentRead == nil);
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *packet = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	NSError *packetError = [[notification userInfo] objectForKey:AFPacketErrorKey];
	if (packetError != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	
	[[self xmlBuffer] appendData:packet.buffer];
	
	NSString *xmlString = [[[NSString alloc] initWithData:self.currentRead.buffer encoding:_encoding] autorelease];
	xmlString = [xmlString stringByTrimmingWhiteSpace];
	
	if (!NSEqualRanges([xmlString rangeOfString:@"</"], NSMakeRange(NSNotFound, 0))) _depth--;
	else if (!NSEqualRanges([xmlString rangeOfString:@"/>"], NSMakeRange(NSNotFound, 0))) _depth;
	else _depth++;
	
	if (_depth <= 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
		return;
	}
	
	self.currentRead = nil;
}

@end
