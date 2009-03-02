//
//  AFSocketStream
//
//	Based on AsyncSocket
//  Renamed to AFSocketStream, API changed, and included in Core Networking by Keith Duncan
//  Original host http://code.google.com/p/cocoaasyncsocket/
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFSocketStreamDataDelegate;
@protocol AFSocketStreamControlDelegate;

enum {
	AFSocketStreamNoError = 0,
	AFSocketStreamCanceledError,		// onSocketWillConnect: returned NO.
	AFSocketStreamReadMaxedOutError,    // Reached set maxLength without completing
	AFSocketStreamReadTimeoutError,
	AFSocketStreamWriteTimeoutError
};
typedef NSUInteger AFSocketStreamsError;

extern NSString *const AFSocketStreamErrorDomain;

/*!
    @class
    @abstract    An extention of the CFSocketStream API
    @discussion  This class is a mix of two primary patterns. Internally, it acts an adaptor and a bridge between the CFSocket and CFStream API. Externally, it bridges CFHost and CFSocket.
*/

@interface AFSocketStream : NSObject <AFConnectionLayer> {
	id _delegate;
	NSUInteger _flags;
	
#if 1
	/*
		These are only needed for a host socket
	 */
	
	__strong CFSocketRef _socket;
	
	__strong CFRunLoopRef _runLoop;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
#endif
	
#if 1
	SInt32 _port;
	__strong CFHostRef _host;
	
	/*
		These are only needed for a connect socket
	 */
	__strong CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	id _currentReadPacket;
	NSTimer *readTimer;
	
	NSMutableData *partialReadBuffer;
	
	__strong CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	id _currentWritePacket;
	NSTimer *writeTimer;
#endif
}

/*
 * Host Initialisers
 */

// Note: the lower-layer is provided
- (id)initHostWithSocket:(CFSocketRef)socket;

// Note: the lower-layer is created from the signature, the signature address is copied out
- (id)initHostWithSignature:(const CFSocketSignature *)signature;

/*
 * Connection Initialisers
 *	These create an implicitly full-duplex bidirectional stream
 */

- (id)initConnectionWithNetService:(CFNetServiceRef)service;
- (id)initConnectionWithHost:(CFHostRef)host port:(SInt32)port;

/*
 * Use "canSafelySetDelegate" to see if there is any pending business (reads and writes) with the current delegate
 */
- (BOOL)canSafelySetDelegate;



@property (assign) id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate> delegate;

/*
 * Note: this is deprecated and will be removed
 */
- (CFSocketRef)lowerLayer __attribute__((deprecated));

/**
 * Disconnects after all pending writes have completed.
 * After calling this, the read and write methods (including "readDataWithTimeout:tag:") will do nothing.
 * The socket will disconnect even if there are still pending reads.
**/
- (void)disconnectAfterWriting;

/**
 * Returns progress of current read or write, from 0.0 to 1.0, or NaN if no read/write (use isnan() to check).
 * "tag", "done" and "total" will be filled in if they aren't NULL.
**/
- (float)progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;
- (float)progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;

/**
 * For handling readDataToData requests, data is necessarily read from the socket in small increments.
 * The performance can be improved by allowing AsyncSocket to read larger chunks at a time and
 * store any overflow in a small internal buffer.
 * This is termed pre-buffering, as some data may be read for you before you ask for it.
 * If you use readDataToData a lot, enabling pre-buffering may offer a small performance improvement.
 * 
 * Pre-buffering is disabled by default. You must explicitly enable it to turn it on.
 * 
 * Note: If your protocol negotiates upgrades to TLS (as opposed to using TLS from the start), you should
 * consider how, if at all, pre-buffering could affect the TLS negotiation sequence.
 * This is because TLS runs atop TCP, and requires sending/receiving a TLS handshake over the TCP socket.
 * If the negotiation sequence is poorly designed, pre-buffering could potentially pre-read part of the TLS handshake,
 * thus causing TLS to fail. In almost all cases, especially when implementing a formalized protocol, this will never
 * be a hazard.
**/
- (void)enablePreBuffering;

/**
 * In the event of an error, this method may be called during onSocket:willDisconnectWithError: to read
 * any data that's left on the socket.
**/
- (NSData *)unreadData;

@end

@protocol AFSocketStreamControlDelegate <AFConnectionLayerHostDelegate>

 @optional

/*!
	@method
	@abstract	This will allow callbacks to execute in the given run loop's thread, defaults to CFRunLoopMain() is none given
 */
- (CFRunLoopRef)layerShouldScheduleWithRunLoop:(id <AFConnectionLayer>)layer;

@end

@protocol AFSocketStreamDataDelegate <AFNetworkLayerDataDelegate>

@optional

/**
 * Called when a socket has read in data, but has not yet completed the read.
 * This would occur if using readToData: or readToLength: methods.
 * It may be used to for things such as updating progress bars.
 **/
- (void)layer:(AFSocketStream *)stream didReadPartialDataOfLength:(CFIndex)partialLength tag:(long)tag;

@end
