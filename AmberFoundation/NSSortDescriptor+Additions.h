//
//  NSSortDescriptor+Additions.h
//  Amber
//
//  Created by Keith Duncan on 27/06/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSortDescriptor (AFAdditions)

/*!
	@brief
	Simplifies the creation of multiple sort descriptors, by creating them inline.
 */
+ (NSArray *)ascending:(BOOL)ascending descriptorsForKeys:(NSString *)firstKey, ... NS_REQUIRES_NIL_TERMINATION;

@end
