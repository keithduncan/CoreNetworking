//
//  AFErrorsController.h
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AFErrorsController : NSWindowController {
	NSString *_title;
	
	NSArray *_errors;
	IBOutlet NSTableColumn *errorColumn;
}

@property(copy) NSString *title;
@property(retain) NSArray *errors;

- (IBAction)closeWindow:(id)sender;

@end
