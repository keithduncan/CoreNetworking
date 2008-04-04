//
//  NSXMLElement+Additions.m
//  TimelineUpdates
//
//  Created by Keith Duncan on 22/11/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSXMLElement+Additions.h"

#import "KDCollection.h"
#import "NSString+Additions.h"

@implementation NSXMLElement (Additions)

NSXMLNode *NodeForKey(NSXMLElement *element, NSString *key) {
	NSArray *elements = [element elementsForName:key];
	
	if ([elements count] == 0) return nil;
	else if ([elements count] > 1) {
		[NSException raise:NSInternalInconsistencyException format:@"ElementForKey(), the element %@ contains %d %@ tags.", element, [elements count], key];
		return nil;
	}
	
	return [elements objectAtIndex:0];
}

- (NSXMLNode *)nodeForKeyPath:(NSString *)keyPath {	
	NSXMLNode *currentElement = self;
	for (NSString *currentKey in [keyPath keyPathComponents])
		currentElement = NodeForKey((NSXMLElement *)currentElement, currentKey);
	
	return currentElement;
}

- (void)setNode:(NSXMLNode *)newNode forKeyPath:(NSString *)keyPath {
	NSArray *keyPathComponents = [keyPath keyPathComponents];
	NSXMLElement *currentElement = (NSXMLElement *)[self nodeForKeyPath:[keyPathComponents objectAtIndex:0]];
	
	if ([keyPathComponents count] > 1) [currentElement setNode:newNode forKeyPath:[[keyPathComponents subarrayFromIndex:1] componentsJoinedByString:@"."]];
	else {
		NSXMLNode *existingElement = [currentElement nodeForKeyPath:keyPath];
		
		if (existingElement == nil) [currentElement addChild:newNode];
		else [currentElement replaceChildAtIndex:[existingElement index] withNode:newNode];
	}
}

@end
