//
//  AFXMLElementPacket.h
//  Amber
//
//  Created by Keith Duncan on 28/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFNetworkPacket.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFNetworkPacketRead;

/*!
	\brief
	This packet will read a complete XML chunk and it's contents.
 
	Return Examples:
	
	1. <element/>
	2. <element> </element>
	3. </element>
	
	\details
	The completed buffer is an NSString, allowing the caller to use whatever XML library is available.
 */
@interface AFXMLElementPacket : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	NSStringEncoding _encoding;
	
	AFNetworkPacketRead *_currentRead;
	
	NSMutableData *_xmlBuffer;
	NSInteger _depth;
}

/*!
	\brief
	Designated Initializer.
 */
- (id)initWithStringEncoding:(NSStringEncoding)encoding;

/*!
	\brief
	This returns the XML buffer as a string, encoded as you specified at initialization.
 */
- (NSString *)buffer;

@end
