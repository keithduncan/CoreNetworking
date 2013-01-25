//
//  AFHTTPTransaction.h
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	This class encapsulates a request/response pair.
 */
@interface AFHTTPTransaction : NSObject {
 @private
	NSArray *_requestPackets;
	BOOL _finishedRequestPackets;
	
	NSArray *_responsePackets;
	BOOL _finishedResponsePackets;
	
	void *_context;
}

/*!
	\brief
	Retains the request and creates an empty response.
	A NULL request, will result in an empty request being allocated.
 */
- (id)initWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets context:(void *)context;

AFNETWORK_EXTERN NSString *const AFHTTPTransactionRequestPacketsKey;
@property (readonly, nonatomic) NSArray *requestPackets;
@property (assign, nonatomic) BOOL finishedRequestPackets;

AFNETWORK_EXTERN NSString *const AFHTTPTransactionResponsePacketsKey;
@property (readonly, nonatomic) NSArray *responsePackets;
@property (assign, nonatomic) BOOL finishedResponsePackets;

@property (readonly, nonatomic) void *context;

@end
