//
//  AFKeyValueBinding.h
//  Amber
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#if TARGET_OS_IPHONE

#import <Foundation/Foundation.h>

extern NSString *const AFObservedKeyPathKey;
extern NSString *const AFObservedObjectKey;
extern NSString *const AFOptionsKey;

#else

#import <Cocoa/Cocoa.h>

#endif

/*!
	@header
	This is an extention of the NSKeyValueBinding protocol.
 */

/*!
	@brief
	This constant stores the current value of an unbound binding.
 */
extern NSString *const AFUnboundValueKey;

/*!
	@brief
	This is to be implemented by adpoters.
 */
@protocol AFKeyValueBinding <NSObject>

- (id)infoForBinding:(NSString *)binding;
- (void)setInfo:(id)info forBinding:(NSString *)binding;

- (void *)contextForBinding:(NSString *)binding;

@end

/*!
	@brief
	The methods in this category are implemented on NSObject and require AFKeyValueBinding.
 */
@interface NSObject (AFKeyValueBindingAdditions)

/*!
	@brief
	This method will run the value through a value transformer if one is provided.
	It will retrieve an unbound value from the <tt>-infoForBinding:</tt> dictionary under the AFUnboundValueKey if the controller object is nil.
 */
- (id)valueForBinding:(NSString *)binding;

/*!
	@brief
	This method will reverse the value through a value transformer if one is provided.
	It will store the value in the <tt>-infoForBinding:</tt> dictionary under the AFUnboundValueKey if the controller object is nil.
 */
- (void)setValue:(id)value forBinding:(NSString *)binding;

/*!
	@result
	From the <tt>-infoForBinding:</tt> dictionary, the <tt>-objectForKey:</tt> NSObservedObjectKey.
 */
- (id)controllerForBinding:(NSString *)binding;

/*!
	@result
	From the <tt>-infoForBinding:</tt> dictionary, the <tt>-objectForKey:</tt> NSObservedKeyPathKey.
 */
- (NSString *)keyPathForBinding:(NSString *)binding;

#if !TARGET_OS_IPHONE
/*!
	@brief
	This method first checks the NSValueTransformerBindingOption key for a provided instance,
	secondly it attempts to retrieve one from <tt>+[NSValueTransformer valueTransformerForName:]</tt>
	using NSValueTransformerNameBindingOption. If neither succeed it returns nil.
 
	@result
	The value transformer specified in the NSOptionsKey for the binding.
 */
- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding;
#endif

@end

/*!
	@header
 
	@brief
	These are common additional bindings.
 */

#if TARGET_OS_IPHONE

/*
	These are only delcared when compling for the iPhone because they exist in AppKit already.
 */

/*!
	@brief
	This binding should represent a singular object.
 */
extern NSString *const AFContentObject;

#endif

/*!
	@brief
	An NSDate indicating the current month. Readwrite binding.
 */
extern NSString *const AFCurrentMonthBinding;

/*!
	@brief
	A singular version of NSSelectionIndexPathsBinding. Readwrite binding.
 */
extern NSString *const AFSelectionIndexPathBinding;
