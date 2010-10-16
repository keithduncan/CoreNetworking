//
//  AFPropertyListProtocol.h
//  AmberFoundation
//
//  Created by Keith Duncan on 11/03/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\file
 */

/*!
	\brief
	Check the plist serialisability of the object passed in.
 
	\details
	The plist objects are NSString, NSArray, NSDictionary, NSDate, NSData, NSNumber.
	In the case of NSDictionary, the keys must be NSString object mapping to another plist object.
 
	\return
	If the object is, or is wholly consituted of, plist objects.
 */
BOOL AFObjectIsPlistSerialisable(id object);

/*!
	\brief
	An <tt>NSCoding</tt> like method pair. Unlike NSCoding it is designed to produce human-readable archives.
 */
@protocol AFPropertyList <NSObject>

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation;

- (id)propertyListRepresentation;

@end

@interface NSArray (AFPropertyList) <AFPropertyList>

@end

@interface NSDictionary (AFPropertyList) <AFPropertyList>

@end

/*!
	\brief
	This function returns a property list object which combines the <tt>-propertyListRepresentation</tt>
	of |object| and the data required to reinstantiate it. The archive can be reinstantiated using
	<tt>AFPropertyListRepresenationUnarchive</tt>.
 */
extern CFPropertyListRef AFPropertyListRepresentationArchive(id <AFPropertyList> object);

/*!
	\brief
	This function unarchives a property list archive, returned from <tt>AFPropertyListRepresentationArchive()</tt>,
	back into a live object.
 */
extern id <AFPropertyList> AFPropertyListRepresentationUnarchive(CFPropertyListRef propertyListArchive);
