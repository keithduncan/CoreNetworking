//
//  NSObject+Additions.h
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (AFAdditions) // Note: experimental interface

// Caution: don't become overly confident with the thread proxy methods
//	If you intent to execute a method on the main thread using the proxy, that method will be enqued in the main thread's run loop and WILL execute on the main thread - the calling thread WILL block until the method returns - but once it does the execution will continue in the calling thread
//	Execution doesn't yield to the main thread so be careful what you do with return values from -threadProxy

- (id)mainThreadProxy; // Note: messages will be performed synchronously
- (id)threadProxy:(NSThread *)object; // Note: messages performed synchronously iff (thread == [NSThread mainThread])

- (id)protocolProxy:(Protocol *)protocol; // Note: only selectors that return true for respondsToSelector: will be forwarded
@end
