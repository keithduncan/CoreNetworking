//
//  AFNetworkMacros.h
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define CORENETWORKING_NSSTRING_CONSTANT(var) NSString *const var = @#var

#define CORENETWORKING_NSSTRING_CONTEXT(var) static NSString *var = @#var
