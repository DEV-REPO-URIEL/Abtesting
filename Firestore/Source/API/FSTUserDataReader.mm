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

#import "Firestore/Source/API/FSTUserDataReader.h"

#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "FIRGeoPoint.h"
#import "FIRTimestamp.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRGeoPoint+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter_legacy.h"
#import "Firestore/Source/API/converters.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/core/user_data.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/field_transform.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/transform_operation.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/timestamp_internal.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/read_context.h"
#include "Firestore/core/src/util/string_apple.h"

#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "absl/types/optional.h"

namespace util = firebase::firestore::util;
namespace nanopb = firebase::firestore::nanopb;
using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::GeoPoint;
using firebase::firestore::core::ParseAccumulator;
using firebase::firestore::core::ParseContext;
using firebase::firestore::core::ParsedSetData;
using firebase::firestore::core::ParsedUpdateData;
using firebase::firestore::core::UserDataSource;
using firebase::firestore::model::ArrayTransform;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldMask;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldTransform;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::NumericIncrementTransform;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::MutableObjectValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ServerTimestampTransform;
using firebase::firestore::model::TransformOperation;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::ThrowInvalidArgument;
using firebase::firestore::util::ReadContext;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::google_firestore_v1_MapValue;
using firebase::firestore::google_firestore_v1_ArrayValue;
using firebase::firestore::google_protobuf_NullValue_NULL_VALUE;
using firebase::firestore::google_firestore_v1_MapValue_FieldsEntry;
using firebase::firestore::google_type_LatLng;
using firebase::firestore::google_protobuf_Timestamp;
using nanopb::StringReader;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDocumentKeyReference

@implementation FSTDocumentKeyReference {
  DocumentKey _key;
  DatabaseId _databaseID;
}

- (instancetype)initWithKey:(DocumentKey)key databaseID:(DatabaseId)databaseID {
  self = [super init];
  if (self) {
    _key = std::move(key);
    _databaseID = std::move(databaseID);
  }
  return self;
}

- (const model::DocumentKey &)key {
  return _key;
}

- (const model::DatabaseId &)databaseID {
  return _databaseID;
}

@end

#pragma mark - FSTUserDataReader

@interface FSTUserDataReader ()
@property(strong, nonatomic, readonly) FSTPreConverterBlock preConverter;
@end

@implementation FSTUserDataReader {
  DatabaseId _databaseID;
  std::unique_ptr<Serializer> _serializer;
}

- (instancetype)initWithDatabaseID:(DatabaseId)databaseID
                      preConverter:(FSTPreConverterBlock)preConverter {
  self = [super init];
  if (self) {
    _databaseID = std::move(databaseID);
    _preConverter = preConverter;
    _serializer.reset(new Serializer{_databaseID});
  }
  return self;
}

// TODO(mutabledocuments): Remove these methods once we remove FieldValue
- (FieldValue)wrapValue:(google_firestore_v1_Value)value {
  ReadContext context;
  return _serializer->DecodeFieldValue(&context, value);
}

- (std::vector<FieldValue>)wrapValues:(const std::vector<google_firestore_v1_Value> &)values {
  std::vector<FieldValue> fieldValues;
  for (const auto &value : values) {
    fieldValues.emplace_back([self wrapValue:value]);
  }
  return fieldValues;
}

- (ObjectValue)wrapObject:(google_firestore_v1_Value)value {
  return ObjectValue{[self wrapValue:value]};
}

- (ParsedSetData)parsedSetData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::Set};
  absl::optional<google_firestore_v1_Value> updateData = [self parseData:input
                                                                 context:accumulator.RootContext()];
  HARD_ASSERT(updateData.has_value(), "Parsed data should not be nil.");

  return std::move(accumulator).SetData([self wrapObject:*updateData]);
}

- (ParsedSetData)parsedMergeData:(id)input fieldMask:(nullable NSArray<id> *)fieldMask {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  ParseAccumulator accumulator{UserDataSource::MergeSet};

  absl::optional<google_firestore_v1_Value> updateData = [self parseData:input
                                                                 context:accumulator.RootContext()];
  HARD_ASSERT(updateData.has_value(), "Parsed data should not be nil.");

  ObjectValue updateObject = [self wrapObject:*updateData];

  if (fieldMask) {
    std::set<FieldPath> validatedFieldPaths;
    for (id fieldPath in fieldMask) {
      FieldPath path;

      if ([fieldPath isKindOfClass:[NSString class]]) {
        path = FieldPath::FromDotSeparatedString(util::MakeString(fieldPath));
      } else if ([fieldPath isKindOfClass:[FIRFieldPath class]]) {
        path = static_cast<FIRFieldPath *>(fieldPath).internalValue;
      } else {
        ThrowInvalidArgument("All elements in mergeFields: must be NSStrings or FIRFieldPaths.");
      }

      // Verify that all elements specified in the field mask are part of the parsed context.
      if (!accumulator.Contains(path)) {
        ThrowInvalidArgument(
            "Field '%s' is specified in your field mask but missing from your input data.",
            path.CanonicalString());
      }

      validatedFieldPaths.insert(path);
    }

    return std::move(accumulator)
        .MergeData(updateObject, FieldMask{std::move(validatedFieldPaths)});

  } else {
    return std::move(accumulator).MergeData(updateObject);
  }
}

- (ParsedUpdateData)parsedUpdateData:(id)input {
  // NOTE: The public API is typed as NSDictionary but we type 'input' as 'id' since we can't trust
  // Obj-C to verify the type for us.
  if (![input isKindOfClass:[NSDictionary class]]) {
    ThrowInvalidArgument("Data to be written must be an NSDictionary.");
  }

  NSDictionary *dict = input;

  ParseAccumulator accumulator{UserDataSource::Update};
  __block ParseContext context = accumulator.RootContext();
  __block MutableObjectValue updateData;

  [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *) {
    FieldPath path;

    if ([key isKindOfClass:[NSString class]]) {
      path = FieldPath::FromDotSeparatedString(util::MakeString(key));
    } else if ([key isKindOfClass:[FIRFieldPath class]]) {
      path = ((FIRFieldPath *)key).internalValue;
    } else {
      ThrowInvalidArgument("Dictionary keys in updateData: must be NSStrings or FIRFieldPaths.");
    }

    value = self.preConverter(value);
    if ([value isKindOfClass:[FSTDeleteFieldValue class]]) {
      // Add it to the field mask, but don't add anything to updateData.
      context.AddToFieldMask(std::move(path));
    } else {
      absl::optional<google_firestore_v1_Value> parsedValue =
          [self parseData:value context:context.ChildContext(path)];
      if (parsedValue) {
        context.AddToFieldMask(path);
        updateData.Set(path, *parsedValue);
      }
    }
  }];

  google_firestore_v1_Value rootValue = updateData.Get(FieldPath::EmptyPath()).value();
  return std::move(accumulator).UpdateData([self wrapObject:rootValue]);
}

- (FieldValue)parsedQueryValue:(id)input {
  return [self parsedQueryValue:input allowArrays:false];
}

- (FieldValue)parsedQueryValue:(id)input allowArrays:(bool)allowArrays {
  ParseAccumulator accumulator{allowArrays ? UserDataSource::ArrayArgument
                                           : UserDataSource::Argument};

  absl::optional<google_firestore_v1_Value> parsed = [self parseData:input
                                                             context:accumulator.RootContext()];
  HARD_ASSERT(parsed, "Parsed data should not be nil.");
  HARD_ASSERT(accumulator.field_transforms().empty(),
              "Field transforms should have been disallowed.");
  return [self wrapValue:*parsed];
}

/**
 * Internal helper for parsing user data.
 *
 * @param input Data to be parsed.
 * @param context A context object representing the current path being parsed, the source of the
 *   data being parsed, etc.
 *
 * @return The parsed value, or nil if the value was a FieldValue sentinel that should not be
 *   included in the resulting parsed data.
 */
- (absl::optional<google_firestore_v1_Value>)parseData:(id)input context:(ParseContext &&)context {
  input = self.preConverter(input);
  if ([input isKindOfClass:[NSDictionary class]]) {
    return [self parseDictionary:(NSDictionary *)input context:std::move(context)];

  } else if ([input isKindOfClass:[FIRFieldValue class]]) {
    // FieldValues usually parse into transforms (except FieldValue.delete()) in which case we
    // do not want to include this field in our parsed data (as doing so will overwrite the field
    // directly prior to the transform trying to transform it). So we don't call appendToFieldMask
    // and we return nil as our parsing result.
    [self parseSentinelFieldValue:(FIRFieldValue *)input context:std::move(context)];
    return absl::nullopt;

  } else {
    // If context path is unset we are already inside an array and we don't support field mask paths
    // more granular than the top-level array.
    if (context.path()) {
      context.AddToFieldMask(*context.path());
    }

    if ([input isKindOfClass:[NSArray class]]) {
      // TODO(b/34871131): Include the path containing the array in the error message.
      // In the case of IN queries, the parsed data is an array (representing the set of values to
      // be included for the IN query) that may directly contain additional arrays (each
      // representing an individual field value), so we disable this validation.
      if (context.array_element() && context.data_source() != UserDataSource::ArrayArgument) {
        ThrowInvalidArgument("Nested arrays are not supported");
      }
      return [self parseArray:(NSArray *)input context:std::move(context)];
    } else {
      return [self parseScalarValue:input context:std::move(context)];
    }
  }
}

- (google_firestore_v1_Value)parseDictionary:(NSDictionary<NSString *, id> *)dict
                                     context:(ParseContext &&)context {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_map_value_tag;

  __block std::vector<google_firestore_v1_MapValue_FieldsEntry> fields{};

  if (dict.count == 0) {
    const FieldPath *path = context.path();
    if (path && !path->empty()) {
      context.AddToFieldMask(*path);
    }
  } else {
    // Populate a vector of fields since we don't know the size of the final fields array.
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *) {
      absl::optional<google_firestore_v1_Value> parsedValue =
          [self parseData:value context:context.ChildContext(util::MakeString(key))];
      if (parsedValue) {
        google_firestore_v1_MapValue_FieldsEntry fieldsEntry;
        fieldsEntry.key = nanopb::MakeBytesArray(util::MakeString(key));
        fieldsEntry.value = *parsedValue;
        fields.push_back(fieldsEntry);
      }
    }];
  }

  result.map_value.fields_count = static_cast<pb_size_t>(fields.size());
  result.map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(result.map_value.fields_count);

  for (size_t i = 0; i < fields.size(); ++i) {
    result.map_value.fields[i] = fields[i];
  }

  return result;
}

- (google_firestore_v1_Value)parseArray:(NSArray<id> *)array context:(ParseContext &&)context {
  __block google_firestore_v1_Value result;
  result.which_value_type = google_firestore_v1_Value_array_value_tag;
  result.array_value.values_count = static_cast<pb_size_t>([array count]);
  result.array_value.values =
      nanopb::MakeArray<google_firestore_v1_Value>(result.array_value.values_count);

  [array enumerateObjectsUsingBlock:^(id entry, NSUInteger idx, BOOL *) {
    absl::optional<google_firestore_v1_Value> parsedEntry =
        [self parseData:entry context:context.ChildContext(idx)];
    if (!parsedEntry) {
      // Just include nulls in the array for fields being replaced with a sentinel.
      parsedEntry = [self encodeNullValue];
    }
    result.array_value.values[idx] = *parsedEntry;
  }];

  return result;
}

/**
 * "Parses" the provided FIRFieldValue, adding any necessary transforms to
 * context.fieldTransforms.
 */
- (void)parseSentinelFieldValue:(FIRFieldValue *)fieldValue context:(ParseContext &&)context {
  // Sentinels are only supported with writes, and not within arrays.
  if (!context.write()) {
    ThrowInvalidArgument("%s can only be used with updateData() and setData()%s",
                         fieldValue.methodName, context.FieldDescription());
  }
  if (!context.path()) {
    ThrowInvalidArgument("%s is not currently supported inside arrays", fieldValue.methodName);
  }

  if ([fieldValue isKindOfClass:[FSTDeleteFieldValue class]]) {
    if (context.data_source() == UserDataSource::MergeSet) {
      // No transform to add for a delete, but we need to add it to our fieldMask so it gets
      // deleted.
      context.AddToFieldMask(*context.path());

    } else if (context.data_source() == UserDataSource::Update) {
      HARD_ASSERT(context.path()->size() > 0,
                  "FieldValue.delete() at the top level should have already been handled.");
      ThrowInvalidArgument("FieldValue.delete() can only appear at the top level of your "
                           "update data%s",
                           context.FieldDescription());
    } else {
      // We shouldn't encounter delete sentinels for queries or non-merge setData calls.
      ThrowInvalidArgument(
          "FieldValue.delete() can only be used with updateData() and setData() with merge:true%s",
          context.FieldDescription());
    }

  } else if ([fieldValue isKindOfClass:[FSTServerTimestampFieldValue class]]) {
    context.AddToFieldTransforms(*context.path(), ServerTimestampTransform());

  } else if ([fieldValue isKindOfClass:[FSTArrayUnionFieldValue class]]) {
    std::vector<google_firestore_v1_Value> parsedElements =
        [self parseArrayTransformElements:((FSTArrayUnionFieldValue *)fieldValue).elements];
    ArrayTransform arrayUnion(TransformOperation::Type::ArrayUnion,
                              [self wrapValues:std::move(parsedElements)]);
    context.AddToFieldTransforms(*context.path(), std::move(arrayUnion));

  } else if ([fieldValue isKindOfClass:[FSTArrayRemoveFieldValue class]]) {
    std::vector<google_firestore_v1_Value> parsedElements =
        [self parseArrayTransformElements:((FSTArrayRemoveFieldValue *)fieldValue).elements];
    ArrayTransform arrayRemove(TransformOperation::Type::ArrayRemove,
                               [self wrapValues:std::move(parsedElements)]);
    context.AddToFieldTransforms(*context.path(), std::move(arrayRemove));

  } else if ([fieldValue isKindOfClass:[FSTNumericIncrementFieldValue class]]) {
    FSTNumericIncrementFieldValue *numericIncrementFieldValue =
        (FSTNumericIncrementFieldValue *)fieldValue;

    // TODO(mutabledocuments): Use `parseQueryValue`;
    ParseAccumulator accumulator{UserDataSource::Argument};
    absl::optional<google_firestore_v1_Value> operand =
        [self parseData:numericIncrementFieldValue.operand context:accumulator.RootContext()];
    NumericIncrementTransform numeric_increment([self wrapValue:*operand]);

    context.AddToFieldTransforms(*context.path(), std::move(numeric_increment));

  } else {
    HARD_FAIL("Unknown FIRFieldValue type: %s", NSStringFromClass([fieldValue class]));
  }
}

/**
 * Helper to parse a scalar value (i.e. not an NSDictionary, NSArray, or FIRFieldValue).
 *
 * Note that it handles all NSNumber values that are encodable as int64_t or doubles
 * (depending on the underlying type of the NSNumber). Unsigned integer values are handled though
 * any value outside what is representable by int64_t (a signed 64-bit value) will throw an
 * exception.
 *
 * @return The parsed value.
 */
- (google_firestore_v1_Value)parseScalarValue:(nullable id)input context:(ParseContext &&)context {
  if (!input || [input isMemberOfClass:[NSNull class]]) {
    return [self encodeNullValue];

  } else if ([input isKindOfClass:[NSNumber class]]) {
    // Recover the underlying type of the number, using the method described here:
    // http://stackoverflow.com/questions/2518761/get-type-of-nsnumber
    const char *cType = [input objCType];

    // Type Encoding values taken from
    // https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/
    // Articles/ocrtTypeEncodings.html
    switch (cType[0]) {
      case 'q':
        return [self encodeInteger:[input longLongValue]];

      case 'i':  // Falls through.
      case 's':  // Falls through.
      case 'l':  // Falls through.
      case 'I':  // Falls through.
      case 'S':
        // Coerce integer values that aren't long long. Allow unsigned integer types that are
        // guaranteed small enough to skip a length check.
        return [self encodeInteger:[input longLongValue]];

      case 'L':  // Falls through.
      case 'Q':
        // Unsigned integers that could be too large. Note that the 'L' (long) case is handled here
        // because when compiled for LP64, unsigned long is 64 bits and could overflow int64_t.
        {
          unsigned long long extended = [input unsignedLongLongValue];

          if (extended > LLONG_MAX) {
            ThrowInvalidArgument("NSNumber (%s) is too large%s", [input unsignedLongLongValue],
                                 context.FieldDescription());

          } else {
            return [self encodeInteger:static_cast<int64_t>(extended)];
          }
        }

      case 'f':
        return [self encodeDouble:[input doubleValue]];

      case 'd':
        // Double values are already the right type, so just reuse the existing boxed double.
        //
        // Note that NSNumber already performs NaN normalization to a single shared instance
        // so there's no need to treat NaN specially here.
        return [self encodeDouble:[input doubleValue]];

      case 'B':  // Falls through.
      case 'c':  // Falls through.
      case 'C':
        // Boolean values are weird.
        //
        // On arm64, objCType of a BOOL-valued NSNumber will be "c", even though @encode(BOOL)
        // returns "B". "c" is the same as @encode(signed char). Unfortunately this means that
        // legitimate usage of signed chars is impossible, but this should be rare.
        //
        // Additionally, for consistency, map unsigned chars to bools in the same way.
        return [self encodeBoolean:[input boolValue]];

      default:
        // All documented codes should be handled above, so this shouldn't happen.
        HARD_FAIL("Unknown NSNumber objCType %s on %s", cType, input);
    }

  } else if ([input isKindOfClass:[NSString class]]) {
    std::string inputString = util::MakeString(input);
    return [self encodeStringValue:inputString];

  } else if ([input isKindOfClass:[NSDate class]]) {
    NSDate *inputDate = input;
    return [self encodeTimestampValue:api::MakeTimestamp(inputDate)];

  } else if ([input isKindOfClass:[FIRTimestamp class]]) {
    FIRTimestamp *inputTimestamp = input;
    Timestamp timestamp = TimestampInternal::Truncate(api::MakeTimestamp(inputTimestamp));
    return [self encodeTimestampValue:timestamp];

  } else if ([input isKindOfClass:[FIRGeoPoint class]]) {
    return [self encodeGeoPoint:api::MakeGeoPoint(input)];
  } else if ([input isKindOfClass:[NSData class]]) {
    NSData *inputData = input;
    return [self encodeBlob:(nanopb::MakeByteString(inputData))];

  } else if ([input isKindOfClass:[FSTDocumentKeyReference class]]) {
    FSTDocumentKeyReference *reference = input;
    if (reference.databaseID != _databaseID) {
      const DatabaseId &other = reference.databaseID;
      ThrowInvalidArgument(
          "Document Reference is for database %s/%s but should be for database %s/%s%s",
          other.project_id(), other.database_id(), _databaseID.project_id(),
          _databaseID.database_id(), context.FieldDescription());
    }
    return [self encodeReference:_databaseID key:reference.key];

  } else {
    ThrowInvalidArgument("Unsupported type: %s%s", NSStringFromClass([input class]),
                         context.FieldDescription());
  }
}

- (google_firestore_v1_Value)encodeNullValue {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_null_value_tag;
  result.null_value = google_protobuf_NullValue_NULL_VALUE;
  return result;
}

- (google_firestore_v1_Value)encodeBoolean:(bool)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_boolean_value_tag;
  result.boolean_value = value;
  return result;
}

- (google_firestore_v1_Value)encodeInteger:(int64_t)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.integer_value = value;
  return result;
}

- (google_firestore_v1_Value)encodeDouble:(double)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_double_value_tag;
  result.double_value = value;
  return result;
}

- (google_firestore_v1_Value)encodeTimestampValue:(Timestamp)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result.timestamp_value.seconds = value.seconds();
  result.timestamp_value.nanos = value.nanoseconds();
  return result;
}

- (google_firestore_v1_Value)encodeStringValue:(const std::string &)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_string_value_tag;
  result.string_value = nanopb::MakeBytesArray(value);
  return result;
}

- (google_firestore_v1_Value)encodeBlob:(const nanopb::ByteString &)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_bytes_value_tag;
  // Copy the blob so that pb_release can do the right thing.
  result.bytes_value = nanopb::CopyBytesArray(value.get());
  return result;
}

- (google_firestore_v1_Value)encodeReference:(const DatabaseId &)databaseId
                                         key:(const DocumentKey &)key {
  HARD_ASSERT(_databaseID == databaseId, "Database %s cannot encode reference from %s",
              _databaseID.ToString(), databaseId.ToString());

  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_reference_value_tag;

  std::string referenceName = ResourcePath({"projects", databaseId.project_id(), "databases",
                                            databaseId.database_id(), "documents", key.ToString()})
                                  .CanonicalString();
  result.reference_value = nanopb::MakeBytesArray(referenceName);
  return result;
}

- (google_firestore_v1_Value)encodeGeoPoint:(const GeoPoint &)value {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_geo_point_value_tag;
  result.geo_point_value.latitude = value.latitude();
  result.geo_point_value.longitude = value.longitude();
  return result;
}

- (std::vector<google_firestore_v1_Value>)parseArrayTransformElements:(NSArray<id> *)elements {
  ParseAccumulator accumulator{UserDataSource::Argument};

  std::vector<google_firestore_v1_Value> values;
  for (NSUInteger i = 0; i < elements.count; i++) {
    id element = elements[i];
    // Although array transforms are used with writes, the actual elements being unioned or removed
    // are not considered writes since they cannot contain any FieldValue sentinels, etc.
    ParseContext context = accumulator.RootContext();

    absl::optional<google_firestore_v1_Value> parsedElement =
        [self parseData:element context:context.ChildContext(i)];
    HARD_ASSERT(parsedElement && accumulator.field_transforms().size() == 0,
                "Failed to properly parse array transform element: %s", element);
    values.push_back(*parsedElement);
  }
  return values;
}

@end

NS_ASSUME_NONNULL_END
