//
//  AFLibrary.h
//  Amber
//
//  Created by Keith Duncan on 05/03/2008.
//  Copyright 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AmberFoundation/NSBundle+Additions.h"

@class AFLibrary, AFSourceNode;

@protocol AFLibraryDelegate <AFBundleDiscovery>

- (NSURL *)libraryRequestLocationFromUser:(AFLibrary *)library;

 @optional

/*!
	@brief
	Root children are NEVER selectable and you won't be queried.
 */
- (BOOL)library:(AFLibrary *)library isObjectSelectable:(id)object;

@end

/*!
    @brief
	This is an abstract class for loading XML library representations, iTunes initially, perhaps iPhoto or another custom store could be added.
*/
@interface AFLibrary : NSObject {
 @private
	id <AFLibraryDelegate> delegate;
	
	NSURL *_location;
	BOOL _shouldRequest;
	
	BOOL _loaded;
}

@property (assign) id <AFLibraryDelegate> delegate;

/*!
	@brief
	Designated Initialiser.
 
	@param |shouldRequest|
	Pass YES to trigger a user request when loading the library, bypassing the search paths.
 */
- (id)initWithLocation:(NSURL *)location shouldRequest:(BOOL)shouldRequest;

/*!
	@brief
	This property is observable.
 */
@property (readonly, copy) NSURL *location;

/*
	@brief
	This property is observable.
 */
@property (readonly, assign, getter=isLoaded) BOOL loaded;

/*!
	@brief
	This implementation doesn't load anything, it attempts to locate the library - your implementation should call super.
	Upon return from this method the |location| property will represent the first library file found.
 */
- (BOOL)loadAndReturnError:(NSError **)error;

/*
	@brief
	This is for binding an NSTreeController to the library's source tree.
 */
@property (readonly, retain) AFSourceNode *rootNode;

/*!
 
 */
- (NSMenu *)sourceMenu DEPRECATED_ATTRIBUTE;

@end

/*!
	@brief
	Library subclasses MUST conform to this protocol.
 */
@protocol AFLibraryDiscovery <NSObject>

/*!
	@brief
	This string should be suitable for displaying in the interface.
 */
- (NSString *)localisedName;

/*!
	@brief
	If your library has a default, expected location, return it here.
 */
- (NSURL *)expectedURL;

 @optional

/*!
	@brief
	Your subclass my reside in other default locations, return the URL for each in priority order here.
 */
- (NSArray *)additionalSearchURLs;

@end
