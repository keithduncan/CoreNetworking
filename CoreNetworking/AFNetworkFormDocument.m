//
//  AFNetworkFormDataDocument.m
//  Amber
//
//  Created by Keith Duncan on 26/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkFormDocument.h"

#import "AFPacketWrite.h"
#import "AFPacketWriteFromReadStream.h"

const NSStringEncoding _FormEncoding = NSUTF8StringEncoding;

#pragma mark -

static NSData *_AFNetworkFormDocumentHeadersDataFromDictionary(NSDictionary *headers) {
	NSMutableData *data = [NSMutableData data];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		
		NSString *currentHeader = [NSString stringWithFormat:@"%@: %@\r\n", currentKey, currentValue];
		[data appendData:[currentHeader dataUsingEncoding:_FormEncoding]];
	}
	[data appendData:[@"\r\n" dataUsingEncoding:_FormEncoding]];
	
	return data;
}

#pragma mark -

static NSString *const _AFNetworkFormDocumentFileFieldPartLocationKey = @"location";

@interface _AFNetworkFormDocumentFileFieldPart : NSObject {
 @private
	NSURL *_location;
}

- (id)initWithLocation:(NSURL *)location;

@property (readonly) NSURL *location;

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef;

@end

@implementation _AFNetworkFormDocumentFileFieldPart

@synthesize location=_location;

- (id)initWithLocation:(NSURL *)location {
	self = [self init];
	if (self == nil) return nil;
	
	_location = [location copy];
	
	return self;
}

- (void)dealloc {
	[_location release];
	
	[super dealloc];
}

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef {
	NSString *resourceType = nil;
	BOOL getMIMEType = [[self location] getResourceValue:&resourceType forKey:NSURLTypeIdentifierKey error:NULL];
	
	NSNumber *resourceLength = nil;
	BOOL getResourceLength = [[self location] getResourceValue:&resourceLength forKey:NSURLFileSizeKey error:NULL];
	
	if (!getMIMEType || !getResourceLength) return nil;
	
	
	NSString *MIMEType = [NSMakeCollectable(UTTypeCopyPreferredTagWithClass((CFStringRef)resourceType, kUTTagClassMIMEType)) autorelease];
	MIMEType = (MIMEType ? : @"application/ocet-stream");
	
	[headers addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
									   @"binary", @"Content-Transfer-Encoding",
									   MIMEType, @"Content-Type",
									   nil]
	 ];
	
#if 0
	NSInputStream *readStream = [[[NSInputStream alloc] initWithURL:[self location]] autorelease];
	AFPacketWriteFromReadStream *filePacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:readStream numberOfBytesToWrite:[resourceLength unsignedIntegerValue]] autorelease];
#else
	NSData *fileData = [NSData dataWithContentsOfURL:[self location]];
	AFPacketWrite *filePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:fileData] autorelease];
#endif
	
	if (frameLengthRef != NULL) *frameLengthRef = [resourceLength unsignedIntegerValue];
	
	return [NSArray arrayWithObject:filePacket];
}

@end

#pragma mark -

@interface AFNetworkFormDocument ()
@property (readonly) NSMutableDictionary *values, *files;
@end

@implementation AFNetworkFormDocument

@synthesize values=_values, files=_files;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_values = [[NSMutableDictionary alloc] init];
	_files = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_values release];
	[_files release];
	
	[super dealloc];
}

- (NSString *)valueForField:(NSString *)fieldname {
	[[self values] objectForKey:fieldname];
}

- (void)setValue:(NSString *)value forField:(NSString *)fieldname {
	[[self values] setValue:value forKey:fieldname];
	[[self files] removeObjectForKey:fieldname];
}

- (NSSet *)fileLocationsForField:(NSString *)fieldname {
	[[[[self files] objectForKey:fieldname] allValues] valueForKey:_AFNetworkFormDocumentFileFieldPartLocationKey];
}

- (void)addFileByReferencingURL:(NSURL *)location withFilename:(NSString *)filename toField:(NSString *)fieldname {
	NSParameterAssert([location isFileURL]);
	
	NSMutableDictionary *parts = [[self files] objectForKey:fieldname];
	if (parts == nil) {
		parts = [NSMutableDictionary dictionary];
		[[self files] setObject:parts forKey:fieldname];
	}
	
	_AFNetworkFormDocumentFileFieldPart *part = [[[_AFNetworkFormDocumentFileFieldPart alloc] initWithLocation:location] autorelease];
	
	if (filename == nil) filename = [location lastPathComponent];
	[parts setObject:part forKey:filename];
	
	[[self values] removeObjectForKey:fieldname];
}

- (NSString *)_generateMultipartBoundaryWithHeader:(NSData **)multipartHeaderRef footer:(NSData **)multipartFooterRef {
	NSString *multipartBoundary = [[NSProcessInfo processInfo] globallyUniqueString];
	multipartBoundary = [multipartBoundary stringByReplacingOccurrencesOfString:@"-" withString:@""];
	
	*multipartHeaderRef = [[NSString stringWithFormat:@"--%@\r\n", multipartBoundary] dataUsingEncoding:_FormEncoding];
	*multipartFooterRef = [[NSString stringWithFormat:@"--%@--\r\n", multipartBoundary] dataUsingEncoding:_FormEncoding];
	
	return multipartBoundary;
}

- (void)_appendPart:(_AFNetworkFormDocumentFileFieldPart *)part toCumulativePackets:(NSMutableArray *)cumulativePackets cumulativeFrameLength:(NSUInteger *)cumulativeFrameLengthRef withContentDisposition:(NSString *)contentDisposition {
	NSUInteger partFrameLength = 0;
	NSMutableArray *partPackets = [NSMutableArray array];
	
	NSUInteger currentValueFrameLength = 0;
	NSMutableDictionary *currentValueHeaders = [NSMutableDictionary dictionary];
	NSArray *currentValuePackets = [part documentPacketsWithMutableHeaders:currentValueHeaders frameLength:&currentValueFrameLength];
	
	[currentValueHeaders addEntriesFromDictionary:[NSDictionary	dictionaryWithObjectsAndKeys:
												   contentDisposition, @"Content-Disposition",
												   nil]
	 ];
	
	NSData *currentValueHeadersData = _AFNetworkFormDocumentHeadersDataFromDictionary(currentValueHeaders);
	AFPacketWrite *currentValueHeadersPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:currentValueHeadersData] autorelease];
	[partPackets addObject:currentValueHeadersPacket];
	partFrameLength += [currentValueHeadersData length];
	
	[partPackets addObjectsFromArray:currentValuePackets];
	partFrameLength += currentValueFrameLength;
	
	NSData *newLineData = [@"\r\n" dataUsingEncoding:_FormEncoding];
	AFPacketWrite *newLinePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:newLineData] autorelease];
	[partPackets addObject:newLinePacket];
	partFrameLength += [newLineData length];
	
	
	[cumulativePackets addObjectsFromArray:partPackets];
	*cumulativeFrameLengthRef += partFrameLength;
}

- (NSArray *)documentPacketsWithContentType:(NSString **)contentTypeRef frameLength:(NSUInteger *)frameLengthRef {
	NSMutableArray *cumulativePackets = [NSMutableArray array];
	NSUInteger cumulativeFrameLength = 0;
	
	
	NSData *multipartHeader = nil, *multipartFooter = nil;
	NSString *multipartBoundary = [self _generateMultipartBoundaryWithHeader:&multipartHeader footer:&multipartFooter];
	
	
	for (NSString *currentFieldname in [self values]) {
		AFPacketWrite *headerPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:multipartHeader] autorelease];
		[cumulativePackets addObject:headerPacket];
		cumulativeFrameLength += [multipartHeader length];
		
		
		NSMutableData *currentValueData = [NSMutableData data];
		
		NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSString stringWithFormat:@"form-data; name=\"%@\"", currentFieldname], @"Content-Disposition",
										@"text/plain", @"Content-Type",
										nil];
		[currentValueData appendData:_AFNetworkFormDocumentHeadersDataFromDictionary(headers)];
		
		NSString *currentValue = [[self values] objectForKey:currentFieldname];
		[currentValueData appendData:[currentValue dataUsingEncoding:_FormEncoding]];
		[currentValueData appendData:[@"\r\n" dataUsingEncoding:_FormEncoding]];
		
		AFPacketWrite *currentValuePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:currentValueData] autorelease];
		[cumulativePackets addObject:currentValuePacket];
		cumulativeFrameLength += [currentValueData length];
	}
	
	
	for (NSString *currentFieldname in [self files]) {
		AFPacketWrite *headerPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:multipartHeader] autorelease];
		[cumulativePackets addObject:headerPacket];
		cumulativeFrameLength += [multipartHeader length];
		
		
		NSDictionary *currentLocations = [[self files] objectForKey:currentFieldname];
		
		if ([currentLocations count] == 1) {
			NSString *currentFilename = [[currentLocations allKeys] objectAtIndex:0];
			_AFNetworkFormDocumentFileFieldPart *currentValue = [[currentLocations allValues] objectAtIndex:0];
			
			NSString *contentDisposition = [NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", currentFieldname, currentFilename];
			[self _appendPart:currentValue toCumulativePackets:cumulativePackets cumulativeFrameLength:&cumulativeFrameLength withContentDisposition:contentDisposition];
			
			continue;
		}
		
		
		
		NSData *innerMultipartHeader = nil, *innerMultipartFooter = nil;
		NSString *innerMultipartBoundary = [self _generateMultipartBoundaryWithHeader:&innerMultipartHeader footer:&innerMultipartFooter];
		
		
		NSDictionary *innerDocumentHeaders = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSString stringWithFormat:@"form-data; name=\"%@\"", currentFieldname], @"Content-Disposition",
											  [NSString stringWithFormat:@"multipart/mixed; boundary=%@", innerMultipartBoundary], @"Content-Type",
											  nil];
		NSData *innerDocumentHeadersData = _AFNetworkFormDocumentHeadersDataFromDictionary(innerDocumentHeaders);
		AFPacketWrite *innerDocumentHeadersPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:innerDocumentHeadersData] autorelease];
		[cumulativePackets addObject:innerDocumentHeadersPacket];
		cumulativeFrameLength += [innerDocumentHeadersData length];
		
		for (NSString *currentFilename in currentLocations) {
			AFPacketWrite *innerHeaderPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:innerMultipartHeader] autorelease];
			[cumulativePackets addObject:innerHeaderPacket];
			cumulativeFrameLength += [innerMultipartHeader length];
			
			_AFNetworkFormDocumentFileFieldPart *currentValue = [currentLocations objectForKey:currentFilename];
			NSString *contentDisposition = [NSString stringWithFormat:@"file; filename=\"%@\"", currentFilename];
			[self _appendPart:currentValue toCumulativePackets:cumulativePackets cumulativeFrameLength:&cumulativeFrameLength withContentDisposition:contentDisposition];
		}
		
		AFPacketWrite *innerFooterPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:innerMultipartFooter] autorelease];
		[cumulativePackets addObject:innerFooterPacket];
		cumulativeFrameLength += [innerMultipartFooter length];
	}
	
	
	AFPacketWrite *footerPacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:multipartFooter] autorelease];
	[cumulativePackets addObject:footerPacket];
	cumulativeFrameLength += [multipartFooter length];
	
	
	if (contentTypeRef != NULL) *contentTypeRef = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", multipartBoundary];
	if (frameLengthRef != NULL) *frameLengthRef = cumulativeFrameLength;
	
	
	return cumulativePackets;
}

@end
