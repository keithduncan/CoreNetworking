//
//  AFHTTPTransaction.h
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

/*!
	@brief
	This class encapsulates a request/response pair.
 */
@interface AFHTTPTransaction : NSObject {
	CFHTTPMessageRef _request, _response;
}

/*!
	@brief
	This method retains the request and creates an empty response.
 */
- (id)initWithRequest:(CFHTTPMessageRef)request;

@property (readonly) CFHTTPMessageRef request, response;

/*!
	@brief
	This method uses the "Content-Length" header to determine how much more a client should read.
	If CFHTTPMessageIsHeaderComplete() returns false this method returns -1.
 */
- (NSInteger)responseBodyLength;

@end
