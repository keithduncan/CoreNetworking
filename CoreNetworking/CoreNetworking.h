//
//  CoreNetworking.h
//  Amber
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AmberFoundation/AmberFoundation.h"

/*
	Core Networking
 */

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFNetworkFunctions.h"
#import "CoreNetworking/AFNetworkConstants.h"

#import "CoreNetworking/AFNetworkLayer.h"
#import "CoreNetworking/AFTransportLayer.h"
#import "CoreNetworking/AFConnectionLayer.h"

#import "CoreNetworking/AFNetworkSocket.h"
#import "CoreNetworking/AFNetworkTransport.h"
#import "CoreNetworking/AFNetworkStream.h"
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

#import "CoreNetworking/AFHTTPMessage.h"
#import "CoreNetworking/NSURLRequest+AFHTTPAdditions.h"

#import "CoreNetworking/AFHTTPMessagePacket.h"
#import "CoreNetworking/AFHTTPHeadersPacket.h"
#import "CoreNetworking/AFHTTPBodyPacket.h"

#import "CoreNetworking/AFHTTPConnection.h"
#import "CoreNetworking/AFHTTPClient.h"

#import "CoreNetworking/AFHTTPTransaction.h"

#import "CoreNetworking/AFHTTPServer.h"

/* XMPP */

#import "CoreNetworking/AFXMLElementPacket.h"

// See http://code.google.com/p/objectivexmpp/ for implementation.

/* AMQP */
// Not Yet Implemented

/* RTSP */
// Not Yet Implemented

/* SMTP */
// Not Yet Implemented

/* IMAP */
// Not Yet Implemented

/* MySQL */
// Not Yet Implemented

/* LDAP */
// Not Yet Implemented

/*
	MIME Documents
 */

#import "CoreNetworking/AFNetworkFormDocument.h"
