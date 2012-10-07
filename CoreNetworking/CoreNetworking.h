//
//  CoreNetworking.h
//  Amber
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
	Core Networking
 */

#import "CoreNetworking/AFNetworkLayer.h"
#import "CoreNetworking/AFNetworkTransportLayer.h"
#import "CoreNetworking/AFNetworkConnectionLayer.h"

#import "CoreNetworking/AFNetworkSocket.h"
#import "CoreNetworking/AFNetworkTransport.h"
#import "CoreNetworking/AFNetworkStream.h"
#import "CoreNetworking/AFNetworkConnection.h"

#import "CoreNetworking/AFNetworkPacketQueue.h"
#import "CoreNetworking/AFNetworkPacket.h"

#import "CoreNetworking/AFNetworkPacketRead.h"
#import "CoreNetworking/AFNetworkPacketReadToWriteStream.h"
#import "CoreNetworking/AFNetworkPacketWrite.h"
#import "CoreNetworking/AFNetworkPacketWriteFromReadStream.h"
#import "CoreNetworking/AFNetworkPacketClose.h"

#import "CoreNetworking/AFNetworkServer.h"
#import "CoreNetworking/AFNetworkPool.h"
#import "CoreNetworking/AFNetworkSchedulerProxy.h"

#import "CoreNetworking/AFNetworkServiceScope.h"
#import "CoreNetworking/AFNetworkServiceBrowser.h"
#import "CoreNetworking/AFNetworkServicePublisher.h"
#import "CoreNetworking/AFNetworkServiceResolver.h"
#import "CoreNetworking/AFNetworkServiceSource.h"
#import "CoreNetworking/AFNetworkService-Functions.h"
#import "CoreNetworking/AFNetworkService-Constants.h"

#import "CoreNetworking/AFNetwork-Types.h"
#import "CoreNetworking/AFNetwork-Functions.h"
#import "CoreNetworking/AFNetwork-Constants.h"

/*
	Categories
 */

#import "CoreNetworking/NSDictionary+AFNetworkAdditions.h"
#import "CoreNetworking/NSURLRequest+AFNetworkAdditions.h"

/*
	Network Protocols
 */

/* HTTP */

#import "CoreNetworking/AFHTTPMessage.h"
#import "CoreNetworking/AFHTTPMessageAccept.h"

#import "CoreNetworking/AFHTTPMessagePacket.h"
#import "CoreNetworking/AFHTTPHeadersPacket.h"
#import "CoreNetworking/AFHTTPBodyPacket.h"

#import "CoreNetworking/AFHTTPConnection.h"
#import "CoreNetworking/AFHTTPClient.h"

#import "CoreNetworking/AFHTTPTransaction.h"

#import "CoreNetworking/AFHTTPServer.h"

/* FTP */

/* XMPP */

#import "CoreNetworking/AFXMLElementPacket.h"

// See <http://code.google.com/p/objectivexmpp/> for implementation

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

/* AFP */
// Not Yet Implememted

/* SVN */
// Not Yet Implememted

/* Git */
// Not Yet Implememted

/*
	MIME Documents
 */

#import "CoreNetworking/AFNetworkFormDocument.h"
