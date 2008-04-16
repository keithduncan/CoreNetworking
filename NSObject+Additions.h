//
//  NSObject+Additions.h
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (Additions)
- (id)mainThreadProxy; // This returns a proxy to the main thread, any messages sent will be performed synchronously
@end
