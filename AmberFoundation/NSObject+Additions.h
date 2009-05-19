//
//  NSObject+Additions.h
//  Amber
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	<b>Note: experimental interface, be prepared for it to break.</b>
 */
@interface NSObject (AFAdditions)

/*!
	@brief
	This simply calls <tt>-[NSObject threadProxy:]</tt> using [NSThread mainThread] as an argument.
	Messages will be performed synchronously.
 */
- (id)mainThreadProxy;

/*!
	@brief
	This creates a background thread and associates the proxy with it.
	Messages will be performed on it asynchronously.
 */
- (id)backgroundThreadProxy;

/*!
	@brief
	This method returns a private NSProxy subclass.
	Caution: don't become overly confident with the thread proxy methods.
 
	@detail
	If you intend to execute a method on the main thread using the proxy, that method
	will be enqueued on the main thread and WILL execute on the main thread - the calling
	thread WILL block until the method returns - but once it does the execution
	will continue in the calling thread. That is to say, execution doesn't yield to the
	main thread so be careful what you do with return values of methods called on -threadProxy.
 
	Note: messages performed synchronously iff [thread isEqual:[NSThread mainThread]]
 */
- (id)threadProxy:(NSThread *)object;

/*!
	@brief
	This method returns an <tt>AFProtocolProxy</tt> with the receiver as the target.
	Only selectors that the target returns true for <tt>-respondsToSelector:</tt> will be
	forwarded allowing you to send unimplemented selectors.
 */
- (id)protocolProxy:(Protocol *)protocol;

@end
