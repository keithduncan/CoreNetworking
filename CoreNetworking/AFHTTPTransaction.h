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
	BOOL _emptyRequest;
	
	__strong CFHTTPMessageRef _request;
	__strong CFHTTPMessageRef _response;
}

/*!
	@brief
	This method retains the request and creates an empty response.
	A NULL request, will result in an empty request being allocated.
 */
- (id)initWithRequest:(CFHTTPMessageRef)request;

/*!
	@brief
	This property will reflect wether the transaction was created with a request, and is awaiting a response, or if it was created with an empty request and needs to read one first.
 */
@property (readonly) BOOL emptyRequest;

@property (readonly) CFHTTPMessageRef request;
@property (readonly) CFHTTPMessageRef response;

@end
