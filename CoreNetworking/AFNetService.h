//
//  AFNetService.h
//  Bonjour
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

/*!
    @protocol
    @abstract    The defines the minimum required to create any service for resolution
    @discussion  NSNetService doesn't need to support copying because once discovered, the name, type and service are sufficient to create other classes
					For example the AFNetService class below provides a KVO compliant presence dictionary that maps to the TXT record
					Another class might listen for changes to the phsh TXT entry of a Bonjour peer and update the avatar (found in the NULL record)
*/

@protocol AFNetServiceCommon <NSObject>
@property (readonly) NSString *name, *type, *domain;
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;
@end

/*!
    @function
    @abstract   Converts a data object containing TXT record to a dictionay
    @discussion The dictionary returned by the +[NSNetService dictionaryFromTXTRecordData:] only converts the keys to UTF-8 encoded NSStrings, this function converts the data objects as UTF-8 strings too
    @param      |TXTRecordData| should be the raw NSData object as returned by -[NSNetService TXTRecordData]
    @result     A dictionary of NSString values and keys 
*/

extern NSDictionary *AFNetServiceProcessTXTRecordData(NSData *TXTRecordData);

@protocol AFNetServiceDelegate;

/*!
    @class
    @abstract	A replacement for a resolvable NSNetService with a KVO compliant 'presence' dictionary corresponding to the TXT record data
	@discussion	This cannot currently be used for publishing a service, the NSNetService API is generally sufficient for that
*/

@interface AFNetService : NSObject <AFNetServiceCommon> {
	CFNetServiceRef service;	
	CFNetServiceMonitorRef monitor;
	
	CFNetServiceClientContext context;
	
	id <AFNetServiceDelegate> delegate;
	NSMutableDictionary *presence;
}

/*!
    @method     
    @abstract   This uses -valueForKey: to access the properties in AFNetServiceCommon and passes them to the initialiser
	@discussion	Because this uses -valueForKey: you can pass in an NSNetService, or a model object containing previously saved properties for example
*/

+ (id)serviceWith:(id <AFNetServiceCommon>)service;

@property (assign) id <AFNetServiceDelegate> delegate;

@property (readonly, retain) NSDictionary *presence;

- (void)startMonitoring;
- (void)stopMonitoring;

- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence; // Note: override point

- (void)resolveWithTimeout:(NSTimeInterval)delta;
- (void)stopResolve;

- (NSArray *)addresses;

/*!
    @method     
    @abstract   This will stop both a monitor and resolve operation
*/

- (void)stop;

@end

@protocol AFNetServiceDelegate <NSObject>
- (void)netServiceDidResolveAddress:(AFNetService *)service;
- (void)netService:(AFNetService *)service didNotResolveAddress:(NSString *)localizedErrorDescription;
@end
