//
//  NSSortDescriptor+Additions.h
//  Shared Source
//
//  Created by Keith Duncan on 27/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSortDescriptor (AFAdditions)
+ (NSArray *)ascending:(BOOL)ascending descriptorsForKeys:(NSString *)firstKey, ... NS_REQUIRES_NIL_TERMINATION;
@end
