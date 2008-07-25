//
//  NSUserDefaults+Additions.h
//  dawn
//
//  Created by Keith Duncan on 17/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults (AFAdditions)
// Changes will be commited to NSUserDefaults at the end of the run loop
+ (NSMutableDictionary *)persistentDomainForBundleIdentifier:(NSString *)bundleIdentifier;
@end
