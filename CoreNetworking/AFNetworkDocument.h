//
//  AFNetworkDocument.h
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

AFNETWORK_EXTERN NSString *const AFNetworkDocumentMIMEContentType;
AFNETWORK_EXTERN NSString *const AFNetworkDocumentMIMEContentTransferEncoding;
AFNETWORK_EXTERN NSString *const AFNetworkDocumentMIMEContentDisposition;

/*!
	\brief
	An abstract superclass, this defines a serialisation API for subclass documents to conform to.
 */
@interface AFNetworkDocument : NSObject

/*!
	\brief
	Used to convert the document into a wire format. This efficiently decomposes the document into multiple packets.
	
	\param contentTypeRef
	The MIME type of the serialised document. Must not be NULL.
	
	\param frameLengthRef
	The combined frame length of the packets. Must not be NULL.
	
	\return
	An ordered collection of `AFPacket <AFNetworkPacketWriting>` objects which should be replayed over a write stream, nil if the document couldn't be serialised.
 */
- (NSArray *)serialisedPacketsWithContentType:(NSString **)contentTypeRef frameLength:(NSUInteger *)frameLengthRef;

@end

@interface AFNetworkDocument (AFNetworkAdditions)

/*!
	\brief
	Used to convert the document into a wire format.
	This inefficiently decomposes the document into a single data object and you should avoid using it.
	
	\details
	The default implementation is suitable for inheriting, it uses `serialisedPacketsWithContentType:frameLength:` to generate the packets, then accumulates them in an in-memory stream returning the result.
 
	\param contentTypeRef
	The MIME type of the serialised document. Must not be NULL.
	
	\return
	The serialised document, nil if the document couldn't be serialised.
 */
- (NSData *)serialisedDataWithContentType:(NSString **)contentTypeRef;

@end
