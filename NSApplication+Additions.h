//
//  NSApplication+Additions.h
//  iLog fitness
//
//  Created by Keith Duncan on 19/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSApplication (AFAdditions)
- (void)presentErrors:(NSArray *)errors withTitle:(NSString *)title;
- (void)errorsPresented;
@end
