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

/// Protocol implemented by SantaNotifier and utilized by santad
@class SNTNotificationMessage;
@protocol SNTNotifierXPC
- (void)postBlockNotification:(SNTNotificationMessage *)event;
@end

@interface SNTXPCNotifierInterface : NSObject

///
///  @return the MachService ID for this service.
///
+ (NSString *)serviceId;

///
///  @return an initialized NSXPCInterface for the SNTNotifierXPC protocol.
///  Ensures any methods that accept custom classes as arguments are set-up before returning
///
+ (NSXPCInterface *)notifierInterface;

@end
