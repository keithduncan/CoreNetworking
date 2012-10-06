//
//  NSObject+Additions.h
//  Amber
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\brief
	<b>Note: experimental interface, be prepared for it to break.</b>
 */
@interface NSObject (AFAdditions)

/*!
	\brief
	The proxy returned will only forward selectors that the target returns true for <tt>-respondsToSelector:</tt>.
 
	\details
	This allows you to send unimplemented selectors without throwing an exception.
 
	\return
	An <tt>AFProtocolProxy</tt> with the receiver as the target.
 */
- (id)protocolProxy:(Protocol *)protocol;

@end
