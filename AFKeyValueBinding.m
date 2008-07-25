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

- (void *)contextForBinding:(NSString *)binding {
	return nil;
}

- (id)valueForBinding:(NSString *)binding {
	id controller = [self controllerForBinding:binding];
	id value = (controller == nil ? [[self infoForBinding:binding] objectForKey:AFUnboundValueKey] : [controller valueForKeyPath:[self keyPathForBinding:binding]]);
	
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	return (transformer == nil ? value : [transformer transformedValue:value]);
}

- (void)setValue:(id)value forBinding:(NSString *)binding {
	NSValueTransformer *transformer = [self valueTransformerForBinding:binding];
	if (transformer != nil && [[transformer class] allowsReverseTransformation]) value = [transformer reverseTransformedValue:value];
	
	if ([value isEqual:[self valueForBinding:binding]]) return;
	
	id controller = [self controllerForBinding:binding];
	
	if (controller == nil) {
		[[self bindingInfoContainer] setValue:(value != nil ? [NSDictionary dictionaryWithObject:value forKey:AFUnboundValueKey] : nil) forKey:binding];
		[self observeValueForKeyPath:binding ofObject:nil change:nil context:[self contextForBinding:binding]];
	} else [controller setValue:value forKeyPath:[self keyPathForBinding:binding]];
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
