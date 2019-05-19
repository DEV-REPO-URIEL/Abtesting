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

#include "Firestore/core/src/firebase/firestore/model/field_value.h"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <memory>
#include <new>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "absl/memory/memory.h"
#include "absl/strings/escaping.h"
#include "absl/types/variant.h"

namespace firebase {
namespace firestore {
namespace model {

using BaseValue = FieldValue::BaseValue;
using Type = FieldValue::Type;

using util::Compare;
using util::ComparisonResult;

template <typename T>
static const T& Cast(const std::shared_ptr<BaseValue>& rep) {
  return *static_cast<T*>(rep.get());
}

template <typename T>
static const T& Cast(const BaseValue& rep) {
  return static_cast<const T&>(rep);
}

ComparisonResult FieldValue::BaseValue::CompareTypes(
    const BaseValue& other) const {
  Type this_type = type();
  Type other_type = other.type();

  // This does not necessarily mean the types are actually the same. For those
  // types that allow mixed types they'll need to handle this further.
  if (FieldValue::Comparable(this_type, other_type)) {
    return ComparisonResult::Same;
  }

  // Otherwise, the types themselves are defined in order.
  return Compare(this_type, other_type);
}

class NullValue : public FieldValue::BaseValue {
 public:
  Type type() const override {
    return Type::Null;
  }

  std::string ToString() const override {
    return util::ToString(nullptr);
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    // Null is only comparable with itself and is defined to be the same.
    return ComparisonResult::Same;
  }

  size_t Hash() const override {
    // std::hash is not defined for nullptr_t.
    return util::Hash(static_cast<void*>(nullptr));
  }
};

template <Type type_enum, typename ValueType>
class SimpleFieldValue : public FieldValue::BaseValue {
 public:
  explicit SimpleFieldValue(ValueType value) : value_(std::move(value)) {
  }

  Type type() const override {
    return type_enum;
  }

  std::string ToString() const override {
    return util::ToString(value_);
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    return Compare(value_, Cast<SimpleFieldValue>(other).value());
  }

  size_t Hash() const override {
    return util::Hash(value_);
  }

  const ValueType& value() const {
    return value_;
  }

 private:
  ValueType value_;
};

class BooleanValue : public SimpleFieldValue<Type::Boolean, bool> {
 public:
  using SimpleFieldValue<Type::Boolean, bool>::SimpleFieldValue;
};

template <Type type_enum, typename ValueType>
class NumberValue : public SimpleFieldValue<type_enum, ValueType> {
 public:
  using SimpleFieldValue<type_enum, ValueType>::SimpleFieldValue;

  ComparisonResult CompareTo(const BaseValue& other) const override;
};

class IntegerValue : public NumberValue<Type::Integer, int64_t> {
 public:
  using NumberValue<Type::Integer, int64_t>::NumberValue;
};

class DoubleValue : public NumberValue<Type::Double, double> {
 public:
  using NumberValue<Type::Double, double>::NumberValue;
};

template <Type type_enum, typename ValueType>
ComparisonResult NumberValue<type_enum, ValueType>::CompareTo(
    const BaseValue& other) const {
  ComparisonResult cmp = this->CompareTypes(other);
  if (!util::Same(cmp)) return cmp;

  Type this_type = this->type();
  Type other_type = other.type();

  if (this_type == Type::Integer) {
    int64_t this_value = Cast<IntegerValue>(*this).value();
    if (other_type == Type::Integer) {
      int64_t other_value = Cast<IntegerValue>(other).value();
      return Compare(this_value, other_value);
    } else {
      double other_value = Cast<DoubleValue>(other).value();
      return util::ReverseOrder(
          util::CompareMixedNumber(other_value, this_value));
    }

  } else {
    double this_value = Cast<DoubleValue>(*this).value();
    if (other_type == Type::Double) {
      double other_value = Cast<DoubleValue>(other).value();
      return Compare(this_value, other_value);
    } else {
      int64_t other_value = Cast<IntegerValue>(other).value();
      return util::CompareMixedNumber(this_value, other_value);
    }
  }
}

class TimestampValue : public BaseValue {
 public:
  explicit TimestampValue(Timestamp value) : value_(value) {
  }

  Type type() const override {
    return Type::Timestamp;
  }

  std::string ToString() const override {
    return util::ToString(value_);
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    if (other.type() == Type::Timestamp) {
      return Compare(value_, Cast<TimestampValue>(other).value_);
    } else {
      return ComparisonResult::Ascending;
    }
  }

  size_t Hash() const override {
    return util::Hash(value().seconds(), value().nanoseconds());
  }

  const Timestamp& value() const {
    return value_;
  }

 private:
  Timestamp value_;
};

class ServerTimestampValue : public FieldValue::BaseValue {
 public:
  ServerTimestampValue(Timestamp local_write_time,
                       absl::optional<FieldValue> previous_value)
      : local_write_time_(local_write_time),
        previous_value_(std::move(previous_value)) {
  }

  explicit ServerTimestampValue(Timestamp local_write_time)
      : ServerTimestampValue(local_write_time, absl::nullopt) {
  }

  Type type() const override {
    return Type::ServerTimestamp;
  }

  std::string ToString() const override {
    std::string time = local_write_time_.ToString();
    return absl::StrCat("ServerTimestamp(local_write_time=", time, ")");
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    if (other.type() == Type::ServerTimestamp) {
      return Compare(local_write_time_,
                     Cast<ServerTimestampValue>(other).local_write_time_);
    } else {
      return ComparisonResult::Descending;
    }
  }

  size_t Hash() const override {
    size_t result = util::Hash(local_write_time_.seconds(),
                               local_write_time_.nanoseconds());

    if (previous_value_) {
      result = util::Hash(result, *previous_value_);
    }
    return result;
  }

 private:
  Timestamp local_write_time_;
  absl::optional<FieldValue> previous_value_;
};

class StringValue : public SimpleFieldValue<Type::String, std::string> {
 public:
  using SimpleFieldValue::SimpleFieldValue;
};

using BlobContents = std::vector<uint8_t>;

class BlobValue : public SimpleFieldValue<Type::Blob, BlobContents> {
 public:
  using SimpleFieldValue::SimpleFieldValue;

  std::string ToString() const override {
    return absl::StrCat("<", absl::BytesToHexString(AsStringView()), ">");
  }

 private:
  absl::string_view AsStringView() const {
    // string_view accepts const char*, but treats it internally as unsigned.
    const BlobContents& contents = value();
    auto data = reinterpret_cast<const char*>(contents.data());
    return {data, contents.size()};
  }
};

class ReferenceValue : public FieldValue::BaseValue {
 public:
  ReferenceValue(DatabaseId database_id, DocumentKey key)
      : database_id_(std::move(database_id)), key_(std::move(key)) {
  }

  Type type() const override {
    return Type::Reference;
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    auto& other_value = Cast<ReferenceValue>(other);
    cmp = Compare(database_id_, other_value.database_id_);
    if (!util::Same(cmp)) return cmp;

    return Compare(key_, other_value.key_);
  }

  std::string ToString() const override {
    return absl::StrCat("Reference(key=", key_.ToString(), ")");
  }

  size_t Hash() const override {
    return util::Hash(database_id_, key_);
  }

 private:
  DatabaseId database_id_;
  DocumentKey key_;
};

class GeoPointValue : public BaseValue {
 public:
  explicit GeoPointValue(GeoPoint value) : value_(value) {
  }

  Type type() const override {
    return Type::GeoPoint;
  }

  std::string ToString() const override {
    return util::ToString(value_);
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    auto& other_value = Cast<GeoPointValue>(other);
    return Compare(value_, other_value.value_);
  }

  size_t Hash() const override {
    return util::Hash(value_.latitude(), value_.longitude());
  }

  const GeoPoint& value() const {
    return value_;
  }

 private:
  GeoPoint value_;
};

class ArrayContents : public FieldValue::BaseValue {
 public:
  explicit ArrayContents(FieldValue::Array value) : value_(std::move(value)) {
  }

  Type type() const override {
    return Type::Array;
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    auto& other_value = Cast<ArrayContents>(other);
    return util::CompareContainer(value_, other_value.value_);
  }

  std::string ToString() const override {
    return util::ToString(value_);
  }

  size_t Hash() const override {
    return util::Hash(value_);
  }

  const FieldValue::Array& value() const {
    return value_;
  }

 private:
  FieldValue::Array value_;
};

class MapContents : public FieldValue::BaseValue {
 public:
  explicit MapContents(FieldValue::Map value) : value_(std::move(value)) {
  }

  Type type() const override {
    return Type::Object;
  }

  ComparisonResult CompareTo(const BaseValue& other) const override {
    ComparisonResult cmp = CompareTypes(other);
    if (!util::Same(cmp)) return cmp;

    auto& other_value = Cast<MapContents>(other);
    return util::CompareContainer(value_, other_value.value_);
  }

  std::string ToString() const override {
    return util::ToString(value_);
  }

  size_t Hash() const override {
    size_t result = 0;
    for (auto&& entry : value_) {
      result = util::Hash(result, entry.first, entry.second);
    }
    return result;
  }

  const FieldValue::Map& value() const {
    return value_;
  }

 private:
  FieldValue::Map value_;
};

#if 0
union {
  // There is no null type as tag_ alone is enough for Null FieldValue.
  bool boolean_value_;
  int64_t integer_value_;
  double double_value_;
  std::unique_ptr<Timestamp> timestamp_value_;
  std::unique_ptr<ServerTimestamp> server_timestamp_value_;
  // TODO(rsgowman): Change unique_ptr<std::string> to nanopb::String?
  std::unique_ptr<std::string> string_value_;
  std::unique_ptr<std::vector<uint8_t>> blob_value_;
  std::unique_ptr<ReferenceValue> reference_value_;
  std::unique_ptr<GeoPoint> geo_point_value_;
  std::unique_ptr<std::vector<FieldValue>> array_value_;
  std::unique_ptr<Map> object_value_;
};
#endif

FieldValue::FieldValue() : FieldValue(std::make_shared<NullValue>()) {
}

bool FieldValue::Comparable(Type lhs, Type rhs) {
  switch (lhs) {
    case Type::Integer:
    case Type::Double:
      return rhs == Type::Integer || rhs == Type::Double;
    case Type::Timestamp:
    case Type::ServerTimestamp:
      return rhs == Type::Timestamp || rhs == Type::ServerTimestamp;
    default:
      return lhs == rhs;
  }
}

bool FieldValue::boolean_value() const {
  HARD_ASSERT(type() == Type::Boolean);
  return Cast<BooleanValue>(rep_).value();
}

int64_t FieldValue::integer_value() const {
  HARD_ASSERT(type() == Type::Integer);
  return Cast<IntegerValue>(rep_).value();
}

double FieldValue::double_value() const {
  HARD_ASSERT(type() == Type::Double);
  return Cast<DoubleValue>(rep_).value();
}

Timestamp FieldValue::timestamp_value() const {
  HARD_ASSERT(type() == Type::Timestamp);
  return Cast<TimestampValue>(rep_).value();
}

const std::string& FieldValue::string_value() const {
  HARD_ASSERT(type() == Type::String);
  return Cast<StringValue>(rep_).value();
}

const std::vector<uint8_t>& FieldValue::blob_value() const {
  HARD_ASSERT(type() == Type::Blob);
  return Cast<BlobValue>(rep_).value();
}

const GeoPoint& FieldValue::geo_point_value() const {
  HARD_ASSERT(type() == Type::GeoPoint);
  return Cast<GeoPointValue>(rep_).value();
}

const FieldValue::Array& FieldValue::array_value() const {
  HARD_ASSERT(type() == Type::Array);
  return Cast<ArrayContents>(rep_).value();
}

const FieldValue::Map& FieldValue::object_value() const {
  HARD_ASSERT(type() == Type::Object);
  return Cast<MapContents>(rep_).value();
}

// TODO(rsgowman): Reorder this file to match its header.
ObjectValue ObjectValue::Set(const FieldPath& field_path,
                             const FieldValue& value) const {
  HARD_ASSERT(!field_path.empty(),
              "Cannot set field for empty path on FieldValue");
  // Set the value by recursively calling on child object.
  const std::string& child_name = field_path.first_segment();
  if (field_path.size() == 1) {
    return SetChild(child_name, value);
  } else {
    ObjectValue child = ObjectValue::Empty();
    const FieldValue::Map& entries = fv_.object_value();
    const auto iter = entries.find(child_name);
    if (iter != entries.end() && iter->second.type() == Type::Object) {
      child = ObjectValue(iter->second);
    }
    ObjectValue new_child = child.Set(field_path.PopFirst(), value);
    return SetChild(child_name, new_child.fv_);
  }
}

ObjectValue ObjectValue::Delete(const FieldPath& field_path) const {
  HARD_ASSERT(!field_path.empty(),
              "Cannot delete field for empty path on FieldValue");
  // Delete the value by recursively calling on child object.
  const std::string& child_name = field_path.first_segment();
  if (field_path.size() == 1) {
    return ObjectValue::FromMap(fv_.object_value().erase(child_name));
  } else {
    const FieldValue::Map& entries = fv_.object_value();
    const auto iter = entries.find(child_name);
    if (iter != entries.end() && iter->second.type() == Type::Object) {
      ObjectValue new_child =
          ObjectValue(iter->second).Delete(field_path.PopFirst());
      return SetChild(child_name, new_child.fv_);
    } else {
      // If the found value isn't an object, it cannot contain the remaining
      // segments of the path. We don't actually change a primitive value to
      // an object for a delete.
      return *this;
    }
  }
}

absl::optional<FieldValue> ObjectValue::Get(const FieldPath& field_path) const {
  const FieldValue* current = &this->fv_;
  for (const auto& path : field_path) {
    if (current->type() != Type::Object) {
      return absl::nullopt;
    }

    const FieldValue::Map& entries = current->object_value();
    const auto iter = entries.find(path);
    if (iter == entries.end()) {
      return absl::nullopt;
    } else {
      current = &iter->second;
    }
  }
  return *current;
}

ObjectValue ObjectValue::SetChild(const std::string& child_name,
                                  const FieldValue& value) const {
  return ObjectValue::FromMap(fv_.object_value().insert(child_name, value));
}

FieldValue FieldValue::Null() {
  return FieldValue();
}

FieldValue FieldValue::True() {
  return FieldValue(std::make_shared<BooleanValue>(true));
}

FieldValue FieldValue::False() {
  return FieldValue(std::make_shared<BooleanValue>(false));
}

FieldValue FieldValue::FromBoolean(bool value) {
  return value ? True() : False();
}

FieldValue FieldValue::Nan() {
  return FieldValue::FromDouble(NAN);
}

FieldValue FieldValue::EmptyObject() {
  return FieldValue::FromMap(FieldValue::Map());
}

FieldValue FieldValue::FromInteger(int64_t value) {
  return FieldValue(std::make_shared<IntegerValue>(value));
}

FieldValue FieldValue::FromDouble(double value) {
  return FieldValue(std::make_shared<DoubleValue>(value));
}

FieldValue FieldValue::FromTimestamp(const Timestamp& value) {
  return FieldValue(std::make_shared<TimestampValue>(value));
}

FieldValue FieldValue::FromServerTimestamp(const Timestamp& local_write_time,
                                           const FieldValue& previous_value) {
  return FieldValue(
      std::make_shared<ServerTimestampValue>(local_write_time, previous_value));
}

FieldValue FieldValue::FromServerTimestamp(const Timestamp& local_write_time) {
  return FieldValue(std::make_shared<ServerTimestampValue>(local_write_time));
}

FieldValue FieldValue::FromString(const char* value) {
  return FieldValue(std::make_shared<StringValue>(value));
}

FieldValue FieldValue::FromString(const std::string& value) {
  return FieldValue(std::make_shared<StringValue>(value));
}

FieldValue FieldValue::FromString(std::string&& value) {
  return FieldValue(std::make_shared<StringValue>(std::move(value)));
}

FieldValue FieldValue::FromBlob(const uint8_t* source, size_t size) {
  std::vector<uint8_t> copy(source, source + size);
  return FieldValue(std::make_shared<BlobValue>(std::move(copy)));
}

FieldValue FieldValue::FromReference(DatabaseId database_id, DocumentKey key) {
  return FieldValue(
      std::make_shared<ReferenceValue>(std::move(database_id), std::move(key)));
}

FieldValue FieldValue::FromGeoPoint(const GeoPoint& value) {
  return FieldValue(std::make_shared<GeoPointValue>(value));
}

FieldValue FieldValue::FromArray(const Array& value) {
  return FieldValue(std::make_shared<ArrayContents>(value));
}

FieldValue FieldValue::FromArray(Array&& value) {
  return FieldValue(std::make_shared<ArrayContents>(std::move(value)));
}

FieldValue FieldValue::FromMap(const Map& value) {
  return FieldValue(std::make_shared<MapContents>(value));
}

FieldValue FieldValue::FromMap(FieldValue::Map&& value) {
  return FieldValue(std::make_shared<MapContents>(std::move(value)));
}

std::ostream& operator<<(std::ostream& os, const FieldValue& value) {
  return os << value.ToString();
}

ObjectValue ObjectValue::FromMap(const FieldValue::Map& value) {
  return ObjectValue(FieldValue::FromMap(value));
}

ObjectValue ObjectValue::FromMap(FieldValue::Map&& value) {
  return ObjectValue(FieldValue::FromMap(std::move(value)));
}

ComparisonResult ObjectValue::CompareTo(const ObjectValue& rhs) const {
  return fv_.CompareTo(rhs.fv_);
}

const FieldValue::Map& ObjectValue::GetInternalValue() const {
  return fv_.object_value();
}

std::string ObjectValue::ToString() const {
  return fv_.ToString();
}

std::ostream& operator<<(std::ostream& os, const ObjectValue& value) {
  return os << value.ToString();
}

size_t ObjectValue::Hash() const {
  return fv_.Hash();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
