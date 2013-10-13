//
//  NSURLRequest+AFNetworkAdditions.h
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (AFNetworkAdditions)

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readonly, nonatomic) NSURL *HTTPBodyFile;

@end

@interface NSMutableURLRequest (AFNetworkAdditions)

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readwrite, copy, nonatomic) NSURL *HTTPBodyFile;

@end
