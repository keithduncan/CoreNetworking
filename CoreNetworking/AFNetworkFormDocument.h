//
//  AFNetworkFormDataDocument.h
//  Amber
//
//  Created by Keith Duncan on 26/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\brief
	This format is described in IETF-RFC-2388 http://tools.ietf.org/html/rfc2388
	
	\details
	The order you add values in is unpreserved.
 */
@interface AFNetworkFormDocument : NSObject {
 @private
	NSMutableDictionary *_values;
	NSMutableDictionary *_files;
}

/*!
	\brief
	Fetch a previously stored value for the field key.
 */
- (NSString *)valueForField:(NSString *)fieldname;

/*!
	\brief
	The fieldname must be unique per document, setting a value for an existing fieldname will overwrite the previous value.
 */
- (void)setValue:(NSString *)value forField:(NSString *)fieldname;

/*!
	\brief
	Unordered collection of previously added URLs using <tt>-addFileByReferencingURL:withFilename:toField:</tt>.
 */
- (NSSet *)fileLocationsForField:(NSString *)fieldname;

/*!
	\brief
	Form documents support multiple files per-fieldname.
	
	\param filename
	This is optional, excluding it will use the last path component.
 */
- (void)addFileByReferencingURL:(NSURL *)location withFilename:(NSString *)filename toField:(NSString *)fieldname;

/*!
	\brief
	Used to convert the document into a wire format.
	
	\return writePackets
	An ordered collection of <AFPacketWriting> conforming objects which should be replayed over the wire.
	Nil return value means the document couldn't be converted.
	
	\param contentTypeRef
	The document type.
	
	\param frameLengthRef
	Used for frame headers.
 */
- (NSArray *)documentPacketsWithContentType:(NSString **)contentTypeRef frameLength:(NSUInteger *)frameLengthRef;

@end
