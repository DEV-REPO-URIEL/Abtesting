/*
 * Copyright 2024 Google LLC
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, FIRListenSource) {
  FIRListenSourceDefault,
  FIRListenSourceCache
} NS_SWIFT_NAME(ListenSource);

NS_SWIFT_NAME(SnapshotListenOptions)
@interface FIRSnapshotListenOptions : NSObject

@property(nonatomic, readonly) FIRListenSource source;
@property(nonatomic, readonly) BOOL includeMetadataChanges;

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (FIRSnapshotListenOptions *)optionsWithIncludeMetadataChanges:(BOOL)includeMetadataChanges;
- (FIRSnapshotListenOptions *)optionsWithSource:(FIRListenSource)source;

@end

NS_ASSUME_NONNULL_END
