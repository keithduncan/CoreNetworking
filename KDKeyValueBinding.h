//
//  KDKeyValueBinding.h
//  Shared Source
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
 This is an extention of the NSKeyValueBinding protocol
 */

extern NSString *const KDUnboundValueKey;

@interface NSObject (KDKeyValueBinding) // These are to be implemented by adpoters
- (NSMutableDictionary *)bindingInfoContainer;
- (void *)contextForBinding:(NSString *)binding;
@end

// These are implemented in NSObject and require KDKeyValueBinding
@interface NSObject (NSKeyValueBindingAdditions)
// These take care of running the value through a value transformer if required.
// These store/retrieve an unbound value in a dictionary under the KDUnboundValueKey of the controller object == nil
- (id)valueForBinding:(NSString *)binding;
- (void)setValue:(id)value forBinding:(NSString *)binding;

- (id)controllerForBinding:(NSString *)binding;
- (NSString *)keyPathForBinding:(NSString *)binding;
- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding;
@end

/*
 These are common additional bindings
 */

extern NSString *const KDCurrentMonthBinding;
extern NSString *const KDSelectionIndexPathBinding;
