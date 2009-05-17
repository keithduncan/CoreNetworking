//
//  AFPluralTransformer.h
//  Amber
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
	@brief
	This class accepts an NSNumber or <NSFastEnumeration> collection and returns @"s" if
	<tt>-integerValue</tt> or <tt>-count</tt> is greater than one, respectively.
 */
@interface AFPluralTransformer : NSValueTransformer

@end
