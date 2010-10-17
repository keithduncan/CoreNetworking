//
//  AFNetworkDocument.h
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const AFNetworkDocumentMIMEContentType;
extern NSString *const AFNetworkDocumentMIMEContentTransferEncoding;

@protocol AFNetworkDocument <NSObject>

/*!
	\brief
	Used to convert the document into a wire format. This efficiently decomposes the document into multiple packets.
	
	\param contentTypeRef
	The MIME type of the serialised document. Must not be NULL.
	
	\param frameLengthRef
	The combined frame length of the packets. Must not be NULL.
	
	\return
	An ordered collection of <tt>AFPacket <AFPacketWriting></tt> objects which should be replayed over a write stream.
	nil if the document couldn't be serialised.
 */
- (NSArray *)serialisedPacketsWithContentType:(NSString **)contentTypeRef frameLength:(NSUInteger *)frameLengthRef;

/*!
	\brief
	Used to convert the document into a wire format. This inefficiently decomposes the document into a single data object.
	
	\param contentTypeRef
	The MIME type of the serialised document. Must not be NULL.
	
	\return
	The serialised document.
	nil if the document couldn't be serialised.
 */
- (NSData *)serialisedDataWithContentType:(NSString **)contentTypeRef;

@end
