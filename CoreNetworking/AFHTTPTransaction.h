//
//  AFHTTPTransaction.h
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009. All rights reserved.
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
 @private
	NSArray *_requestPackets;
	NSArray *_responsePackets;
	
	id _completionBlock;
}

/*!
	@brief
	This method retains the request and creates an empty response.
	A NULL request, will result in an empty request being allocated.
 */
- (id)initWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets;

@property (readonly) NSArray *requestPackets;
@property (readonly) NSArray *responsePackets;

@property (copy) id completionBlock;

@end
