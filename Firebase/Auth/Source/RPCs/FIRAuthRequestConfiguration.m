/*
 * Copyright 2017 Google
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

#import "FIRAuthRequestConfiguration.h"
#import "FIRAuthExceptionUtils.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kAPIKey
    @brief The key used to encode the APIKey for NSSecureCoding.
 */
static NSString *const kAPIKey = @"apiKey";

@implementation FIRAuthRequestConfiguration

- (nullable instancetype)initWithAPIKey:(NSString *)APIKey {
  self = [super init];
  if (self) {
    _APIKey = [APIKey copy];
  }
  return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  NSString *apiKey = [aDecoder decodeObjectOfClass:[NSString class] forKey:kAPIKey];
  self = [self initWithAPIKey:apiKey];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_APIKey forKey:kAPIKey];
}

@end

NS_ASSUME_NONNULL_END
