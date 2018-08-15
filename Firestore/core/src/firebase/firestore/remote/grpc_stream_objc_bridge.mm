/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream_objc_bridge.h"

#include <utility>

#import "Firestore/Source/Remote/FSTStream.h"

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

#include <vector>

namespace firebase {
namespace firestore {

using model::SnapshotVersion;

namespace remote {
namespace bridge {

namespace {

NSData* ToNsData(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  const grpc::Status status = buffer.Dump(&slices);
  HARD_ASSERT(status.ok(), "Trying to convert a corrupted grpc::ByteBuffer");

  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    NSMutableData* data = [NSMutableData dataWithCapacity:buffer.Length()];
    for (const auto& slice : slices) {
      [data appendBytes:slice.begin() length:slice.size()];
    }
    return data;
  }
}

template <typename Proto>
Proto* ToProto(const grpc::ByteBuffer& message, std::string* out_error) {
  NSError* error;
  // NSMutableData* bad = [NSMutableData dataWithData:;
  // [bad appendBytes:"OBC" length:2];
  // auto* proto = [Proto parseFromData:bad error:&error];
  auto* proto = [Proto parseFromData:ToNsData(message) error:&error];
  // FIXME OBC
  if (error) {
    NSDictionary* info = @{
      NSLocalizedDescriptionKey : @"Unable to parse response from the server",
      NSUnderlyingErrorKey : error,
      @"Expected class" : [Proto class],
      @"Received value" : ToNsData(message),
    };
    *out_error = util::MakeString([info description]);

    return nil;
  }
  return proto;
}

grpc::ByteBuffer ConvertToByteBuffer(NSData* data) {
  const grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

}  // namespace

grpc::ByteBuffer WatchStreamSerializer::ToByteBuffer(
    FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];

  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WatchStreamSerializer::ToByteBuffer(
    FSTTargetID target_id) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.removeTarget = target_id;

  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WriteStreamSerializer::CreateHandshake() const {
  // The initial request cannot contain mutations, but must contain a projectID.
  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.database = [serializer_ encodedDatabaseID];
  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WriteStreamSerializer::ToByteBuffer(
    NSArray<FSTMutation*>* mutations) {
  NSMutableArray<GCFSWrite*>* protos =
      [NSMutableArray arrayWithCapacity:mutations.count];
  for (FSTMutation* mutation in mutations) {
    [protos addObject:[serializer_ encodedMutation:mutation]];
  };

  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.writesArray = protos;
  request.streamToken = last_stream_token_;

  return ConvertToByteBuffer([request data]);
}

FSTWatchChange* WatchStreamSerializer::ToWatchChange(
    GCFSListenResponse* proto) const {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion WatchStreamSerializer::ToSnapshotVersion(
    GCFSListenResponse* proto) const {
  return [serializer_ versionFromListenResponse:proto];
}

GCFSListenResponse* WatchStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message, std::string* out_error) const {
  return ToProto<GCFSListenResponse>(message, out_error);
}

void WriteStreamSerializer::UpdateLastStreamToken(
    GCFSWriteResponse* proto) {
  last_stream_token_ = proto.streamToken;
}

model::SnapshotVersion WriteStreamSerializer::ToCommitVersion(
    GCFSWriteResponse* proto) const {
  return [serializer_ decodedVersion:proto.commitTime];
}

NSArray<FSTMutationResult*>* WriteStreamSerializer::ToMutationResults(
    GCFSWriteResponse* proto) const {
  NSMutableArray<GCFSWriteResult*>* protos = proto.writeResultsArray;
  NSMutableArray<FSTMutationResult*>* results =
      [NSMutableArray arrayWithCapacity:protos.count];
  for (GCFSWriteResult* proto in protos) {
    [results addObject:[serializer_ decodedMutationResult:proto]];
  };
  return results;
}

GCFSWriteResponse* WriteStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message, std::string* out_error) const {
  return ToProto<GCFSWriteResponse>(message, out_error);
}

void WatchStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

void WatchStreamDelegate::NotifyDelegateOnChange(
    FSTWatchChange* change, const model::SnapshotVersion& snapshot_version) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:change snapshotVersion:snapshot_version];
}

void WatchStreamDelegate::NotifyDelegateOnStreamFinished(
const util::Status& status) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamWasInterruptedWithError:util::MakeNSError(status)];
}

void WriteStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidOpen];
}

void WriteStreamDelegate::NotifyDelegateOnHandshakeComplete() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidCompleteHandshake];
}

void WriteStreamDelegate::NotifyDelegateOnCommit(
    const SnapshotVersion& commit_version,
    NSArray<FSTMutationResult*>* results) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidReceiveResponseWithVersion:commit_version
                                     mutationResults:results];
}

void WriteStreamDelegate::NotifyDelegateOnStreamFinished(
const util::Status& status) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamWasInterruptedWithError:util::MakeNSError(status)];
}
}
}
}
}
