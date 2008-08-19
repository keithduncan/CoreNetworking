//
//  AFKeyValueBinding.m
//  Shared Source
//
//  Created by Keith Duncan on 12/08/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AFKeyValueBinding.h"

NSString *const AFUnboundValueKey = @"AFUnboundValue";

@implementation NSObject (AFKeyValueBindingAdditions)

- (id)valueForBinding:(NSString *)binding {
	id controller = [self controllerForBinding:binding];
	if (controller == nil) return [[self infoForBinding:binding] objectForKey:AFUnboundValueKey];
	
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
	return [[self infoForBinding:binding] objectForKey:NSObservedObjectKey];
}

- (NSString *)keyPathForBinding:(NSString *)binding {
	return [[self infoForBinding:binding] objectForKey:NSObservedKeyPathKey];
}

- (NSValueTransformer *)valueTransformerForBinding:(NSString *)binding {
	NSDictionary *bindingOptions = [[self infoForBinding:binding] objectForKey:NSOptionsKey];
	
	NSValueTransformer *valueTransformer = [bindingOptions objectForKey:NSValueTransformerBindingOption];
	return (valueTransformer != nil ? valueTransformer : [NSValueTransformer valueTransformerForName:[bindingOptions objectForKey:NSValueTransformerNameBindingOption]]);
}

@end

NSString *const AFCurrentMonthBinding = @"currentMonth";
NSString *const AFSelectionIndexPathBinding = @"selectionIndexPath";
