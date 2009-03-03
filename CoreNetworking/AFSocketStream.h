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


- (BOOL)canSafelySetDelegate;
@property (assign) id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate> delegate;

/*
 * Note: this will be removed
 */
- (CFSocketRef)lowerLayer __attribute__((deprecated));

- (void)disconnectAfterWriting;

- (float)progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;
- (float)progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;

- (void)enablePreBuffering;

- (NSData *)unreadData;

@end

@protocol AFSocketStreamControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	Asynchronous callbacks can be scheduled in another run loop, defaults to CFRunLoopMain() if unimplemented
 */
- (CFRunLoopRef)layerShouldScheduleWithRunLoop:(id <AFConnectionLayer>)layer;

@end

@protocol AFSocketStreamDataDelegate <AFConnectionLayerDataDelegate>

 @optional

- (void)layer:(AFSocketStream *)stream didReadPartialDataOfLength:(CFIndex)partialLength tag:(long)tag;

@end
