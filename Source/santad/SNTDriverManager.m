/// Copyright 2014 Google Inc. All rights reserved.
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///    http://www.apache.org/licenses/LICENSE-2.0
///
///    Unless required by applicable law or agreed to in writing, software
///    distributed under the License is distributed on an "AS IS" BASIS,
///    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///    See the License for the specific language governing permissions and
///    limitations under the License.

#import "SNTDriverManager.h"

#include <IOKit/IODataQueueClient.h>
#include <mach/mach.h>

#include "SNTLogging.h"

#import "SNTNotificationMessage.h"

@interface SNTDriverManager ()
@property IODataQueueMemory *queueMemory;
@property io_connect_t connection;
@property mach_port_t receivePort;
@end

@implementation SNTDriverManager

#pragma mark init/dealloc

- (instancetype)init {
  self = [super init];
  if (self) {
    kern_return_t kr;
    io_service_t serviceObject;
    CFDictionaryRef classToMatch;

    if (!(classToMatch = IOServiceMatching(USERCLIENT_CLASS))) {
      LOGD(@"Failed to create matching dictionary");
      return nil;
    }

    // Locate driver. Wait for it if necessary.
    do {
      CFRetain(classToMatch);  // this ref is released by IOServiceGetMatchingService
      serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, classToMatch);

      if (!serviceObject) {
        LOGD(@"Waiting for Santa driver to become available");
        sleep(10);
      }
    } while (!serviceObject);
    CFRelease(classToMatch);

    // This calls @c initWithTask, @c attach and @c start in @c SantaDriverClient
    kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &_connection);
    IOObjectRelease(serviceObject);
    if (kr != kIOReturnSuccess) {
      LOGD(@"Failed to open Santa driver service");
      return nil;
    }

    // Call @c open in @c SantaDriverClient
    kr = IOConnectCallMethod(_connection, kSantaUserClientOpen, 0, 0, 0, 0, 0, 0, 0, 0);

    if (kr == kIOReturnExclusiveAccess) {
      LOGD(@"A client is already connected");
      return nil;
    } else if (kr != kIOReturnSuccess) {
      LOGD(@"An error occurred while opening the connection");
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  IOServiceClose(_connection);
}

# pragma mark Incoming messages

- (void)listenWithBlock:(void (^)(santa_message_t message))callback {
  kern_return_t kr;
  santa_message_t vdata;
  UInt32 dataSize;

  mach_vm_address_t address = 0;
  mach_vm_size_t size = 0;
  unsigned int msgType = 1;

  // Allocate a mach port to receive notifactions from the IODataQueue
  if (!(self.receivePort = IODataQueueAllocateNotificationPort())) {
    LOGD(@"Failed to allocate notification port");
    return;
  }

  // This will call registerNotificationPort() inside our user client class
  kr = IOConnectSetNotificationPort(self.connection, msgType, self.receivePort, 0);
  if (kr != kIOReturnSuccess) {
    LOGD(@"Failed to register notification port: %d", kr);
    mach_port_destroy(mach_task_self(), self.receivePort);
    return;
  }

  // This will call clientMemoryForType() inside our user client class,
  // which activates the Kauth listeners.
  kr = IOConnectMapMemory(self.connection, kIODefaultMemoryType, mach_task_self(),
                          &address, &size, kIOMapAnywhere);
  if (kr != kIOReturnSuccess) {
    LOGD(@"Failed to map memory: %d", kr);
    mach_port_destroy(mach_task_self(), self.receivePort);
    return;
  }

  self.queueMemory = (IODataQueueMemory *)address;
  dataSize = sizeof(vdata);

  while (IODataQueueWaitForAvailableData(self.queueMemory,
                                         self.receivePort) == kIOReturnSuccess) {
    while (IODataQueueDataAvailable(self.queueMemory)) {
      kr = IODataQueueDequeue(self.queueMemory, &vdata, &dataSize);
      if (kr == kIOReturnSuccess) {
        callback(vdata);
      } else {
        LOGD(@"Error receiving data: %d", kr);
        exit(2);
      }
    }
  }

  IOConnectUnmapMemory(self.connection, kIODefaultMemoryType, mach_task_self(), address);
  mach_port_destroy(mach_task_self(), self.receivePort);
}

#pragma mark Outgoing messages

- (kern_return_t)postToKernelAction:(santa_action_t)action forVnodeID:(uint64_t)vnodeId {
  switch (action) {
    case ACTION_RESPOND_CHECKBW_ALLOW:
      return IOConnectCallScalarMethod(self.connection,
                                       kSantaUserClientAllowBinary,
                                       &vnodeId,
                                       1,
                                       0,
                                       0);
    case ACTION_RESPOND_CHECKBW_DENY:
      return IOConnectCallScalarMethod(self.connection,
                                       kSantaUserClientDenyBinary,
                                       &vnodeId,
                                       1,
                                       0,
                                       0);
    default:
      return KERN_INVALID_ARGUMENT;
  }
}

- (uint64_t)cacheCount {
  uint32_t input_count = 1;
  uint64_t cache_count = 0;

  IOConnectCallScalarMethod(self.connection,
                            kSantaUserClientCacheCount,
                            0,
                            0,
                            &cache_count,
                            &input_count);
  return cache_count;
}

- (BOOL)flushCache {
  return IOConnectCallScalarMethod(
      self.connection, kSantaUserClientClearCache, 0, 0, 0, 0) == KERN_SUCCESS;
}

@end
