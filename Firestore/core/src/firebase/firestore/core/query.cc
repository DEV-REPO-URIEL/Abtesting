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

#include "Firestore/core/src/firebase/firestore/core/query.h"

#include <algorithm>

#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/equality.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace core {
namespace {

using Operator = Filter::Operator;
using Type = Filter::Type;

using model::Document;
using model::DocumentKey;
using model::FieldPath;
using model::ResourcePath;

template <typename T>
std::vector<T> AppendingTo(const std::vector<T>& vector, T&& value) {
  std::vector<T> updated = vector;
  updated.push_back(std::forward<T>(value));
  return updated;
}

}  // namespace

Query::Query(ResourcePath path, std::string collection_group)
    : path_(std::move(path)),
      collection_group_(
          std::make_shared<const std::string>(std::move(collection_group))) {
}

// MARK: - Accessors

bool Query::IsDocumentQuery() const {
  return DocumentKey::IsDocumentKey(path_) && !collection_group_ &&
         filters_.empty();
}

const FieldPath* Query::InequalityFilterField() const {
  for (const auto& filter : filters_) {
    if (filter->IsInequality()) {
      return &filter->field();
    }
  }
  return nullptr;
}

bool Query::HasArrayContainsFilter() const {
  for (const auto& filter : filters_) {
    if (filter->IsAFieldFilter()) {
      const auto& relation_filter = static_cast<const FieldFilter&>(*filter);
      if (relation_filter.op() == Operator::ArrayContains) {
        return true;
      }
    }
  }
  return false;
}

const Query::OrderByList& Query::order_bys() const {
  if (memoized_order_bys_.empty()) {
    const FieldPath* inequality_field = InequalityFilterField();
    const FieldPath* first_order_by_field = FirstOrderByField();
    if (inequality_field && !first_order_by_field) {
      // In order to implicitly add key ordering, we must also add the
      // inequality filter field for it to be a valid query. Note that the
      // default inequality field and key ordering is ascending.
      if (inequality_field->IsKeyFieldPath()) {
        memoized_order_bys_.emplace_back(FieldPath::KeyFieldPath(),
                                         Direction::Ascending);
      } else {
        memoized_order_bys_.emplace_back(*inequality_field,
                                         Direction::Ascending);
        memoized_order_bys_.emplace_back(FieldPath::KeyFieldPath(),
                                         Direction::Ascending);
      }
    } else {
      HARD_ASSERT(
          !inequality_field || *inequality_field == *first_order_by_field,
          "First orderBy %s should match inequality field %s.",
          first_order_by_field->CanonicalString(),
          inequality_field->CanonicalString());

      bool found_key_order = false;

      Query::OrderByList result;
      for (const OrderBy& order_by : explicit_order_bys_) {
        result.push_back(order_by);
        if (order_by.field().IsKeyFieldPath()) {
          found_key_order = true;
        }
      }

      if (!found_key_order) {
        // The direction of the implicit key ordering always matches the
        // direction of the last explicit sort order
        Direction last_direction = explicit_order_bys_.size() > 0
                                       ? explicit_order_bys_.back().direction()
                                       : Direction::Ascending;
        result.emplace_back(FieldPath::KeyFieldPath(), last_direction);
      }

      memoized_order_bys_ = std::move(result);
    }
  }
  return memoized_order_bys_;
}

const FieldPath* Query::FirstOrderByField() const {
  if (explicit_order_bys_.empty()) {
    return nullptr;
  }

  return &explicit_order_bys_.front().field();
}

// MARK: - Builder methods

Query Query::AddingFilter(std::shared_ptr<Filter> filter) const {
  HARD_ASSERT(!IsDocumentQuery(), "No filter is allowed for document query");

  const FieldPath* new_inequality_field = nullptr;
  if (filter->IsInequality()) {
    new_inequality_field = &filter->field();
  }
  const FieldPath* query_inequality_field = InequalityFilterField();
  HARD_ASSERT(!query_inequality_field || !new_inequality_field ||
                  *query_inequality_field == *new_inequality_field,
              "Query must only have one inequality field.");

  // TODO(rsgowman): ensure first orderby must match inequality field

  return Query(path_, collection_group_,
               AppendingTo(filters_, std::move(filter)), explicit_order_bys_);
}

Query Query::AddingOrderBy(OrderBy order_by) const {
  HARD_ASSERT(!IsDocumentQuery(), "No ordering is allowed for document query");

  if (explicit_order_bys_.empty()) {
    const FieldPath* inequality = InequalityFilterField();
    HARD_ASSERT(inequality == nullptr || *inequality == order_by.field(),
                "First OrderBy must match inequality field.");
  }

  return Query(path_, collection_group_, filters_,
               AppendingTo(explicit_order_bys_, std::move(order_by)));
}

Query Query::AsCollectionQueryAtPath(ResourcePath path) const {
  return Query(path, /*collection_group=*/nullptr, filters_,
               explicit_order_bys_);
}

// MARK: - Matching

bool Query::Matches(const Document& doc) const {
  return MatchesPath(doc) && MatchesOrderBy(doc) && MatchesFilters(doc) &&
         MatchesBounds(doc);
}

bool Query::MatchesPath(const Document& doc) const {
  const ResourcePath& doc_path = doc.key().path();
  if (DocumentKey::IsDocumentKey(path_)) {
    return path_ == doc_path;
  } else {
    return path_.IsPrefixOf(doc_path) && path_.size() == doc_path.size() - 1;
  }
}

bool Query::MatchesFilters(const Document& doc) const {
  return std::all_of(filters_.begin(), filters_.end(),
                     [&](const std::shared_ptr<Filter>& filter) {
                       return filter->Matches(doc);
                     });
}

bool Query::MatchesOrderBy(const Document&) const {
  // TODO(rsgowman): Implement this correctly.
  return true;
}

bool Query::MatchesBounds(const Document&) const {
  // TODO(rsgowman): Implement this correctly.
  return true;
}

bool operator==(const Query& lhs, const Query& rhs) {
  return lhs.path() == rhs.path() &&
         util::Equals(lhs.collection_group(), rhs.collection_group()) &&
         absl::c_equal(lhs.filters(), rhs.filters(),
                       util::Equals<std::shared_ptr<const Filter>>) &&
         lhs.order_bys() == rhs.order_bys();
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
