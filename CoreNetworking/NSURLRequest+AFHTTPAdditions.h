//
//  NSURLRequest+AFHTTPAdditions.h
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSURLRequest (AFHTTPAdditions)

@property (readonly) NSURL *HTTPBodyFile;

@end

@interface NSMutableURLRequest (AFHTTPAdditions)

@property (readwrite, copy) NSURL *HTTPBodyFile;

@end
