//
//  AFNetworkXMLElementPacket.m
//  Amber
//
//  Created by Keith Duncan on 28/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkXMLElementPacket.h"

#import "AFNetworkPacketRead.h"

@interface AFNetworkXMLElementPacket ()
@property (retain, nonatomic) AFNetworkPacket <AFNetworkPacketReading> *currentRead;

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket;
- (void)_unobserveAndClearCurrentPacket;

@property (readonly, nonatomic) NSMutableData *xmlBuffer;
@end

@implementation AFNetworkXMLElementPacket

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
	[self _unobservePacket:_currentRead];
	[_currentRead release];
	
	[_xmlBuffer release];
	
	[super dealloc];
}

- (NSString *)buffer {
	return [[[NSString alloc] initWithData:_xmlBuffer encoding:_encoding] autorelease];
}

- (AFNetworkPacketRead *)_nextReadPacket {
	id terminator = [@">" dataUsingEncoding:_encoding];
	return [[[AFNetworkPacketRead alloc] initWithTerminator:terminator] autorelease];
}

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:packet];
}

- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:packet];
}

- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket {
	[self _unobserveAndClearCurrentPacket];
	
	[self _observePacket:newPacket];
	self.currentRead = newPacket;
}

- (void)_unobserveAndClearCurrentPacket {
	AFNetworkPacket <AFNetworkPacketReading> *currentPacket = self.currentRead;
	if (currentPacket == nil) {
		return;
	}
	
	[self _unobservePacket:currentPacket];
	self.currentRead = nil;
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (NSInteger)performRead:(NSInputStream *)readStream {
	NSInteger currentBytesRead = 0;
	
	do {
		if (self.currentRead == nil) {
			AFNetworkPacketRead *newPacket = [self _nextReadPacket];
			[self _observeAndSetCurrentPacket:newPacket];
		}
		
		NSInteger bytesRead = [self.currentRead performRead:readStream];
		if (bytesRead < 0) {
			return -1;
		}
		
		currentBytesRead += bytesRead;
	} while (self.currentRead == nil);
	
	return currentBytesRead;
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFNetworkPacketRead *packet = [notification object];
	
	NSError *packetError = [[notification userInfo] objectForKey:AFNetworkPacketErrorKey];
	if (packetError != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	[self.xmlBuffer appendData:packet.buffer];
	
	NSString *xmlString = [[[NSString alloc] initWithData:self.currentRead.buffer encoding:_encoding] autorelease];
	xmlString = [xmlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([xmlString rangeOfString:@"</"].location != NSNotFound) {
		_depth--;
	}
	else if ([xmlString rangeOfString:@"/>"].location != NSNotFound) {
		(void)_depth;
	}
	else {
		_depth++;
	}
	
	if (_depth > 0) {
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
}

@end
