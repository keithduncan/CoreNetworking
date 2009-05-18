//
//  AFMacro.h
//  Amber
//
//  Created by Keith Duncan on 16/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AmberFoundation/NSString+Additions.h"

#define NSSTRING_CONTEXT(var) static NSString *var = @#var

NS_INLINE BOOL AFFileExistsAtPath(NSString *path) {
	return (path != nil && ![path isEmpty] && [[NSFileManager defaultManager] fileExistsAtPath:[path stringByExpandingTildeInPath]]);
}
