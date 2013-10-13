//
//  AFNetworkService_DNSLabelBufferOverflow.m
//  CoreNetworking
//
//  Created by Keith Duncan on 06/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkService_DNSLabelBufferOverflow.h"

#import <mach/vm_map.h>

#import "CoreNetworking/CoreNetworking.h"
#import "AFNetworkService-PrivateFunctions.h"

@implementation AFNetworkService_DNSLabelBufferOverflow

- (void)testMaliciousPascalStringDoesntCauseBufferOverflow {
	vm_address_t buffer = 0;
	vm_size_t bufferSize = (2 * PAGE_SIZE);
	kern_return_t allocateError = vm_allocate(mach_task_self(), &buffer, bufferSize, VM_FLAGS_ANYWHERE);
	STAssertTrue(allocateError == KERN_SUCCESS, @"vm_allocate must succeed");
	
	int error = mprotect((void *)(buffer + PAGE_SIZE), PAGE_SIZE, PROT_NONE);
	STAssertFalse(error, @"mprotect must succeed");
	
	uint8_t pattern[16] = {};
	memset(pattern, 'a', 16);
	pattern[0] = 15;
	memset_pattern16((void *)buffer, pattern, PAGE_SIZE);
	
	uint8_t *lastLabelSize = (uint8_t *)(buffer + PAGE_SIZE - 16);
	(*lastLabelSize)++;
	
	AFNetworkServiceScope *scope = _AFNetworkServiceBrowserParseEscapedRecord(PAGE_SIZE, (void *)buffer);
	STAssertNil(scope, @"scope should be nil");
	
	vm_deallocate(mach_task_self(), buffer, bufferSize);
}

@end
