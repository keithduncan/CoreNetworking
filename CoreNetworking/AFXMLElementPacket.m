//
//  AFXMLElementPacket.m
//  Amber
//
//  Created by Keith Duncan on 28/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFXMLElementPacket.h"

#import "AFPacketRead.h"

#import "NSString+Additions.h"

@interface AFXMLElementPacket ()
@property (retain) AFPacketRead *currentRead;
@end

@implementation AFXMLElementPacket

@synthesize currentRead=_currentRead;

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
	[_xmlBuffer release];
	
	[super dealloc];
}

- (NSString *)buffer {
	return [[[NSString alloc] initWithData:_xmlBuffer encoding:_encoding] autorelease];
}

- (AFPacketRead *)_nextReadPacket {
	id terminator = [@">" dataUsingEncoding:_encoding];
	return [[[AFPacketRead alloc] initWithTag:0 timeout:-1 terminator:terminator] autorelease];
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (BOOL)performRead:(CFReadStreamRef)stream error:(NSError **)errorRef {
	BOOL shouldContinue = NO;
	
	do {
		if (self.currentRead == nil)
			self.currentRead = [self _nextReadPacket];
		
		shouldContinue = [self.currentRead performRead:stream error:errorRef];
		
		if (shouldContinue) {
			[_xmlBuffer appendData:self.currentRead.buffer];
			
			NSString *xmlString = [[[NSString alloc] initWithData:self.currentRead.buffer encoding:_encoding] autorelease];
			xmlString = [xmlString stringByTrimmingWhiteSpace];
			
			self.currentRead = nil;
			
		
			if (!NSEqualRanges([xmlString rangeOfString:@"</"], NSMakeRange(NSNotFound, 0))) _depth--;
			else if (!NSEqualRanges([xmlString rangeOfString:@"/>"], NSMakeRange(NSNotFound, 0))) _depth;
			else _depth++;
			
			if (_depth <= 0) return YES;
		}
	} while (shouldContinue && self.currentRead == nil);
	
	return NO;
}

@end
