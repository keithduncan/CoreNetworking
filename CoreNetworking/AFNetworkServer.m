//
//  AFConnectionServer.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkServer.h"

#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <objc/runtime.h>

#import "AFNetworkSocket.h"
#import "AFNetworkTransport.h"
#import "AFNetworkSchedule.h"
#import "AFNetworkPortMapper.h"

#import "AFNetworkDelegateProxy.h"

#import	"AFNetwork-Types.h"
#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

@interface AFNetworkServer () <AFNetworkSocketDelegate, AFNetworkTransportLayerControlDelegate>
@property (retain, nonatomic) NSMutableSet *listeners;
@property (retain, nonatomic) NSArray *encapsulationClasses;
@property (retain, nonatomic) NSMutableSet *connections;
@end

@interface AFNetworkServer (AFNetworkPrivate)
- (void)_initialiseWithEncapsulationClass:(Class)encapsulationClass;
- (AFNetworkLayer *)_encapsulateNetworkLayer:(AFNetworkLayer *)layer;
- (void)_fullyEncapsulateLayer:(AFNetworkLayer *)layer;
- (void)_scheduleLayer:(id)layer;
- (void)_unscheduleLayer:(id)layer;
@end

@implementation AFNetworkServer

@synthesize schedule=_schedule;
@synthesize delegate=_delegate;

@synthesize listeners=_listeners;

@synthesize encapsulationClasses=_encapsulationClasses, connections=_connections;

+ (id)server {
	return [[[self alloc] init] autorelease];
}

#pragma mark -

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_schedule = [[AFNetworkSchedule alloc] init];
#if 0
	[_schedule scheduleInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
#else
	[_schedule scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
#endif
	
	_listeners = [[NSMutableSet alloc] init];
	
	_connections = [[NSMutableSet alloc] init];
	
	[self _initialiseWithEncapsulationClass:[AFNetworkTransport class]];
	
	return self;
}

- (id)initWithEncapsulationClass:(Class)encapsulationClass {
	self = [self init];
	if (self == nil) return nil;
	
	[self _initialiseWithEncapsulationClass:encapsulationClass];
	
	return self;
}

- (void)dealloc {	
	[_schedule release];
	
	[_listeners release];
	
	[_encapsulationClasses release];
	[_connections release];
	
	[super dealloc];
}

- (void)setSchedule:(AFNetworkSchedule *)schedule {
	NSParameterAssert([self.listeners count] == 0);
	
	[_schedule autorelease];
	_schedule = [schedule retain];
}

- (AFNetworkDelegateProxy *)delegateProxy:(AFNetworkDelegateProxy *)proxy {	
	if (_delegate == nil) {
		return proxy;
	}
	
	if (proxy == nil) {
		proxy = [[[AFNetworkDelegateProxy alloc] init] autorelease];
	}
	
	[proxy insertTarget:self];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) {
		proxy = [(id)_delegate delegateProxy:proxy];
	}
	
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature scope:(AFNetworkInternetSocketScope)scope port:(uint16_t)port errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler {
	struct addrinfo hints = {
		.ai_family = AF_UNSPEC,
		.ai_socktype = socketSignature.socketType,
		.ai_flags = AI_PASSIVE,
	};
	struct addrinfo *addresses = NULL;
	
	char const *nodename = NULL;
	if (scope == AFNetworkInternetSocketScopeLocalOnly) {
		nodename = "localhost";
	}
	else if (scope == AFNetworkInternetSocketScopeGlobal) {
		nodename = NULL;
	}
	else {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unknown address scope %ld", (unsigned long)scope] userInfo:nil];
		return NO;
	}
	
	char const *servname = [[NSString stringWithFormat:@"%hu", port] UTF8String];
	
	int getaddrinfoError = getaddrinfo(nodename, servname, &hints, &addresses);
	if (getaddrinfoError != 0) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSNumber numberWithInteger:getaddrinfoError], (id)kCFGetAddrInfoFailureKey,
								   nil];
		NSError *error = [NSError errorWithDomain:(id)kCFErrorDomainCFNetwork code:kCFHostErrorUnknown userInfo:errorInfo];
		
		NSError *displayError = AFNetworkStreamPrepareDisplayError(nil, error);
		
		if (errorHandler != nil) {
			errorHandler(nil, displayError);
		}
		
		return NO;
	}
	
	NSMutableSet *socketAddresses = [NSMutableSet set];
	for (struct addrinfo *currentAddressInfo = addresses; currentAddressInfo != NULL; currentAddressInfo = currentAddressInfo->ai_next) {
		NSData *currentAddressData = [NSData dataWithBytes:currentAddressInfo->ai_addr length:currentAddressInfo->ai_addrlen];
		[socketAddresses addObject:currentAddressData];
	}
	
	freeaddrinfo(addresses);
	
	return [self openInternetSocketsWithSocketSignature:socketSignature socketAddresses:socketAddresses errorHandler:errorHandler];
}

- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature socketAddresses:(NSSet *)socketAddresses errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler {
	NSMutableSet *socketObjects = [NSMutableSet setWithCapacity:[socketAddresses count]];
	BOOL shouldCloseSocketObjects = NO;
	
	for (NSData *currentSocketAddress in socketAddresses) {
		NSError *currentSocketObjectError = nil;
		AFNetworkSocket *currentSocketObject = [self openSocketWithSignature:socketSignature address:currentSocketAddress options:nil error:&currentSocketObjectError];
		if (currentSocketObject == nil) {
			if (errorHandler != nil) {
				BOOL errorHandlerValue = errorHandler(currentSocketAddress, currentSocketObjectError);
				if (!errorHandlerValue) {
					shouldCloseSocketObjects = YES;
					break;
				}
				
				continue;
			}
			
			shouldCloseSocketObjects = YES;
			break;
		}
		
		[socketObjects addObject:currentSocketObject];
	}
	
	if (shouldCloseSocketObjects) {
		[socketObjects makeObjectsPerformSelector:@selector(close)];
		return NO;
	}
	
	return YES;
}

- (BOOL)openPathSocketWithLocation:(NSURL *)location error:(NSError **)errorRef {
	NSParameterAssert([location isFileURL]);
	
	AFNetworkSocketSignature signature = (AFNetworkSocketSignature){
		.socketType = SOCK_STREAM,
		.protocol = 0,
	};
	
	char const *fileSystemRepresentation = [[location path] fileSystemRepresentation];
	
	struct sockaddr_un address = {};
	unsigned int maximumLength = sizeof(address.sun_path);
	if (strlen(fileSystemRepresentation) >= maximumLength) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, (%@) must be < %lu characters including the NUL terminator", __PRETTY_FUNCTION__, [location path], (unsigned long)maximumLength] userInfo:nil];
		return NO;
	}
	
	address.sun_family = AF_UNIX;
	strlcpy(address.sun_path, fileSystemRepresentation, sizeof(address.sun_path));
	address.sun_len = SUN_LEN(&address);
	
	NSData *addressData = [NSData dataWithBytes:&address length:address.sun_len];
	
	AFNetworkSocket *socket = [self openSocketWithSignature:signature address:addressData options:nil error:errorRef];
	if (socket == nil) {
		return NO;
	}
	
	return YES;
}

- (AFNetworkSocket *)openSocketWithSignature:(AFNetworkSocketSignature const)signature address:(NSData *)address options:(NSSet *)options error:(NSError **)errorRef {
	NSParameterAssert(self.listeners != nil);
	NSParameterAssert(self.schedule != nil);
	
	CFRetain(address);
	
	sa_family_t protocolFamily = ((struct sockaddr_storage const *)[address bytes])->ss_family;
	
	CFSocketSignature socketSignature = {
		.protocolFamily = protocolFamily,
		.socketType = signature.socketType,
		.protocol = signature.protocol,
		.address = (CFDataRef)address,
	};
	
	AFNetworkSocket *newSocket = [[[AFNetworkSocket alloc] initWithSocketSignature:&socketSignature options:options] autorelease];
	
	CFRelease(address);
	
	BOOL addListen = [self addListenSocket:newSocket error:errorRef];
	if (!addListen) {
		return nil;
	}
	
	return newSocket;
}

- (BOOL)addListenSocket:(AFNetworkSocket *)socket error:(NSError **)errorRef {
	[self _scheduleLayer:socket];
	[socket setDelegate:self];
	
	BOOL open = [socket open:errorRef];
	if (!open) {
		return NO;
	}
	
	[self.listeners addObject:socket];
	
	return YES;
}

- (void)closeListenSockets {
	for (AFNetworkSocket *currentLayer in self.listeners) {
		[self _unscheduleLayer:currentLayer];
		[currentLayer close];
	}
	[self.listeners removeAllObjects];
}

- (void)addConnection:(id)connection {
	[self configureLayer:connection];
	
	[self.connections addObject:connection];
}

- (void)closeConnections {
	for (AFNetworkLayer <AFNetworkTransportLayer> *currentLayer in self.connections) {
		[self _unscheduleLayer:currentLayer];
		[currentLayer close];
	}
	[self.connections removeAllObjects];
}

- (void)close {
	[self closeListenSockets];
	
	[self closeConnections];
}

#pragma mark - Delegate

- (void)networkLayer:(id)layer didReceiveConnection:(AFNetworkSocket *)sender {
	NSParameterAssert([self.listeners containsObject:layer]);
	
	BOOL shouldAccept = YES;
	if ([self.delegate respondsToSelector:@selector(networkServer:shouldAcceptConnection:)]) {
		shouldAccept = [self.delegate networkServer:self shouldAcceptConnection:(id)sender];
	}
	
	if (!shouldAccept) {
		[sender close];
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkServer:didAcceptConnection:)]) {
		[self.delegate networkServer:self didAcceptConnection:(id)sender];
	}
	
	[self _fullyEncapsulateLayer:sender];
}

- (void)networkLayerDidOpen:(id <AFNetworkTransportLayer>)layer {
	//nop
}

- (void)networkLayerDidClose:(id <AFNetworkTransportLayer>)layer {
	if ([self.listeners containsObject:layer]) {
		[self _unscheduleLayer:layer];
		[self.listeners removeObject:layer];
	}
	else if ([self.connections containsObject:layer]) {
		[self _unscheduleLayer:layer];
		[self.connections removeObject:layer];
	}
	else {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"unknown layer" userInfo:nil];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didReceiveError:(NSError *)error {
	[layer close];
}

- (void)configureLayer:(id <AFNetworkTransportLayer>)layer {
	[self _scheduleLayer:layer];
	[layer setDelegate:self];
}

@end

#pragma mark -

@implementation AFNetworkServer (AFNetworkPrivate)

- (void)_initialiseWithEncapsulationClass:(Class)encapsulationClass {
	NSMutableArray *newEncapsulationClasses = [NSMutableArray arrayWithObjects:encapsulationClass, nil];
	for (id lowerLayer = [encapsulationClass lowerLayerClass]; lowerLayer != Nil; lowerLayer = [lowerLayer lowerLayerClass]) {
		[newEncapsulationClasses insertObject:lowerLayer atIndex:0];
	}
	self.encapsulationClasses = newEncapsulationClasses;
}

- (AFNetworkLayer *)_encapsulateNetworkLayer:(AFNetworkLayer *)layer {
	NSInteger classIndex = [self.encapsulationClasses indexOfObject:[layer class]];
	if (classIndex == NSNotFound) {
		return nil;
	}
	
	NSUInteger nextClassIndex = (classIndex + 1);
	if (nextClassIndex >= [self.encapsulationClasses count]) {
		return nil;
	}
	
	Class encapsulationClass = [self.encapsulationClasses objectAtIndex:nextClassIndex];
	AFNetworkLayer *newLayer = [[[encapsulationClass alloc] initWithLowerLayer:(id)layer] autorelease];
	
	if ([self.delegate respondsToSelector:@selector(networkServer:didEncapsulateLayer:)]) {
		[self.delegate networkServer:self didEncapsulateLayer:(id)newLayer];
	}
	
	return newLayer;
}

- (void)_fullyEncapsulateLayer:(AFNetworkLayer *)layer {
	AFNetworkLayer *currentLayer = layer;
	
	while (1) {
		AFNetworkLayer *encapsulatedLayer = [self _encapsulateNetworkLayer:currentLayer];
		if (encapsulatedLayer == nil) {
			break;
		}
		
		[self _scheduleLayer:encapsulatedLayer];
		
		currentLayer = encapsulatedLayer;
	}
	
	[self addConnection:currentLayer];
	
	[(id <AFNetworkTransportLayer>)currentLayer open];
}

- (void)_scheduleLayer:(AFNetworkLayer *)layer {
	AFNetworkSchedule *schedule = self.schedule;
	NSParameterAssert(schedule != nil);
	
	if (schedule->_runLoop != nil) {
		NSRunLoop *runLoop = schedule->_runLoop;
		
		[layer scheduleInRunLoop:runLoop forMode:schedule->_runLoopMode];
	}
	else if (schedule->_dispatchQueue != NULL) {
		dispatch_queue_t dispatchQueue = schedule->_dispatchQueue;
		
		[layer scheduleInQueue:dispatchQueue];
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported schedule environment" userInfo:nil];
	}
}

- (void)_unscheduleLayer:(AFNetworkLayer *)layer {
	[layer setDelegate:nil];
}

@end
