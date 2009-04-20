//
//  AFKeyValueBinding.h
//  Amber
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#if TARGET_OS_MAC && (defined(TARGET_OS_IPHONE) && !TARGET_OS_IPHONE)

#import <Cocoa/Cocoa.h>

#else

#import <Foundation/Foundation.h>

extern NSString *const AFObservedKeyPathKey;
extern NSString *const AFObservedObjectKey;

#endif

/*
 This is an extention of the NSKeyValueBinding protocol
 */

extern NSString *const AFUnboundValueKey;

@protocol AFKeyValueBinding // This is to be implemented by adpoters
- (id)infoForBinding:(NSString *)binding;
- (void)setInfo:(id)info forBinding:(NSString *)binding;

- (void *)contextForBinding:(NSString *)binding;
@end

// These are implemented in NSObject and require AFKeyValueBinding
@interface NSObject (AFKeyValueBindingAdditions)
// These take care of running the value through a value transformer if required.
// These store/retrieve an unbound value in a dictionary under the AFUnboundValueKey of the controller object == nil
- (id)valueForBinding:(NSString *)binding;
- (void)setValue:(id)value forBinding:(NSString *)binding;

- (id)controllerForBinding:(NSString *)binding;
- (NSString *)keyPathForBinding:(NSString *)binding;

#if TARGET_OS_MAC && (defined(TARGET_OS_IPHONE) && !TARGET_OS_IPHONE)
- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding;
#endif

@end

/*
 These are common additional bindings
 */

extern NSString *const AFCurrentMonthBinding;
extern NSString *const AFSelectionIndexPathBinding;
