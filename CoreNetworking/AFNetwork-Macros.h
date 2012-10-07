//
//  AFNetworkMacros.h
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AFNETWORK_API_VERSION 20121007

#if defined(__cplusplus)
	#define AFNETWORK_EXTERN extern "C"
#else
	#define AFNETWORK_EXTERN extern
#endif /* defined(__cplusplus) */

#define AFNETWORK_NSSTRING_CONSTANT(__var) NSString *const __var = @#__var
#define AFNETWORK_NSSTRING_CONTEXT(__var) static NSString *__var = @#__var

#if !defined(OBJC_NO_GC)
	#define AFNETWORK_STRONG 
#else
	#define AFNETWORK_STRONG __strong
#endif /* !defined(OBJC_NO_GC) */

/*
	Note
	
	Support fixed type enum declarations if available, otherwise fallback to the typedef plus enum version
 */
#if (__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))
	#define AFNETWORK_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
	#if (__cplusplus)
		#define AFNETWORK_OPTIONS(_type, _name) _type _name; enum : _type
	#else
		#define AFNETWORK_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
	#endif
#else
	#define AFNETWORK_ENUM(_type, _name) _type _name; enum
	#define AFNETWORK_OPTIONS(_type, _name) _type _name; enum
#endif

static void _AFNetworkCallScopedBlock(dispatch_block_t const *blockRef) {
	if (*blockRef != nil) (*blockRef)();
}
#define af_scoped_block_t dispatch_block_t __attribute__((cleanup(_AFNetworkCallScopedBlock), unused))
