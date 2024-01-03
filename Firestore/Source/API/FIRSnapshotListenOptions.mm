/*
 * Copyright 2023 Google LLC
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

#import "FIRSnapshotListenOptions.h"

#import <Foundation/Foundation.h>

#include <cstdint>
#include <string>

NS_ASSUME_NONNULL_BEGIN

@implementation FIRSnapshotListenOptions

// private method
- (instancetype)initPrivateWithSource:(FIRListenSource)source
               includeMetadataChanges:(BOOL)includeMetadataChanges {
  self = [self init];
  if (self) {
    _source = source;
    _includeMetadataChanges = includeMetadataChanges;
  }
  return self;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _source = FIRListenSourceDefault;
    _includeMetadataChanges = NO;
  }
  return self;
}

- (FIRSnapshotListenOptions *)withIncludeMetadataChanges:(BOOL)includeMetadataChanges {
  FIRSnapshotListenOptions *newOptions =
      [[FIRSnapshotListenOptions alloc] initPrivateWithSource:self.source
                                       includeMetadataChanges:includeMetadataChanges];
  return newOptions;
}

- (FIRSnapshotListenOptions *)withSource:(FIRListenSource)source {
  FIRSnapshotListenOptions *newOptions =
      [[FIRSnapshotListenOptions alloc] initPrivateWithSource:source
                                       includeMetadataChanges:self.includeMetadataChanges];
  return newOptions;
}

@end

NS_ASSUME_NONNULL_END
