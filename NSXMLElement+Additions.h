//
//  NSXMLElement+Additions.h
//  TimelineUpdates
//
//  Created by Keith Duncan on 22/11/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSXMLElement (Additions)
// Should there be >1 or elements for any of the key path components an exception is raised, if 0 elements for any key path component nil is returned
- (NSXMLNode *)nodeForKeyPath:(NSString *)keyPath;
// This method uses -elementForKeyPath so the same restrictions apply
- (void)setNode:(NSXMLNode *)node forKeyPath:(NSString *)keyPath;
@end
