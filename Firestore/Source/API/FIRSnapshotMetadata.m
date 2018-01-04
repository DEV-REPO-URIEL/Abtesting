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

#import <FirebaseFirestore/FIRSnapshotMetadata.h>

#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRSnapshotMetadata ()

- (instancetype)initWithPendingWrites:(BOOL)pendingWrites fromCache:(BOOL)fromCache;

@end

@implementation FIRSnapshotMetadata (Internal)

+ (instancetype)snapshotMetadataWithPendingWrites:(BOOL)pendingWrites fromCache:(BOOL)fromCache {
  return [[FIRSnapshotMetadata alloc] initWithPendingWrites:pendingWrites fromCache:fromCache];
}

@end

@implementation FIRSnapshotMetadata

- (instancetype)initWithPendingWrites:(BOOL)pendingWrites fromCache:(BOOL)fromCache {
  if (self = [super init]) {
    _pendingWrites = pendingWrites;
    _fromCache = fromCache;
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
