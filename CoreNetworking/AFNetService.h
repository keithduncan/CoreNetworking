//
//  AFNetService.h
//  Amber
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

/*!
	@brief
	The defines the minimum required to create a service suitable for resolution
 
	@detail
	NSNetService doesn't need to support copying because once discovered, the name, type and service are sufficient to create other classes
	For example the AFNetService class below provides a KVO compliant presence dictionary that maps to the TXT record
	Another class might listen for changes to the phsh TXT entry of a Bonjour peer and update the avatar (found in the NULL record)
	Important: if a class is passed an (id <AFNetServiceCommon) to create a new service, you MUST use <tt>-valueForKey:</tt> allowing for a dictionary (or other serialized reference) to be used in place of an actual service object.
 */
@protocol AFNetServiceCommon <NSObject>

@property (readonly) NSString *name, *type, *domain;

/*!
	@brief
	This method MUST use <tt>-valueForKey:</tt> to extract the |name|, |type| and |domain| as documented in the <tt>AFNetServiceCommon</tt> description.
 */
- (id)initWithNetService:(id <AFNetServiceCommon>)service;

 @optional

/*!
	@brief
	This method is optional, though it should simply be a concatenation of the |name|, |type| and |domain| suitable for resolution.
 */
- (NSString *)fullName;

/*!
	@brief
	This is the expanded form of <tt>-initWithNetService:</tt> taking explict arguments.
 */
- (id)initWithName:(NSString *)name type:(NSString *)type domain:(NSString *)domain;

@end

/*!
	@brief
	Converts a data object containing TXT record to a dictionay.
 
	@detail
	The dictionary returned by the <tt>+[NSNetService dictionaryFromTXTRecordData:]</tt> only converts the keys to UTF-8 encoded NSStrings, this function converts the data objects as UTF-8 strings too.
 
	@param
	|TXTRecordData| should be the raw NSData object as returned by <tt>-[NSNetService TXTRecordData]</tt>.
 
	@result
	A dictionary of NSString key-value pairs.
*/
extern NSDictionary *AFNetServicePropertyDictionaryFromTXTRecordData(NSData *TXTRecordData);

/*!
	@brief
	Converts a key-value string pair dictionary into a data object that can be set as a TXT record.
 
	@detail
	The dictionary returned by the <tt>+[NSNetService dataFromTXTRecordDictionary:]</tt> only accepts a dictionary with data objects, this function converts the data objects as UTF-8 strings into data objects for you.
 */
extern NSData *AFNetServiceTXTRecordDataFromPropertyDictionary(NSDictionary *TXTRecordDictionary);

@protocol AFNetServiceDelegate;

/*!
    @brief
	A replacement for a resolvable NSNetService with a KVO compliant 'presence' dictionary corresponding to the TXT record data
 
	@detail
	The initialisers for this class are in <tt>AFNetServiceCommon</tt>.
	This cannot currently be used for publishing a service, the NSNetService API is generally sufficient for that.
*/
@interface AFNetService : NSObject <AFNetServiceCommon> {
	__strong CFNetServiceRef _service;
	__strong CFNetServiceMonitorRef _monitor;
	
	id <AFNetServiceDelegate> delegate;
	NSDictionary *presence;
}


@property (assign) id <AFNetServiceDelegate> delegate;

@property (readonly, retain) NSDictionary *presence;

/*!
	@brief
	This starts observing the TXT record of the service. Interested parties will be notified using the KVO compliant |persence| dictionary property
 */
- (void)startMonitoring;

- (void)stopMonitoring;

/*!
	@brief
	If one of the TXT dicrionary keys has a knock-on effect, like the phsh key for P2P XMPP documented in XEP-0174, you can detect that in an overridden implementation.
	This will serve as a useful override point for protocol specific subclasses.
 */
- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence;

- (void)resolveWithTimeout:(NSTimeInterval)delta;

- (void)stopResolve;

/*!
	@brief
	This returns an array of NSData objects wrapping a (struct sockaddr) suitable for connecting to.
 */
- (NSArray *)addresses;

/*!
    @brief  
	This will stop both a monitor and resolve operation.
*/
- (void)stop;

@end


@protocol AFNetServiceDelegate <NSObject>

- (void)netServiceDidResolveAddress:(AFNetService *)service;
- (void)netService:(AFNetService *)service didNotResolveAddress:(NSError *)error;

@end


@interface NSNetService (AFAdditions) <AFNetServiceCommon>

@end
