//
//  AFFoundationMacros.h
//  AmberFoundation
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define NSSTRING_CONSTANT(var) NSString *const var = @#var
#define NSSTRING_CONTEXT(var) static NSString *var = @#var
