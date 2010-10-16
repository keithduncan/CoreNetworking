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
	This is a primitive method.
	
	\param thread
	This thread must service it's runloop, otherwise the message will not be executed.
	
	\param waitUntilDone
	If true, the caller will block until the target thread has executes each message.
	This is provided for executing work on the main thread and blocking until complation.
*/
- (id)threadProxy:(NSThread *)thread synchronous:(BOOL)waitUntilDone;

/*
	This simply calls <tt>-[NSObject threadProxy:]</tt> using [NSThread mainThread] as an argument.
	Sync messages will be performed synchronously. If async, control returns immediately to caller.
 */
- (id)syncMainThreadProxy;
- (id)asyncMainThreadProxy;

/*
	These enqueue the messages on a shared background thread.
	Sync messages will be performed synchronously. If async, control returns immediately to caller.
 */
- (id)syncBackgroundThreadProxy;
- (id)asyncBackgroundThreadProxy;

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
