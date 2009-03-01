//
//  AsyncSocket.h
//  
//  This class is in the public domain.
//  Originally created by Dustin Voss on Wed Jan 29 2003.
//  Updated and maintained by Deusty Designs and the Mac development community.
//
//  Renamed to AFSocketStreams, API changed, and included in Core Networking by Keith Duncan
//
//  Original host http://code.google.com/p/cocoaasyncsocket/
//

#import <Foundation/Foundation.h>

#import "AmberNetworking.h"

@class AsyncReadPacket, AsyncWritePacket;

@protocol AFSocketStreamDataDelegate;
@protocol AFSocketStreamControlDelegate;

extern NSString *const AsyncSocketException;
extern NSString *const AsyncSocketErrorDomain;

enum AsyncSocketError {
	AsyncSocketCFSocketError = kCFSocketError,	// From CFSocketError enum.
	AsyncSocketNoError = 0,						// Never used.
	AsyncSocketCanceledError,					// onSocketWillConnect: returned NO.
	AsyncSocketReadMaxedOutError,               // Reached set maxLength without completing
	AsyncSocketReadTimeoutError,
	AsyncSocketWriteTimeoutError
};
typedef NSInteger AFSocketStreamsError;

@interface AFSocketStream : NSObject <AFConnectionLayer> {
	id _delegate;
	void *_context;
	NSUInteger flags;
	
	CFRunLoopRef runLoop;
	CFRunLoopSourceRef runLoopSource;
	
	CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	AsyncReadPacket *currentRead;
	NSTimer *readTimer;
	NSMutableData *partialReadBuffer;
	
	CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	AsyncWritePacket *currentWrite;
	NSTimer *writeTimer;
}

- (id)initWithLocalHost:(CFDataRef)addr port:(SInt32)port error:(NSError **)errorRef;
- (id)initWithRemoteHost:(CFHostRef)host port:(SInt32)port error:(NSError **)errorRef;

/**
 * Use "canSafelySetDelegate" to see if there is any pending business (reads and writes) with the current delegate
 * before changing it.  It is, of course, safe to change the delegate before connecting or accepting connections.
**/
- (BOOL)canSafelySetDelegate;

@property (assign) id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate> delegate;

// Note: this isn't retained, if it's an object then you need to manage the memory
@property (assign) void *context;

/*
 * Note: this _probably_ shouldn't be used and will likely be removed
 */
- (CFSocketRef)lowerLayer;

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

@protocol AFSocketStreamDataDelegate <AFNetworkLayerDataDelegate>

 @optional

/**
 * Called when a socket has read in data, but has not yet completed the read.
 * This would occur if using readToData: or readToLength: methods.
 * It may be used to for things such as updating progress bars.
 **/
- (void)socket:(AFSocketStream *)sock didReadPartialDataOfLength:(CFIndex)partialLength tag:(long)tag;

@end

@protocol AFSocketStreamControlDelegate <AFConnectionLayerControlDelegate>

/**
 * In the event of an error, the socket is closed.
 * You may call "unreadData" during this call-back to get the last bit of data off the socket.
 * When connecting, this delegate method may be called
 * before"onSocket:didAcceptNewSocket:" or "socket:didConnectToHost:".
 **/
- (void)layer:(AFSocketStream *)sock willDisconnectWithError:(NSError *)err;

/**
 * Called when a socket accepts a connection.  Another socket is spawned to handle it. The new socket will have
 * the same delegate and will call "socket:didConnectToHost:port:".
 **/
- (void)layer:(id <AFNetworkLayer>)sock didAcceptConnection:(id <AFNetworkLayer>)newSocket;

 @optional

/**
 * Called when a new socket is spawned to handle a connection.  This method should return the run-loop of the
 * thread on which the new socket and its delegate should operate. If omitted, [NSRunLoop currentRunLoop] is used.
 **/
- (NSRunLoop *)layer:(AFSocketStream *)sock runLoopForNewLayer:(AFSocketStream *)newSocket;

 @required

/**
 * Called when a socket is about to connect. This method should return YES to continue, or NO to abort.
 * If aborted, will result in AsyncSocketCanceledError.
 * 
 * If the connectToHost:onPort:error: method was called, the delegate will be able to access and configure the
 * CFReadStream and CFWriteStream as desired prior to connection.
 *
 * If the connectToAddress:error: method was called, the delegate will be able to access and configure the
 * CFSocket and CFSocketNativeHandle (BSD socket) as desired prior to connection. You will be able to access and
 * configure the CFReadStream and CFWriteStream in the socket:didConnectToHost:port: method.
 **/
- (BOOL)layerWillConnect:(AFSocketStream *)sock;

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)layer:(AFSocketStream *)sock didConnectToHost:(const struct sockaddr *)remoteAddr;
#warning this callback should use CFHost

@end
