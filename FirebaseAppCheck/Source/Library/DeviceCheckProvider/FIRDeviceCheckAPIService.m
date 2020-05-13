/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRDeviceCheckAPIService.h"

#import <FBLPromises/FBLPromises.h>

#import "FIRAppCheckToken.h"

@implementation FIRDeviceCheckAPIService

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithDeviceToken:(NSData *)deviceToken {
  // TODO: Implement.
  return [FBLPromise resolvedWith:[[FIRAppCheckToken alloc] initWithToken:@"token"
                                                           expirationDate:[NSDate distantFuture]]];
}

@end
