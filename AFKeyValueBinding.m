//
//  AFKeyValueBinding.m
//  Shared Source
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AFKeyValueBinding.h"

#if TARGET_OS_IPHONE
NSString *const AFObservedKeyPathKey = @"keyPath";
NSString *const AFObservedObjectKey = @"object";
#endif

NSString *const AFUnboundValueKey = @"AFUnboundValue";

@implementation NSObject (AFKeyValueBindingAdditions)

- (id)valueForBinding:(NSString *)binding {
	id controller = [self controllerForBinding:binding];
	if (controller == nil) return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:AFUnboundValueKey];
	
	id value = [controller valueForKeyPath:[self keyPathForBinding:binding]];
	
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE)
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	if (transformer != nil) value = [transformer transformedValue:value];
#endif
	
	return value;
}

- (void)setValue:(id)value forBinding:(NSString *)binding {
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE)
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	if (transformer != nil && [[transformer class] allowsReverseTransformation]) value = [transformer reverseTransformedValue:value];
#endif
	
	id controller = [self controllerForBinding:binding];
	
	if (controller != nil) {
		[[self controllerForBinding:binding] setValue:value forKeyPath:[self keyPathForBinding:binding]];
		return;
	}
	
	[(id <AFKeyValueBinding>)self setInfo:[NSDictionary dictionaryWithObject:value forKey:AFUnboundValueKey] forBinding:binding];
	[self observeValueForKeyPath:nil ofObject:nil change:nil context:[(id <AFKeyValueBinding>)self contextForBinding:binding]];
}

- (id)controllerForBinding:(NSString *)binding {
	return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE)
			NSObservedObjectKey
#elif TARGET_OS_MAC && TARGET_OS_IPHONE
			AFObservedObjectKey
#endif
			];
}

- (NSString *)keyPathForBinding:(NSString *)binding {
	return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:
#if TARGET_OS_MAC && !(TARGET_OS_IPHONE)
			NSObservedKeyPathKey
#elif TARGET_OS_MAC && TARGET_OS_IPHONE
			AFObservedKeyPathKey
#endif
			];
}

#if TARGET_OS_MAC && !(TARGET_OS_IPHONE)
- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding {
	NSDictionary *bindingOptions = [[self infoForBinding:binding] objectForKey:NSOptionsKey];
	
	NSValueTransformer *valueTransformer = [bindingOptions objectForKey:NSValueTransformerBindingOption];
	return (valueTransformer != nil ? valueTransformer : [NSValueTransformer valueTransformerForName:[bindingOptions objectForKey:NSValueTransformerNameBindingOption]]);
}
#endif

@end

NSString *const AFCurrentMonthBinding = @"currentMonth";
NSString *const AFSelectionIndexPathBinding = @"selectionIndexPath";
