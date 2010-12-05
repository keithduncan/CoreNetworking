//
//  AFNetService.h
//  Amber
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@protocol AFNetworkServiceDelegate;

/*!
	\brief
	The defines the minimum required to create a service suitable for resolution.
	
	\details
	<tt>NSNetService</tt> doesn't need to support copying because once discovered, the name, type and service are sufficient to create other classes.
	For example the <tt>AFNetService</tt> class below provides a KVO compliant presence dictionary that maps to the TXT record.
	Important: if a class is passed an (id <AFNetServiceCommon>) to create a new service, you <b>must</b> use <tt>-valueForKey:</tt> allowing for a dictionary (or other serialized reference) to be used in place of an actual service object.
 */
@protocol AFNetworkServiceCommon <NSObject>

/*!
	\brief
	This is the expanded form of <tt>-initWithNetService:</tt> taking explict arguments.
 */
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;

/*!
	\brief
	The uniquing properties of a DNS-SD registration.
 */
@property (readonly) NSString *name, *type, *domain;

/*!
	\brief
	This method is optional, though it should simply be a concatenation of the <tt>name</tt>, <tt>type</tt> and <tt>domain</tt> suitable for resolution.
 */
@property (readonly) NSString *fullName;

/*!
	\brief
	Implementors <b>must</b> use <tt>-valueForKey:</tt> to extract the <tt>name<tt>, <tt>type</tt> and <tt>domain</tt> as documented in the <tt>AFNetServiceCommon</tt> description.
 */
- (id)initWithNetService:(id <AFNetworkServiceCommon>)service;

@end


/*!
	\brief
	Convert an <tt>NSData</tt> object containing TXT record data into an <tt>NSDictionay</tt>.
	
	\details
	The dictionary returned by the <tt>+[NSNetService dictionaryFromTXTRecordData:]</tt> only converts the keys to UTF-8 encoded <tt>NSString</tt> objects, this function converts the data objects as UTF-8 strings too.
	
	\param TXTRecordData
	The raw NSData object as returned by <tt>-[NSNetService TXTRecordData]</tt>.
	
	\return
	An <tt>NSDictionary</tt> object of <tt>NSString</tt> key-value pairs.
*/
extern NSDictionary *AFNetworkServicePropertyDictionaryFromTXTRecordData(NSData *TXTRecordData);

/*!
	\brief
	Converts a key-value string pair dictionary into a data object that can be set as a TXT record.
 
	\details
	The dictionary returned by the <tt>+[NSNetService dataFromTXTRecordDictionary:]</tt> only accepts a dictionary with data objects, this function converts the data objects as UTF-8 strings into data objects for you.
 */
extern NSData *AFNetworkServiceTXTRecordDataFromPropertyDictionary(NSDictionary *TXTRecordDictionary);

/*
 
 */

extern NSString *const AFNetworkServicePresenceKey;

/*!
    \brief
	A replacement for a resolvable <tt>NSNetService</tt> with a KVO compliant 'presence' dictionary corresponding to the TXT record data.
	
	\details
	The initialisers for this class are in <tt>AFNetServiceCommon</tt>.
	This cannot currently be used for publishing a service, the NSNetService API is generally sufficient for that.
*/
@interface AFNetworkService : NSObject <AFNetworkServiceCommon> {
 @private
	__strong CFNetServiceRef _service;
	__strong CFNetServiceMonitorRef _monitor;
	
	id <AFNetworkServiceDelegate> delegate;
	
	NSDictionary *presence;
}

/*!
	\brief
	The delegate is called when resolution discovers an address or fails to.
 */
@property (assign) id <AFNetworkServiceDelegate> delegate;

/*!
	\brief
	Start monitoring the TXT record of the service.
	Interested parties will be notified using the KVO compliant <tt>persence</tt> <tt>NSDictionary</tt> property.
 */
- (void)startMonitoring;

/*!
	\brief
	Stop monitoring the TXT record of the service.
 */
- (void)stopMonitoring;

/*!
	\brief
	The TXT record decoded into key=value string pairs.
 */
@property (readonly, retain) NSDictionary *presence;

/*!
	\brief
	Called when a new TXT record has been received.
	
	\details
	If one of the TXT dicrionary keys has a knock-on effect, like the phsh key for P2P XMPP documented in XEP-0174, you can detect that in an overridden implementation.
 */
- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence;

/*!
	\brief
	Starts lookup for the addresses of the service.
 */
- (void)resolveWithTimeout:(NSTimeInterval)delta;

/*!
	\brief
	Stops lookup for the addresses of the service.
 */
- (void)stopResolve;

/*!
	\brief
	This returns an array of NSData objects wrapping a (struct sockaddr) suitable for connecting to.
 */
@property (readonly) NSArray *addresses;

/*!
    \brief  
	This will stop both a monitor and resolve operation.
*/
- (void)stop;

@end


@protocol AFNetworkServiceDelegate <NSObject>

/*!
	\brief
	
 */
- (void)networkServiceDidResolveAddress:(AFNetworkService *)service;

/*!
	\brief
	
 */
- (void)networkService:(AFNetworkService *)service didNotResolveAddress:(NSError *)error;

@end
