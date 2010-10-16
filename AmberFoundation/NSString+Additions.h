//
//  NSString+Additions.h
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (AFAdditions)

/*!
	\brief
	Compares the receiver, after trimming whitespace, to @"".
 */
- (BOOL)isEmpty;

/*!
	\brief
	Parses parameters in the prescribed format.
	
	\param separator
	The '=' in key=value
	
	\param delimiter
	The '&' in key1=value1&key2=value2
 */
- (NSDictionary *)parametersWithSeparator:(NSString *)separator delimiter:(NSString *)delimiter;

@end

/*!
	\brief
	Assists in manipulating KVC dotted paths.
 */
@interface NSString (AFKeyValueCoding)

- (NSArray *)keyPathComponents;
- (NSString *)lastKeyPathComponent;

+ (NSString *)stringWithKeyPathComponents:(NSString *)component, ... NS_REQUIRES_NIL_TERMINATION;

- (NSString *)stringByAppendingKeyPath:(NSString *)keyPath;

- (NSString *)stringByRemovingKeyPathComponentAtIndex:(NSUInteger)index;
- (NSString *)stringByRemovingLastKeyPathComponent;

@end
