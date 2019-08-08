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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SET_MUTATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SET_MUTATION_H_

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * A mutation that creates or replaces the document at the given key with the
 * object value contents.
 */
class SetMutation : public Mutation {
 public:
  SetMutation(DocumentKey&& key,
              ObjectValue&& value,
              Precondition&& precondition);

  Type type() const override {
    return Mutation::Type::Set;
  }

  MaybeDocument ApplyToRemoteDocument(
      const absl::optional<MaybeDocument>& maybe_doc,
      const MutationResult& mutation_result) const override;

  absl::optional<MaybeDocument> ApplyToLocalView(
      const absl::optional<MaybeDocument>& maybe_doc,
      const absl::optional<MaybeDocument>& base_doc,
      const Timestamp& local_write_time) const override;

  /** Returns the object value to use when setting the document. */
  const ObjectValue& value() const {
    return value_;
  }

 protected:
  bool equal_to(const Mutation& other) const override;

 private:
  const ObjectValue value_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_SET_MUTATION_H_
