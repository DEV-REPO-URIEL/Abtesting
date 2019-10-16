/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_APPLE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_APPLE_H_

#include <string>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/base/attributes.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Default failure handler for ObjC/Swift. Typically shouldn't be used
 * directly.
 */
ABSL_ATTRIBUTE_NORETURN void ObjcAssertionHandler(const char* file,
                                                  const char* func,
                                                  const int line,
                                                  const std::string& message);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_HARD_ASSERT_APPLE_H_
