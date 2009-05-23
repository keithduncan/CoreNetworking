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
	@result
	A copy of the receiver, with CFStringTimeWhitespace applied.
 */
- (NSString *)stringByTrimmingWhiteSpace;

/*!
	@brief
	This method compares the receiver, after trimming whitespace, to @"".
 */
- (BOOL)isEmpty;

/*!
	@brief
	This method returns a substring from index after |count| characters and then appends @"..."
 */
- (NSString *)stringByAppendingElipsisAfterCharacters:(NSUInteger)count;

@end

/*!
	@brief
	This category assists in manipulating KVC dotted paths.
 */
@interface NSString (AFKeyValueCoding)

- (NSArray *)keyPathComponents;
- (NSString *)lastKeyPathComponent;

+ (NSString *)keyPathWithComponents:(NSString *)component, ... NS_REQUIRES_NIL_TERMINATION;

- (NSString *)stringByAppendingKeyPath:(NSString *)keyPath;
- (NSString *)stringByRemovingKeyPathComponentAtIndex:(NSUInteger)index;
- (NSString *)stringByRemovingLastKeyPathComponent;

@end
