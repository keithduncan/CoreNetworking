//
//  NSObject+Additions.h
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (AFAdditions) // Note: experimental interface
- (id)mainThreadProxy; // Any messages sent will be performed synchronously
- (id)threadProxy:(NSThread *)object; // Note: performed synchronously if (thread == [NSThread mainThread])
- (id)optionalProxy; // any messages sent will be tested for respondsToSelector:
@end
