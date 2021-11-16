/*
 * Copyright 2021 Google LLC
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
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_slice.h"

#import "GRPCSwiftShim/GRPCSwiftShim-Swift.h"

#include <Foundation/Foundation.h>

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

Slice::Slice(const void* buf, size_t len) {
  shim_ = [[GRPCSliceShim alloc] init:buf len:len];
}
Slice::Slice(const std::string& s) {
  shim_ = [[GRPCSliceShim alloc] init:s];
}
size_t Slice::size() const {
  return shim_.size();
}
const uint8_t* Slice::begin() const {
  return shim_.begin();
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
