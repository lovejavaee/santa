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

#import "SNTRule.h"

@implementation SNTRule

static NSString *const kShasumKey = @"shasum";
static NSString *const kStateKey = @"state";
static NSString *const kTypeKey = @"type";
static NSString *const kCustomMessageKey = @"custommsg";

- (instancetype)initWithShasum:(NSString *)shasum
                         state:(santa_rulestate_t)state
                          type:(santa_ruletype_t)type
                     customMsg:(NSString *)customMsg {
  self = [super init];
  if (self) {
    _shasum  = shasum;
    _state = state;
    _type = type;
    _customMsg = customMsg;
  }
  return self;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.shasum forKey:kShasumKey];
  [coder encodeInt:self.state forKey:kStateKey];
  [coder encodeInt:self.type forKey:kTypeKey];
  [coder encodeObject:self.customMsg forKey:kCustomMessageKey];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  NSSet *stringPlusNull = [NSSet setWithObjects:[NSString class], [NSNull class], nil];

  _shasum = [decoder decodeObjectOfClass:[NSString class] forKey:kShasumKey];
  _state = [decoder decodeIntForKey:kStateKey];
  _type = [decoder decodeIntForKey:kTypeKey];
  _customMsg = [decoder decodeObjectOfClasses:stringPlusNull forKey:kCustomMessageKey];
  return self;
}

@end