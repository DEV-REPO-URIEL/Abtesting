/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FIRPhoneMultiFactorInfo.h"

#import "FIRAuthProtoMfaEnrollment.h"
#import "FIRMultiFactorInfo+Internal.h"
#import "FIRMultiFactorInfo.h"

extern NSString *const FIRPhoneMultiFactorID;

@implementation FIRPhoneMultiFactorInfo

- (instancetype)initWithProto:(FIRAuthProtoMfaEnrollment *)proto {
  self = [super initWithProto:proto];
  if (self) {
    _factorID = FIRPhoneMultiFactorID;
    _phoneNumber = proto.mfaValue;
  }
  return self;
}

@end

#endif
