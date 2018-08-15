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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H

#include <memory>
#include <utility>

#include <grpcpp/client_context.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace internal {
class GrpcStreamDelegate;
}

class GrpcOperationsObserver;

class GrpcStream : public std::enable_shared_from_this<GrpcStream> {
 public:
  GrpcStream(std::unique_ptr<grpc::ClientContext> context,
             std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
             GrpcOperationsObserver* observer,
             GrpcCompletionQueue* grpc_queue);

  void Start();
  void Write(grpc::ByteBuffer&& buffer);
  void Finish();
  void WriteAndFinish(grpc::ByteBuffer&& buffer);

 private:
  friend class internal::GrpcStreamDelegate;

  void Read();
  void BufferedWrite(grpc::ByteBuffer&& message);

  void OnStart();
  void OnRead(const grpc::ByteBuffer& message);
  void OnWrite();
  void OnOperationFailed();
  void OnFinishedWithServerError(const grpc::Status& status);

  bool SameGeneration() const;

  template <typename Op, typename... Args>
  Op* MakeOperation(Args... args);

  template <typename Op, typename... Args>
  void Execute(Args... args) {
    MakeOperation<Op>(args...)->Execute();
  }

  std::unique_ptr<grpc::ClientContext> context_;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;
  GrpcCompletionQueue* grpc_queue_ = nullptr;

  GrpcOperationsObserver* observer_ = nullptr;
  int generation_ = -1;
  absl::optional<BufferedWriter> buffered_writer_;

  bool write_and_finish_ = false;

  // For sanity checks
  bool is_started_ = false;
  bool has_pending_read_ = false;
};

namespace internal {

class GrpcStreamDelegate {
 public:
  explicit GrpcStreamDelegate(std::shared_ptr<GrpcStream>&& stream)
      : stream_{std::move(stream)} {
  }

  void OnStart() {
    stream_->OnStart();
  }
  void OnRead(const grpc::ByteBuffer& message) {
    stream_->OnRead(message);
  }
  void OnWrite() {
    stream_->OnWrite();
  }
  void OnOperationFailed() {
    stream_->OnOperationFailed();
  }
  void OnFinishedWithServerError(const grpc::Status& status) {
    stream_->OnFinishedWithServerError(status);
  }

 private:
  // TODO: explain ownership
  std::shared_ptr<GrpcStream> stream_;
};

} // internal

template <typename Op, typename... Args>
Op* GrpcStream::MakeOperation(Args... args) {
  return new Op{internal::GrpcStreamDelegate{shared_from_this()}, call_.get(),
                grpc_queue_, std::move(args)...};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H
