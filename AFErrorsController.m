//
//  AFErrorsController.m
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "ErrorPresentation.h"

#import "AFPluralTransformer.h"

@implementation AFErrorsController

@synthesize title=_title;
@synthesize errors=_errors;

+ (void)initialize {
	AFPluralTransformer *transformer = [[AFPluralTransformer alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:@"AFPluralTransformer"];
	[transformer release];
}

- (void)dealloc {
	self.title = nil;
	self.errors = nil;
	
	[super dealloc];
}

- (void)windowDidLoad {
	AFErrorCell *cell = [[AFErrorCell alloc] init];
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
