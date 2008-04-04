//
//  NSApplication+Additions.m
//  iLog fitness
//
//  Created by Keith Duncan on 19/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSApplication+Additions.h"

#import "KDError.h"
#import "KDErrorsController.h"

@implementation NSApplication (Additions)

static NSLock *errorsLock = nil;

- (void)presentErrors:(NSArray *)errors withTitle:(NSString *)title {
	@synchronized(self) {
		if (errorsLock == nil) errorsLock = [[NSLock alloc] init];
		[errorsLock lock];
	}
	
	KDErrorsController *controller = [[KDErrorsController alloc] initWithWindowNibName:@"Errors"];
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
