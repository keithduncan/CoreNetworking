//
//  AFNetService.h
//  Bonjour
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@protocol
	@abstract    The defines the minimum required to create a service suitable for resolution
	@discussion  NSNetService doesn't need to support copying because once discovered, the name, type and service are sufficient to create other classes
					For example the AFNetService class below provides a KVO compliant presence dictionary that maps to the TXT record
					Another class might listen for changes to the phsh TXT entry of a Bonjour peer and update the avatar (found in the NULL record)
 
					Important: if a class is passed an (id <AFNetServiceCommon) to create a new service, you MUST use <tt>-valueForKey:</tt> allowing for a dictionary (or other serialized reference) to be used in place of an actual service object
 */
@protocol AFNetServiceCommon <NSObject>

/*!
	@property
 */
@property (readonly) NSString *name, *type, *domain;

/*!
	@method
	@abstract	This method uses <tt>-valueForKey:</tt> to extract the |name|, |type| and |domain| as documented.
 */
- (id)initWithNetService:(id <AFNetServiceCommon>)service;

 @optional

/*!
	@method
	@abstract	This method is optional, it should simply be a concatenation of the |name|, |type| and |domain| suitable for resolution.
 */
- (NSString *)fullName;

/*!
	@method
	@abstract	This is the expanded form of <tt>-initWithNetService:</tt> taking explict arguments.
 */
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;

@end

/*!
	@function
	@abstract   Converts a data object containing TXT record to a dictionay
	@discussion The dictionary returned by the <tt>+[NSNetService dictionaryFromTXTRecordData:]</tt> only converts the keys to UTF-8 encoded NSStrings, this function converts the data objects as UTF-8 strings too
	@param      |TXTRecordData| should be the raw NSData object as returned by <tt>-[NSNetService TXTRecordData]</tt>
	@result     A dictionary of NSString values and keys 
*/
extern NSDictionary *AFNetServiceProcessTXTRecordData(NSData *TXTRecordData);

@protocol AFNetServiceDelegate;

/*!
    @class
    @abstract	A replacement for a resolvable NSNetService with a KVO compliant 'presence' dictionary corresponding to the TXT record data
	@discussion	The initialisers for this class are in <tt>AFNetServiceCommon</tt>.
				This cannot currently be used for publishing a service, the NSNetService API is generally sufficient for that.
*/
@interface AFNetService : NSObject <AFNetServiceCommon> {
	CFNetServiceRef service;	
	CFNetServiceMonitorRef monitor;
	
	id <AFNetServiceDelegate> delegate;
	NSMutableDictionary *presence;
}

/*!
	@property
 */
@property (assign) id <AFNetServiceDelegate> delegate;

/*!
	@property
 */
@property (readonly, retain) NSDictionary *presence;

/*!
	@method
	@abstract	This starts observing the TXT record of the service. Interested parties will be notified using the KVO compliant |persence| dictionary property
 */
- (void)startMonitoring;

/*!
	@method
 */
- (void)stopMonitoring;

/*!
	@method
	@abstract	If one of the TXT dicrionary keys has a knock-on effect, like the phsh key for P2P XMPP documented in XEP-0174, you can detect that in an overridden implementation
 */
- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence; // Note: override point

/*!
	@method
 */
- (void)resolveWithTimeout:(NSTimeInterval)delta;

/*!
	@method
 */
- (void)stopResolve;

/*!
	@method
	@abstract	This returns an array of NSData objects wrapping a (struct sockaddr) suitable for connecting to.
 */
- (NSArray *)addresses;

/*!
    @method     
    @abstract   This will stop both a monitor and resolve operation
*/
- (void)stop;

@end

/*!
	@protocol
 */
@protocol AFNetServiceDelegate <NSObject>

/*!
	@method
 */
- (void)netServiceDidResolveAddress:(AFNetService *)service;

/*!
	@method
 */
- (void)netService:(AFNetService *)service didNotResolveAddress:(NSError *)error;

@end

/*!
	@category
 */
@interface NSNetService (AFAdditions) <AFNetServiceCommon>

@end
