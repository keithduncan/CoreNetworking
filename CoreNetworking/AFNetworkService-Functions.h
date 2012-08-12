//
//  AFNetworkService-Functions.h
//  CoreNetworking
//
//  Created by Keith Duncan on 22/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Convert a dictionary with NSString object keys to NSString object values.
	If the dictionary doesn't conform to this format, an exception is thrown.
	
	\return
	Data suitable for publishing as an AFNetworkServiceRecordTypeTXT record.
 */
AFNETWORK_EXTERN NSData *AFNetworkServiceTXTRecordDataFromPropertyDictionary(NSDictionary *TXTRecordDictionary);

/*!
	\brief
	Convert TXT record data where the keys are ASCII strings and the values are UTF8 strings.
	If a value isn't a UTF8 string, it isn't included in the returned dictionary.
 */
AFNETWORK_EXTERN NSDictionary *AFNetworkServicePropertyDictionaryFromTXTRecordData(NSData *TXTRecordData);
