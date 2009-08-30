//
//  AFLibrary.m
//  Amber
//
//  Created by Keith Duncan on 05/03/2008.
//  Copyright 2008 thirty-three. All rights reserved.
//

#import "AFLibrary.h"

#import "AFSourceNode.h"

#import "NSString+Additions.h"
#import "NSFileManager+Additions.h"
#import "AFMacro.h"

@interface AFLibrary ()
@property (readwrite, copy) NSURL *location;
@property (readwrite, assign) BOOL shouldRequest;
@property (readwrite, assign, getter=isLoaded) BOOL loaded;
@end

@implementation AFLibrary

@synthesize delegate;
@synthesize location=_location;
@synthesize shouldRequest=_shouldRequest;
@synthesize loaded=_loaded;
@dynamic rootNode;

- (id)initWithLocation:(NSURL *)location shouldRequest:(BOOL)shouldRequest {
	self = [self init];
	if (self == nil) return nil;
	
	_location = [location copy];
	_shouldRequest = shouldRequest;
	
	return self;
}

- (void)dealloc {
	[_location release];
	
	[super dealloc];
}

- (NSBundle *)bundle {
	return [self.delegate bundle];
}

- (BOOL)loadAndReturnError:(NSError **)errorRef {
	if (self.loaded) return YES;
	
	if (self.shouldRequest) {
		self.location = [self.delegate libraryRequestLocationFromUser:self];
	} else {
		NSMutableArray *searchPaths = [NSMutableArray array];
		
		if (self.location != nil) [searchPaths addObject:self.location];
		if ([(id)self expectedURL] != nil) [searchPaths addObject:[(id)self expectedURL]];
		if ([self respondsToSelector:@selector(additionalSearchURLs)])
			[searchPaths addObjectsFromArray:[(id)self additionalSearchURLs]];
		
		for (NSURL *currentLocation in searchPaths) {
			if (!AFFileExistsAtLocation(currentLocation)) continue;
			self.location = currentLocation;
			break;
		}
	}
	
	if (!AFFileExistsAtLocation(self.location)) {
		if (errorRef != NULL)
			*errorRef = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not locate library.", NSLocalizedDescriptionKey, nil]];
		
		return NO;
	}
	
	return YES;
}

- (NSMenuItem *)_createMenuItemForNode:(AFSourceNode *)node NS_RETURNS_RETAINED {
	NSMenuItem *nodeMenuItem = [[NSMenuItem alloc] init];
	
	[nodeMenuItem setImage:node.image];
	[nodeMenuItem setTitle:[node.name stringByAppendingElipsisAfterCharacters:30]];
	
	[nodeMenuItem setEnabled:([self.delegate respondsToSelector:@selector(library:isObjectSelectable:)] ? [self.delegate library:self isObjectSelectable:node] : YES)];
	[nodeMenuItem setIndentationLevel:([[node indexPath] length] - 1)];
	
	return nodeMenuItem;
}

- (void)_addChildNodes:(AFSourceNode *)node to:(NSMenu *)menu {
	for (AFSourceNode *currentNode in [node childNodes]) {
		NSMenuItem *currentNodeMenuItem = [self _createMenuItemForNode:currentNode];
		
		[menu addItem:currentNodeMenuItem];
		[self _addChildNodes:currentNode to:menu];
		
		[currentNodeMenuItem release];
	}
}

- (NSMenu *)sourceMenu {
	NSMenu *sourceMenu = [[NSMenu alloc] init];
	[sourceMenu setAutoenablesItems:NO];
	
	for (AFSourceNode *rootChild in [self.rootNode childNodes]) {
		[self _addChildNodes:rootChild to:sourceMenu];
		
		if (rootChild != [[self.rootNode childNodes] lastObject])
			[sourceMenu addItem:[NSMenuItem separatorItem]];
	}
	
	return [sourceMenu autorelease];
}

@end
