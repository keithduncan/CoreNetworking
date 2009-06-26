//
//  AFKeyValueBinding.m
//  Amber
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFKeyValueBinding.h"

#if TARGET_OS_IPHONE

NSString *AFObservedKeyPathKey = @"keyPath";
NSString *AFObservedObjectKey = @"object";
NSString *AFOptionsKey = @"options";

NSString *AFValueTransformerBindingOption = @"valueTransformer";
NSString *AFValueTransformerNameBindingOption = @"valueTransformerName";

#endif

NSString *const AFUnboundValueKey = @"AFUnboundValue";

@implementation NSObject (AFKeyValueBindingAdditions)

- (id)valueForBinding:(NSString *)binding {
	id controller = [self controllerForBinding:binding];
	if (controller == nil) return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:AFUnboundValueKey];
	
	id value = [controller valueForKeyPath:[self keyPathForBinding:binding]];
	
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	if (transformer != nil) value = [transformer transformedValue:value];
	
	return value;
}

- (void)setValue:(id)value forBinding:(NSString *)binding {
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	if (transformer != nil && [[transformer class] allowsReverseTransformation]) value = [transformer reverseTransformedValue:value];
	
	id controller = [self controllerForBinding:binding];
	
	if (controller != nil) {
		[[self controllerForBinding:binding] setValue:value forKeyPath:[self keyPathForBinding:binding]];
		return;
	}
	
	[(id <AFKeyValueBinding>)self setInfo:[NSDictionary dictionaryWithObject:value forKey:AFUnboundValueKey] forBinding:binding];
	[self observeValueForKeyPath:nil ofObject:nil change:nil context:[(id <AFKeyValueBinding>)self contextForBinding:binding]];
}

- (id)controllerForBinding:(NSString *)binding {
	return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:AFObservedObjectKey];
}

- (NSString *)keyPathForBinding:(NSString *)binding {
	return [[(id <AFKeyValueBinding>)self infoForBinding:binding] objectForKey:AFObservedKeyPathKey];
}

- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding {
	NSDictionary *bindingOptions = [[self infoForBinding:binding] objectForKey:AFOptionsKey];
	
	NSValueTransformer *valueTransformer = [bindingOptions objectForKey:AFValueTransformerBindingOption];
	return (valueTransformer != nil ? valueTransformer : [NSValueTransformer valueTransformerForName:[bindingOptions objectForKey:AFValueTransformerNameBindingOption]]);
}

@end

#if TARGET_OS_IPHONE

NSString *const AFContentObject = @"contentObject";

#endif

NSString *const AFCurrentMonthBinding = @"currentMonth";
NSString *const AFSelectionIndexPathBinding = @"selectionIndexPath";
