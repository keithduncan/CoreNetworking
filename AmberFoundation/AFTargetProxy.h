//
//  AFTargetProxy.h
//  Amber
//
//  Created by Keith Duncan on 07/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
	@brief
	Returns the result of -[self.target valueForKeyPath:self.keyPath] as it's forwarding target.
	
	@detail
	Allows you to dynamically proxy a delegate, without regenerating proxy chains each time one changes.
 */
@interface AFTargetProxy : NSProxy {
 @private
	id _target;
	NSString *_keyPath;
}

/*!
	@brief
	Designated Initialiser.
	
	@param target
	Retained.
	
	@param keyPath
	Copied.
 */
- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath;

@end
