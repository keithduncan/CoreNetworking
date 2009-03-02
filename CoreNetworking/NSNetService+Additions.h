//
//  NSNetService+Additions.h
//  Bonjour
//
//  Created by Keith Duncan on 30/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@interface NSNetService (AFAdditions) <AFNetServiceCommon>

- (NSString *)fullName;

@end
