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
	Compares the receiver, after trimming whitespace, to @"".
 */
- (BOOL)isEmpty;

/*!
	@result
	A substring from index zero to |count| characters and then appends @"..."
 */
- (NSString *)stringByAppendingElipsisAfterCharacters:(NSUInteger)count;

@end

/*!
	@brief
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
