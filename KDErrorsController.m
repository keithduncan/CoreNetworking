//
//  KDErrorsController.m
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ErrorPresentation.h"

#import "KDPluralTransformer.h"

@implementation KDErrorsController

@synthesize title=_title;
@synthesize errors=_errors;

+ (void)initialize {
	KDPluralTransformer *transformer = [[KDPluralTransformer alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:@"KDPluralTransformer"];
	[transformer release];
}

- (void)dealloc {
	self.title = nil;
	self.errors = nil;
	
	[super dealloc];
}

- (void)windowDidLoad {
	KDErrorCell *cell = [[KDErrorCell alloc] init];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[errorColumn setDataCell:cell];
	[cell release];
	
	[[self window] center];
	[[self window] orderFront:nil];
}

- (IBAction)closeWindow:(id)sender {
	[self close];
	
	[NSApp errorsPresented];
	[self release];
}

@end
