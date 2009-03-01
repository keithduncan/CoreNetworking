//
//  AFNetService.h
//  Bonjour
//
//  Created by Keith Duncan on 03/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CFNetwork/CFNetwork.h>

/*!
    @protocol
    @abstract    The defines the minimum required to create any service for resolution
    @discussion  NSNetService doesn't need to support copying because once discovered the name, type and service are sufficient for other classes to work with
					For example the AFNetService class below provides a KVO compliant presence dictionary that maps to the TXT record
					Another class might listen for changes to the phsh TXT entry of a Bonjour peer and update the avatar (NULL record)
*/

@protocol AFNetServiceCommon <NSObject>
@property (readonly) NSString *name;
@property (readonly) NSString *type;
@property (readonly) NSString *domain;

@property (readonly) NSString *fullName;
@end

@protocol AFNetServiceDelegate;

/*!
    @function
    @abstract   Converts a data object containing TXT record to a dictionay
    @discussion The dictionary returned by the +[NSNetService dictionaryFromTXTRecordData:] only converts the keys to UTF-8 encoded NSStrings, this function converts the data objects as UTF-8 strings too
    @param      |TXTRecordData| should be the raw NSData object as returned by -[NSNetService TXTRecordData]
    @result     A dictionary of NSString values and keys 
*/

extern NSDictionary *AFNetServiceProcessTXTRecordData(NSData *TXTRecordData);

/*!
    @class
    @abstract    A replacement for NSNetService with a KVO compliant 'presence' dictionary corresponding to the TXT record data
*/

@interface AFNetService : NSObject <AFNetServiceCommon> {
	CFNetServiceRef service;
	
	CFNetServiceMonitorRef monitor;
	CFNetServiceClientContext context;
	
	NSMutableArray *addresses;
	
	id <AFNetServiceDelegate> delegate;
	NSMutableDictionary *presence;
}

+ (id)serviceWithNetService:(NSNetService *)service;
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;

@property (readonly) NSString *domain, *type, *name;

@property (assign) id <AFNetServiceDelegate> delegate;

@property (readonly, retain) NSDictionary *presence;

- (void)startMonitoring;
- (void)stopMonitoring;

- (void)updatePresenceWithValuesForKeys:(NSDictionary *)newPresence; // Note: override point

- (void)resolveWithTimeout:(NSTimeInterval)delta;
- (void)stopResolve;

- (NSArray *)addresses;

// Note: this will stop both the monitor operation and resolve
- (void)stop;

@end

@protocol AFNetServiceDelegate <NSObject>
- (void)netServiceDidResolveAddress:(AFNetService *)service;
- (void)netService:(AFNetService *)service didNotResolveAddress:(NSString *)localizedErrorDescription;
@end
