//
//  NSApplication+Additions.m
//  iLog fitness
//
//  Created by Keith Duncan on 19/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSApplication+Additions.h"

#import "AFError.h"
#import "AFErrorsController.h"

@implementation NSApplication (AFAdditions)

static NSLock *errorsLock = nil;

- (void)presentErrors:(NSArray *)errors withTitle:(NSString *)title {
	@synchronized(self) {
		if (errorsLock == nil) errorsLock = [[NSLock alloc] init];
		[errorsLock lock];
	}
	
	AFErrorsController *controller = [[AFErrorsController alloc] initWithWindowNibName:@"Errors"];
	controller.errors = errors;
	controller.title = title;
		
	[NSApp runModalForWindow:[controller window]];
	[NSApp requestUserAttention:NSCriticalRequest];
}

- (void)errorsPresented {
	[errorsLock unlock];
	[NSApp stopModal];
}

@end
