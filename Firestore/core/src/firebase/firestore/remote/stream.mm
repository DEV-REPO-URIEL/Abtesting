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

#include "Firestore/core/src/firebase/firestore/remote/stream.h"

#include <chrono>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::Token;
using util::AsyncQueue;
using util::TimerId;
using util::Status;
using util::StatusOr;
using util::StringFormat;

namespace {

/**
 * Initial backoff time after an error.
 * Set to 1s according to https://cloud.google.com/apis/design/errors.
 */
const double kBackoffFactor = 1.5;
const AsyncQueue::Milliseconds kBackoffInitialDelay{std::chrono::seconds(1)};
const AsyncQueue::Milliseconds kBackoffMaxDelay{std::chrono::seconds(60)};
/** The time a stream stays open after it is marked idle. */
const AsyncQueue::Milliseconds kIdleTimeout{std::chrono::seconds(60)};

}  // namespace

Stream::Stream(AsyncQueue* worker_queue,
               CredentialsProvider* credentials_provider,
               Datastore* datastore,
               TimerId backoff_timer_id,
               TimerId idle_timer_id)
    : worker_queue_{worker_queue},
      credentials_provider_{credentials_provider},
      datastore_{datastore},
      backoff_{worker_queue, backoff_timer_id, kBackoffFactor,
               kBackoffInitialDelay, kBackoffMaxDelay},
      idle_timer_id_{idle_timer_id} {
}

// Starting

void Stream::Start() {
  EnsureOnQueue();

  if (state_ == State::Error) {
    BackoffAndTryRestarting();
    return;
  }

  LOG_DEBUG("%s start", GetDebugDescription());

  HARD_ASSERT(state_ == State::Initial, "Already started");
  state_ = State::Starting;

  Authenticate();
}

void Stream::Authenticate() {
  EnsureOnQueue();

  // Auth may outlive the stream, so make sure it doesn't try to access a
  // deleted object.
  std::weak_ptr<Stream> weak_this{shared_from_this()};
  int auth_generation = generation_;
  credentials_provider_->GetToken(
      [weak_this, auth_generation](StatusOr<Token> maybe_token) {
        auto strong_this = weak_this.lock();
        if (!strong_this) {
          return;
        }
        strong_this->worker_queue_->EnqueueRelaxed(
            [maybe_token, weak_this, auth_generation] {
              auto strong_this = weak_this.lock();
              // Streams can be stopped while waiting for authorization, so need
              // to check generation.
              if (!strong_this || strong_this->generation_ != auth_generation) {
                return;
              }
              strong_this->ResumeStartAfterAuth(maybe_token);
            });
      });
}

void Stream::ResumeStartAfterAuth(const StatusOr<Token>& maybe_token) {
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::Starting,
              "State should still be 'Starting' (was %s)", state_);

  if (!maybe_token.ok()) {
    OnStreamError(maybe_token.status());
    return;
  }

  absl::string_view token = [&] {
    auto token = maybe_token.ValueOrDie();
    return token.user().is_authenticated() ? token.token()
                                           : absl::string_view{};
  }();

  grpc_stream_ = CreateGrpcStream(datastore_, token);
  grpc_stream_->Start();
}

void Stream::OnStreamStart() {
  EnsureOnQueue();

  state_ = State::Open;
  DoOnStreamStart();
}

// Backoff

void Stream::BackoffAndTryRestarting() {
  EnsureOnQueue();

  LOG_DEBUG("%s backoff", GetDebugDescription());

  HARD_ASSERT(state_ == State::Error,
              "Should only perform backoff in an error case");

  state_ = State::Backoff;
  backoff_.BackoffAndRun([this] { ResumeStartFromBackoff(); });
}

void Stream::ResumeStartFromBackoff() {
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::Backoff, "Backoff elapsed but state is now: %s",
              state_);

  state_ = State::Initial;
  Start();
  HARD_ASSERT(IsStarted(), "Stream should have started.");
}

void Stream::InhibitBackoff() {
  EnsureOnQueue();

  HARD_ASSERT(!IsStarted(),
              "Can only cancel backoff in a stopped state (was %s)", state_);

  // Clear the error condition.
  state_ = State::Initial;
  ResetBackoff();
}

void Stream::ResetBackoff() {
  EnsureOnQueue();
  backoff_.Reset();
}

// Idleness

void Stream::MarkIdle() {
  EnsureOnQueue();

  if (IsOpen() && !idleness_timer_) {
    idleness_timer_ = worker_queue_->EnqueueAfterDelay(
        kIdleTimeout, idle_timer_id_, [this] { Stop(); });
  }
}

void Stream::CancelIdleCheck() {
  EnsureOnQueue();
  idleness_timer_.Cancel();
}

// Read/write

void Stream::OnStreamRead(const grpc::ByteBuffer& message) {
  EnsureOnQueue();

  HARD_ASSERT(IsStarted(), "OnStreamRead called for a stopped stream.");

  if (bridge::IsLoggingEnabled()) {
    LOG_DEBUG("%s headers (whitelisted): %s", GetDebugDescription(),
              Datastore::GetWhitelistedHeadersAsString(
                  grpc_stream_->GetResponseHeaders()));
  }

  Status read_status = DoOnStreamRead(message);
  if (!read_status.ok()) {
    grpc_stream_->Finish();
    // Don't expect GRPC to produce status -- since the error happened on the
    // client, we have all the information we need.
    OnStreamError(read_status);
    return;
  }
}

// Stopping

void Stream::Stop() {
  EnsureOnQueue();

  LOG_DEBUG("%s stop", GetDebugDescription());

  if (!IsStarted()) {
    return;
  }

  RaiseGeneration();

  // If the stream is in the auth stage, GRPC stream might not have been created
  // yet.
  if (grpc_stream_) {
    LOG_DEBUG("%s Finishing GRPC stream", GetDebugDescription());
    FinishGrpcStream(grpc_stream_.get());
    ResetGrpcStream();
  }

  // If this is an intentional close ensure we don't delay our next connection
  // attempt.
  ResetBackoff();

  // State must be updated before calling the delegate.
  state_ = State::Initial;
  // Stopping the stream was initiated by the client, so we have all the
  // information we need.
  DoOnStreamFinish(Status::OK());
}

void Stream::OnStreamError(const Status& status) {
  EnsureOnQueue();

  // TODO(varconst): log error here?
  LOG_DEBUG("%s Stream error", GetDebugDescription());

  RaiseGeneration();

  if (status.code() == FirestoreErrorCode::ResourceExhausted) {
    LOG_DEBUG(
        "%s Using maximum backoff delay to prevent overloading the backend.",
        GetDebugDescription());
    backoff_.ResetToMax();
  } else if (status.code() == FirestoreErrorCode::Unauthenticated) {
    // "unauthenticated" error means the token was rejected. Try force
    // refreshing it in case it just expired.
    credentials_provider_->InvalidateToken();
  }

  ResetGrpcStream();

  // State must be updated before calling the delegate.
  state_ = State::Error;
  DoOnStreamFinish(status);
}

void Stream::ResetGrpcStream() {
  EnsureOnQueue();

  grpc_stream_.reset();
  backoff_.Cancel();
}

// Check state

bool Stream::IsOpen() const {
  EnsureOnQueue();
  return state_ == State::Open;
}

bool Stream::IsStarted() const {
  EnsureOnQueue();
  return state_ == State::Starting || state_ == State::Backoff || IsOpen();
}

// Protected helpers

void Stream::EnsureOnQueue() const {
  worker_queue_->VerifyIsCurrentQueue();
}

void Stream::Write(grpc::ByteBuffer&& message) {
  EnsureOnQueue();

  HARD_ASSERT(IsOpen(), "Cannot write when the stream is not open.");

  CancelIdleCheck();
  grpc_stream_->Write(std::move(message));
}

std::string Stream::GetDebugDescription() const {
  EnsureOnQueue();
  return StringFormat("%s (%s)", GetDebugName(), this);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
