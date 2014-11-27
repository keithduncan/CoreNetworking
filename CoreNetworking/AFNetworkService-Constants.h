//
//  AFNetworkService-Constants.h
//  CoreNetworking
//
//  Created by Keith Duncan on 13/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

#import <dns_sd.h>

typedef AFNETWORK_ENUM(NSUInteger, AFNetworkDomainRecordType) {
	AFNetworkDomainRecordTypeA		= kDNSServiceType_A,
	AFNetworkDomainRecordTypeNS		= kDNSServiceType_NS,
	AFNetworkDomainRecordTypeCNAME	= kDNSServiceType_CNAME,
	AFNetworkDomainRecordTypeSOA	= kDNSServiceType_SOA,
	AFNetworkDomainRecordTypeNULL	= kDNSServiceType_NULL,
	AFNetworkDomainRecordTypePTR	= kDNSServiceType_PTR,
	AFNetworkDomainRecordTypeMX		= kDNSServiceType_MX,
	AFNetworkDomainRecordTypeTXT	= kDNSServiceType_TXT,
	AFNetworkDomainRecordTypeAAAA	= kDNSServiceType_AAAA,
	AFNetworkDomainRecordTypeSRV	= kDNSServiceType_SRV,
};
