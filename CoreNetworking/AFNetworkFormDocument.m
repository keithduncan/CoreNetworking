//
//  AFNetworkFormDataDocument.m
//  Amber
//
//  Created by Keith Duncan on 26/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkFormDocument.h"

#import "AFNetworkPacketWrite.h"
#import "AFNetworkPacketWriteFromReadStream.h"

const NSStringEncoding _AFNetworkFormEncoding = NSUTF8StringEncoding;

static NSData *_AFNetworkFormDocumentHeadersDataFromDictionary(NSDictionary *headers) {
	NSMutableData *data = [NSMutableData data];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		
		NSString *currentHeader = [NSString stringWithFormat:@"%@: %@\r\n", currentKey, currentValue];
		[data appendData:[currentHeader dataUsingEncoding:_AFNetworkFormEncoding]];
	}
	[data appendData:[@"\r\n" dataUsingEncoding:_AFNetworkFormEncoding]];
	
	return data;
}

static NSString * _AFNetworkMultipartDocumentGenerateMultipartBoundaryWithHeaderAndFooter(NSData **multipartHeaderRef, NSData **multipartFooterRef) {
	NSString *multipartBoundary = [[NSProcessInfo processInfo] globallyUniqueString];
	multipartBoundary = [multipartBoundary stringByReplacingOccurrencesOfString:@"-" withString:@""];
	
	*multipartHeaderRef = [[NSString stringWithFormat:@"--%@\r\n", multipartBoundary] dataUsingEncoding:_AFNetworkFormEncoding];
	*multipartFooterRef = [[NSString stringWithFormat:@"--%@--\r\n", multipartBoundary] dataUsingEncoding:_AFNetworkFormEncoding];
	
	return multipartBoundary;
}

#pragma mark -

@interface _AFNetworkDocumentPart : NSObject

@property (readonly) NSString *contentType;

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef;

@end

@implementation _AFNetworkDocumentPart

@dynamic contentType;

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end

@interface _AFNetworkFormDocumentDataFieldPart : _AFNetworkDocumentPart {
 @private
	NSData *_data;
	NSString *_contentType;
}

- (id)initWithData:(NSData *)data contentType:(NSString *)contentType;

@property (readonly, retain) NSData *data;

@end

@interface _AFNetworkFormDocumentDataFieldPart ()
@property (readwrite, copy) NSString *contentType;
@end

@implementation _AFNetworkFormDocumentDataFieldPart

@synthesize data=_data, contentType=_contentType;

- (id)initWithData:(NSData *)data contentType:(NSString *)contentType {
	self = [self init];
	if (self == nil) return nil;
	
	_data = [data retain];
	_contentType = [contentType copy];
	
	return self;
}

- (void)dealloc {
	[_data release];
	[_contentType release];
	
	[super dealloc];
}

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef {
	NSString *MIMEType = [self contentType];
	MIMEType = (MIMEType ? : @"application/octet-stream");
	
	[headers addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
									   @"binary", AFNetworkDocumentMIMEContentTransferEncoding,
									   MIMEType, AFNetworkDocumentMIMEContentType,
									   nil]
	 ];
	
	if (frameLengthRef != NULL) {
		*frameLengthRef = [[self data] length];
	}
	
	if ([self data] == nil) {
		return nil;
	}
	
	return [NSArray arrayWithObject:[[[AFNetworkPacketWrite alloc] initWithData:[self data]] autorelease]];
}

@end

static NSString *const _AFNetworkFormDocumentFileFieldPartLocationKey = @"location";

@interface _AFNetworkFormDocumentFileFieldPart : _AFNetworkDocumentPart {
 @private
	NSURL *_location;
}

- (id)initWithLocation:(NSURL *)location;

@property (readonly, copy) NSURL *location;

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

- (NSString *)contentType {
	NSString *defaultMIMEType = @"application/octet-stream";
	
	NSString *resourceType = nil;
	BOOL getMIMEType = [[self location] getResourceValue:&resourceType forKey:NSURLTypeIdentifierKey error:NULL];
	if (!getMIMEType) return defaultMIMEType;
	
	NSString *MIMEType = [NSMakeCollectable(UTTypeCopyPreferredTagWithClass((CFStringRef)resourceType, kUTTagClassMIMEType)) autorelease];
	if (MIMEType == nil) return defaultMIMEType;
	
	return MIMEType;
}

- (NSArray *)documentPacketsWithMutableHeaders:(NSMutableDictionary *)headers frameLength:(NSUInteger *)frameLengthRef {
	NSNumber *resourceLength = nil;
	BOOL getResourceLength = [[self location] getResourceValue:&resourceLength forKey:NSURLFileSizeKey error:NULL];
	if (!getResourceLength) return nil;
	
	
	NSString *MIMEType = [self contentType];
	
	[headers addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
									   @"binary", AFNetworkDocumentMIMEContentTransferEncoding,
									   MIMEType, AFNetworkDocumentMIMEContentType,
									   nil]
	 ];
	
#if 1
	NSInputStream *readStream = [[[NSInputStream alloc] initWithURL:[self location]] autorelease];
	AFNetworkPacketWriteFromReadStream *filePacket = [[[AFNetworkPacketWriteFromReadStream alloc] initWithReadStream:readStream totalBytesToWrite:[resourceLength unsignedIntegerValue]] autorelease];
#else
	NSData *fileData = [NSData dataWithContentsOfURL:[self location]];
	AFPacketWrite *filePacket = [[[AFPacketWrite alloc] initWithData:fileData] autorelease];
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
	return [[self values] objectForKey:fieldname];
}

- (void)setValue:(NSString *)value forField:(NSString *)fieldname {
	[[self values] setValue:value forKey:fieldname];
	[[self files] removeObjectForKey:fieldname];
}

- (NSSet *)fileLocationsForField:(NSString *)fieldname {
	return [[[[self files] objectForKey:fieldname] allValues] valueForKey:_AFNetworkFormDocumentFileFieldPartLocationKey];
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

- (void)_appendPart:(_AFNetworkDocumentPart *)part toCumulativePackets:(NSMutableArray *)cumulativePackets cumulativeFrameLength:(NSUInteger *)cumulativeFrameLengthRef withContentDisposition:(NSString *)contentDisposition {
	NSUInteger partFrameLength = 0;
	NSMutableArray *partPackets = [NSMutableArray array];
	
	NSUInteger currentValueFrameLength = 0;
	NSMutableDictionary *currentValueHeaders = [NSMutableDictionary dictionary];
	NSArray *currentValuePackets = [part documentPacketsWithMutableHeaders:currentValueHeaders frameLength:&currentValueFrameLength];
	
	[currentValueHeaders addEntriesFromDictionary:[NSDictionary	dictionaryWithObjectsAndKeys:
												   contentDisposition, AFNetworkDocumentMIMEContentDisposition,
												   nil]
	 ];
	
	NSData *currentValueHeadersData = _AFNetworkFormDocumentHeadersDataFromDictionary(currentValueHeaders);
	AFNetworkPacketWrite *currentValueHeadersPacket = [[[AFNetworkPacketWrite alloc] initWithData:currentValueHeadersData] autorelease];
	[partPackets addObject:currentValueHeadersPacket];
	partFrameLength += [currentValueHeadersData length];
	
	[partPackets addObjectsFromArray:currentValuePackets];
	partFrameLength += currentValueFrameLength;
	
	NSData *newLineData = [@"\r\n" dataUsingEncoding:_AFNetworkFormEncoding];
	AFNetworkPacketWrite *newLinePacket = [[[AFNetworkPacketWrite alloc] initWithData:newLineData] autorelease];
	[partPackets addObject:newLinePacket];
	partFrameLength += [newLineData length];
	
	
	[cumulativePackets addObjectsFromArray:partPackets];
	*cumulativeFrameLengthRef += partFrameLength;
}

- (NSArray *)serialisedPacketsWithContentType:(NSString **)contentTypeRef frameLength:(NSUInteger *)frameLengthRef {
	NSMutableArray *cumulativePackets = [NSMutableArray array];
	NSUInteger cumulativeFrameLength = 0;
	
	
	NSData *multipartHeader = nil, *multipartFooter = nil;
	NSString *multipartBoundary = _AFNetworkMultipartDocumentGenerateMultipartBoundaryWithHeaderAndFooter(&multipartHeader, &multipartFooter);
	
	
	for (NSString *currentFieldname in [self values]) {
		AFNetworkPacketWrite *headerPacket = [[[AFNetworkPacketWrite alloc] initWithData:multipartHeader] autorelease];
		[cumulativePackets addObject:headerPacket];
		cumulativeFrameLength += [multipartHeader length];
		
		
		NSString *currentValue = [[self values] objectForKey:currentFieldname];
		NSData *currentValueData = ([currentValue length] > 0 ? [currentValue dataUsingEncoding:_AFNetworkFormEncoding] : nil);
		NSString *currentValueContentType = [NSString stringWithFormat:@"text/plain; charset=%@", (id)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(_AFNetworkFormEncoding))];
		_AFNetworkFormDocumentDataFieldPart *currentValuePart = [[[_AFNetworkFormDocumentDataFieldPart alloc] initWithData:currentValueData contentType:currentValueContentType] autorelease];
		
		NSString *contentDisposition = [NSString stringWithFormat:@"form-data; name=\"%@\"", currentFieldname];
		[self _appendPart:currentValuePart toCumulativePackets:cumulativePackets cumulativeFrameLength:&cumulativeFrameLength withContentDisposition:contentDisposition];
	}
	
	
	for (NSString *currentFieldname in [self files]) {
		AFNetworkPacketWrite *headerPacket = [[[AFNetworkPacketWrite alloc] initWithData:multipartHeader] autorelease];
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
		NSString *innerMultipartBoundary = _AFNetworkMultipartDocumentGenerateMultipartBoundaryWithHeaderAndFooter(&innerMultipartHeader, &innerMultipartFooter);
		
		
		NSDictionary *innerDocumentHeaders = [NSDictionary dictionaryWithObjectsAndKeys:
											  [NSString stringWithFormat:@"multipart/mixed; boundary=%@", innerMultipartBoundary], AFNetworkDocumentMIMEContentType,
											  [NSString stringWithFormat:@"form-data; name=\"%@\"", currentFieldname], AFNetworkDocumentMIMEContentDisposition,
											  nil];
		NSData *innerDocumentHeadersData = _AFNetworkFormDocumentHeadersDataFromDictionary(innerDocumentHeaders);
		AFNetworkPacketWrite *innerDocumentHeadersPacket = [[[AFNetworkPacketWrite alloc] initWithData:innerDocumentHeadersData] autorelease];
		[cumulativePackets addObject:innerDocumentHeadersPacket];
		cumulativeFrameLength += [innerDocumentHeadersData length];
		
		for (NSString *currentFilename in currentLocations) {
			AFNetworkPacketWrite *innerHeaderPacket = [[[AFNetworkPacketWrite alloc] initWithData:innerMultipartHeader] autorelease];
			[cumulativePackets addObject:innerHeaderPacket];
			cumulativeFrameLength += [innerMultipartHeader length];
			
			_AFNetworkFormDocumentFileFieldPart *currentValue = [currentLocations objectForKey:currentFilename];
			NSString *contentDisposition = [NSString stringWithFormat:@"file; filename=\"%@\"", currentFilename];
			[self _appendPart:currentValue toCumulativePackets:cumulativePackets cumulativeFrameLength:&cumulativeFrameLength withContentDisposition:contentDisposition];
		}
		
		AFNetworkPacketWrite *innerFooterPacket = [[[AFNetworkPacketWrite alloc] initWithData:innerMultipartFooter] autorelease];
		[cumulativePackets addObject:innerFooterPacket];
		cumulativeFrameLength += [innerMultipartFooter length];
	}
	
	
	AFNetworkPacketWrite *footerPacket = [[[AFNetworkPacketWrite alloc] initWithData:multipartFooter] autorelease];
	[cumulativePackets addObject:footerPacket];
	cumulativeFrameLength += [multipartFooter length];
	
	
	if (contentTypeRef != NULL) *contentTypeRef = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", multipartBoundary];
	if (frameLengthRef != NULL) *frameLengthRef = cumulativeFrameLength;
	
	
	return cumulativePackets;
}

@end
