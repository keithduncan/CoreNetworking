//
//  CoreNetworking.h
//  Amber
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
	Core Classes
 */

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFNetworkFunctions.h"
#import "CoreNetworking/AFNetworkConstants.h"

#import "CoreNetworking/AFNetworkLayer.h"
#import "CoreNetworking/AFTransportLayer.h"
#import "CoreNetworking/AFConnectionLayer.h"

#import "CoreNetworking/AFNetworkSocket.h"
#import "CoreNetworking/AFNetworkTransport.h"
#import "CoreNetworking/AFNetworkConnection.h"

#import "CoreNetworking/AFPacket.h"
#import "CoreNetworking/AFPacketRead.h"
#import "CoreNetworking/AFPacketWrite.h"
#import "CoreNetworking/AFPacketQueue.h"

#import "CoreNetworking/AFNetworkServer.h"
#import "CoreNetworking/AFNetworkPool.h"

#import "CoreNetworking/AFNetService.h"
#import "CoreNetworking/AFServiceDiscoveryRunLoopSource.h"

/*
	Network Protocols
 */

/* HTTP */

#import "CoreNetworking/AFHTTPConstants.h"
#import "CoreNetworking/AFHTTPClient.h"
#import "CoreNetworking/AFHTTPConnection.h"
#import "CoreNetworking/AFHTTPTransaction.h"

/* XMPP */

#import "CoreNetworking/AFXMLElementPacket.h"

// Not Yet Public

/* SMTP */

// Not Yet Implemented

/* IMAP */

// Not Yet Implemented
