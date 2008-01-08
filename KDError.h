//
//  KDError.h
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	WARNING,
	ERROR
};
typedef NSUInteger errorType;

@interface KDError : NSObject <NSCopying> {
	errorType type;
	NSString *name , *reason;
}

+ (id)errorWithName:(NSString *)name reason:(NSString *)reason;
+ (id)warningWithName:(NSString *)name reason:(NSString *)reason;

- (id)initWithType:(errorType)type name:(NSString *)name reason:(NSString *)reason;

@property errorType type;
@property(copy) NSString *name, *reason;

@property(readonly) NSImage *image;

@end

@interface NSImage (KDError)
+ (NSImage *)errorImage;
+ (NSImage *)warningImage;
@end
