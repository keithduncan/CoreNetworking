//
//  NSString+Additions.h
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Additions)
- (NSString *)trimWhiteSpace;
- (BOOL)isEmpty;

- (NSString *)stringByAppendingElipsisAfterCharacters:(NSUInteger)count;
@end

@interface NSString (KDKeyValueCoding)
+ (NSString *)keyPathForComponents:(NSString *)component, ... NS_REQUIRES_NIL_TERMINATION;

- (NSArray *)keyPathComponents;
- (NSString *)lastKeyPathComponent;

- (NSString *)stringByAppendingKeyPath:(NSString *)keyPath;
- (NSString *)stringByRemovingKeyPathComponentAtIndex:(NSUInteger)index;
@end
