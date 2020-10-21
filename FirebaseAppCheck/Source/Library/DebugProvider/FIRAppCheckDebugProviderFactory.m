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

#import "FirebaseAppCheck/Source/Library/DebugProvider/Public/FIRAppCheckDebugProviderFactory.h"

#import "FirebaseAppCheck/Source/Library/DebugProvider/Public/FIRAppCheckDebugProvider.h"

#import "FirebaseAppCheck/Source/Library/Core/Private/FIRAppCheckInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppCheckDebugProviderFactory

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  FIRAppCheckDebugProvider *provider = [[FIRAppCheckDebugProvider alloc] init];

  // Print only locally generated token to avoid a valid token leak on CI.
  FIRLogWarning(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown,
                @"Firebase App Check debug token: '%@'.", [provider localDebugToken]);

  return provider;
}

@end

NS_ASSUME_NONNULL_END
