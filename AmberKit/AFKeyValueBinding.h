//
//  AFKeyValueBinding.h
//  Amber
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>

#define AFObservedKeyPathKey NSObservedKeyPathKey
#define AFObservedObjectKey NSObservedObjectKey
#define AFOptionsKey NSOptionsKey

#define AFValueTransformerBindingOption NSValueTransformerBindingOption
#define AFValueTransformerNameBindingOption NSValueTransformerNameBindingOption
#endif

/*!
	@header
	This is an extention of the NSKeyValueBinding protocol.
 */

extern NSString *AFObservedKeyPathKey;
extern NSString *AFObservedObjectKey;
extern NSString *AFOptionsKey;

extern NSString *AFValueTransformerBindingOption;
extern NSString *AFValueTransformerNameBindingOption;

/*!
	@brief
	This constant stores the current value of an unbound binding.
 */
extern NSString *const AFUnboundValueKey;

#if TARGET_OS_IPHONE
// Note: this category eliminates compiler warnings when using bindings with UIKit subclasses
@interface NSObject (AFKeyValueBinding)
- (void)bind:(NSString *)propertyName toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options;
- (void)unbind:(NSString *)propertyName;
@end
#endif

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

/*!
	@brief
	This method first checks the NSValueTransformerBindingOption key for a provided instance.
	Secondly it attempts to retrieve one from <tt>+[NSValueTransformer valueTransformerForName:]</tt> using NSValueTransformerNameBindingOption.
	If neither succeed it returns nil.
 
	@result
	The value transformer specified in the NSOptionsKey for the binding or nil.
 */
- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding;

@end

/*!
	@header
 
	@brief
	These are common additional bindings.
 */

#if TARGET_OS_IPHONE

/*
	This group of binding property names are only delcared when compling for the iPhone because they exist in AppKit already.
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
