//
//  NSURLRequest+AFHTTPAdditions.h
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSURLRequest (AFCoreNetworkingHTTPAdditions)

@property (readonly) NSURL *HTTPBodyFile;

@end

@interface NSMutableURLRequest (AFCoreNetworkingHTTPAdditions)

@property (readwrite, copy) NSURL *HTTPBodyFile;

@end
