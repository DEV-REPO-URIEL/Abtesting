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

// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/firestore/v1beta1/query.proto

// This CPP symbol can be defined to use imports that match up to the framework
// imports needed when using CocoaPods.
#if !defined(GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS)
 #define GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS 0
#endif

#if GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS
 #import <Protobuf/GPBProtocolBuffers.h>
#else
 #import "GPBProtocolBuffers.h"
#endif

#if GOOGLE_PROTOBUF_OBJC_VERSION < 30002
#error This file was generated by a newer version of protoc which is incompatible with your Protocol Buffer library sources.
#endif
#if 30002 < GOOGLE_PROTOBUF_OBJC_MIN_SUPPORTED_VERSION
#error This file was generated by an older version of protoc which is incompatible with your Protocol Buffer library sources.
#endif

// @@protoc_insertion_point(imports)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

CF_EXTERN_C_BEGIN

@class GCFSCursor;
@class GCFSStructuredQuery_CollectionSelector;
@class GCFSStructuredQuery_CompositeFilter;
@class GCFSStructuredQuery_FieldFilter;
@class GCFSStructuredQuery_FieldReference;
@class GCFSStructuredQuery_Filter;
@class GCFSStructuredQuery_Order;
@class GCFSStructuredQuery_Projection;
@class GCFSStructuredQuery_UnaryFilter;
@class GCFSValue;
@class GPBInt32Value;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enum GCFSStructuredQuery_Direction

/** A sort direction. */
typedef GPB_ENUM(GCFSStructuredQuery_Direction) {
  /**
   * Value used if any message's field encounters a value that is not defined
   * by this enum. The message will also have C functions to get/set the rawValue
   * of the field.
   **/
  GCFSStructuredQuery_Direction_GPBUnrecognizedEnumeratorValue = kGPBUnrecognizedEnumeratorValue,
  /** Unspecified. */
  GCFSStructuredQuery_Direction_DirectionUnspecified = 0,

  /** Ascending. */
  GCFSStructuredQuery_Direction_Ascending = 1,

  /** Descending. */
  GCFSStructuredQuery_Direction_Descending = 2,
};

GPBEnumDescriptor *GCFSStructuredQuery_Direction_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL GCFSStructuredQuery_Direction_IsValidValue(int32_t value);

#pragma mark - Enum GCFSStructuredQuery_CompositeFilter_Operator

/** A composite filter operator. */
typedef GPB_ENUM(GCFSStructuredQuery_CompositeFilter_Operator) {
  /**
   * Value used if any message's field encounters a value that is not defined
   * by this enum. The message will also have C functions to get/set the rawValue
   * of the field.
   **/
  GCFSStructuredQuery_CompositeFilter_Operator_GPBUnrecognizedEnumeratorValue = kGPBUnrecognizedEnumeratorValue,
  /** Unspecified. This value must not be used. */
  GCFSStructuredQuery_CompositeFilter_Operator_OperatorUnspecified = 0,

  /** The results are required to satisfy each of the combined filters. */
  GCFSStructuredQuery_CompositeFilter_Operator_And = 1,
};

GPBEnumDescriptor *GCFSStructuredQuery_CompositeFilter_Operator_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL GCFSStructuredQuery_CompositeFilter_Operator_IsValidValue(int32_t value);

#pragma mark - Enum GCFSStructuredQuery_FieldFilter_Operator

/** A field filter operator. */
typedef GPB_ENUM(GCFSStructuredQuery_FieldFilter_Operator) {
  /**
   * Value used if any message's field encounters a value that is not defined
   * by this enum. The message will also have C functions to get/set the rawValue
   * of the field.
   **/
  GCFSStructuredQuery_FieldFilter_Operator_GPBUnrecognizedEnumeratorValue = kGPBUnrecognizedEnumeratorValue,
  /** Unspecified. This value must not be used. */
  GCFSStructuredQuery_FieldFilter_Operator_OperatorUnspecified = 0,

  /** Less than. Requires that the field come first in `order_by`. */
  GCFSStructuredQuery_FieldFilter_Operator_LessThan = 1,

  /** Less than or equal. Requires that the field come first in `order_by`. */
  GCFSStructuredQuery_FieldFilter_Operator_LessThanOrEqual = 2,

  /** Greater than. Requires that the field come first in `order_by`. */
  GCFSStructuredQuery_FieldFilter_Operator_GreaterThan = 3,

  /**
   * Greater than or equal. Requires that the field come first in
   * `order_by`.
   **/
  GCFSStructuredQuery_FieldFilter_Operator_GreaterThanOrEqual = 4,

  /** Equal. */
  GCFSStructuredQuery_FieldFilter_Operator_Equal = 5,
};

GPBEnumDescriptor *GCFSStructuredQuery_FieldFilter_Operator_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL GCFSStructuredQuery_FieldFilter_Operator_IsValidValue(int32_t value);

#pragma mark - Enum GCFSStructuredQuery_UnaryFilter_Operator

/** A unary operator. */
typedef GPB_ENUM(GCFSStructuredQuery_UnaryFilter_Operator) {
  /**
   * Value used if any message's field encounters a value that is not defined
   * by this enum. The message will also have C functions to get/set the rawValue
   * of the field.
   **/
  GCFSStructuredQuery_UnaryFilter_Operator_GPBUnrecognizedEnumeratorValue = kGPBUnrecognizedEnumeratorValue,
  /** Unspecified. This value must not be used. */
  GCFSStructuredQuery_UnaryFilter_Operator_OperatorUnspecified = 0,

  /** Test if a field is equal to NaN. */
  GCFSStructuredQuery_UnaryFilter_Operator_IsNan = 2,

  /** Test if an exprestion evaluates to Null. */
  GCFSStructuredQuery_UnaryFilter_Operator_IsNull = 3,
};

GPBEnumDescriptor *GCFSStructuredQuery_UnaryFilter_Operator_EnumDescriptor(void);

/**
 * Checks to see if the given value is defined by the enum or was not known at
 * the time this source was generated.
 **/
BOOL GCFSStructuredQuery_UnaryFilter_Operator_IsValidValue(int32_t value);

#pragma mark - GCFSQueryRoot

/**
 * Exposes the extension registry for this file.
 *
 * The base class provides:
 * @code
 *   + (GPBExtensionRegistry *)extensionRegistry;
 * @endcode
 * which is a @c GPBExtensionRegistry that includes all the extensions defined by
 * this file and all files that it depends on.
 **/
@interface GCFSQueryRoot : GPBRootObject
@end

#pragma mark - GCFSStructuredQuery

typedef GPB_ENUM(GCFSStructuredQuery_FieldNumber) {
  GCFSStructuredQuery_FieldNumber_Select = 1,
  GCFSStructuredQuery_FieldNumber_FromArray = 2,
  GCFSStructuredQuery_FieldNumber_Where = 3,
  GCFSStructuredQuery_FieldNumber_OrderByArray = 4,
  GCFSStructuredQuery_FieldNumber_Limit = 5,
  GCFSStructuredQuery_FieldNumber_Offset = 6,
  GCFSStructuredQuery_FieldNumber_StartAt = 7,
  GCFSStructuredQuery_FieldNumber_EndAt = 8,
};

/**
 * A Firestore query.
 **/
@interface GCFSStructuredQuery : GPBMessage

/** The projection to return. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_Projection *select;
/** Test to see if @c select has been set. */
@property(nonatomic, readwrite) BOOL hasSelect;

/** The collections to query. */
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<GCFSStructuredQuery_CollectionSelector*> *fromArray;
/** The number of items in @c fromArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger fromArray_Count;

/** The filter to apply. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_Filter *where;
/** Test to see if @c where has been set. */
@property(nonatomic, readwrite) BOOL hasWhere;

/**
 * The order to apply to the query results.
 *
 * Firestore guarantees a stable ordering through the following rules:
 *
 *  * Any field required to appear in `order_by`, that is not already
 *    specified in `order_by`, is appended to the order in field name order
 *    by default.
 *  * If an order on `__name__` is not specified, it is appended by default.
 *
 * Fields are appended with the same sort direction as the last order
 * specified, or 'ASCENDING' if no order was specified. For example:
 *
 *  * `SELECT * FROM Foo ORDER BY A` becomes
 *    `SELECT * FROM Foo ORDER BY A, __name__`
 *  * `SELECT * FROM Foo ORDER BY A DESC` becomes
 *    `SELECT * FROM Foo ORDER BY A DESC, __name__ DESC`
 *  * `SELECT * FROM Foo WHERE A > 1` becomes
 *    `SELECT * FROM Foo WHERE A > 1 ORDER BY A, __name__`
 **/
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<GCFSStructuredQuery_Order*> *orderByArray;
/** The number of items in @c orderByArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger orderByArray_Count;

/** A starting point for the query results. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSCursor *startAt;
/** Test to see if @c startAt has been set. */
@property(nonatomic, readwrite) BOOL hasStartAt;

/** A end point for the query results. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSCursor *endAt;
/** Test to see if @c endAt has been set. */
@property(nonatomic, readwrite) BOOL hasEndAt;

/**
 * The number of results to skip.
 *
 * Applies before limit, but after all other constraints. Must be >= 0 if
 * specified.
 **/
@property(nonatomic, readwrite) int32_t offset;

/**
 * The maximum number of results to return.
 *
 * Applies after all other constraints.
 * Must be >= 0 if specified.
 **/
@property(nonatomic, readwrite, strong, null_resettable) GPBInt32Value *limit;
/** Test to see if @c limit has been set. */
@property(nonatomic, readwrite) BOOL hasLimit;

@end

#pragma mark - GCFSStructuredQuery_CollectionSelector

typedef GPB_ENUM(GCFSStructuredQuery_CollectionSelector_FieldNumber) {
  GCFSStructuredQuery_CollectionSelector_FieldNumber_CollectionId = 2,
  GCFSStructuredQuery_CollectionSelector_FieldNumber_AllDescendants = 3,
};

/**
 * A selection of a collection, such as `messages as m1`.
 **/
@interface GCFSStructuredQuery_CollectionSelector : GPBMessage

/**
 * The collection ID.
 * When set, selects only collections with this ID.
 **/
@property(nonatomic, readwrite, copy, null_resettable) NSString *collectionId;

/**
 * When false, selects only collections that are immediate children of
 * the `parent` specified in the containing `RunQueryRequest`.
 * When true, selects all descendant collections.
 **/
@property(nonatomic, readwrite) BOOL allDescendants;

@end

#pragma mark - GCFSStructuredQuery_Filter

typedef GPB_ENUM(GCFSStructuredQuery_Filter_FieldNumber) {
  GCFSStructuredQuery_Filter_FieldNumber_CompositeFilter = 1,
  GCFSStructuredQuery_Filter_FieldNumber_FieldFilter = 2,
  GCFSStructuredQuery_Filter_FieldNumber_UnaryFilter = 3,
};

typedef GPB_ENUM(GCFSStructuredQuery_Filter_FilterType_OneOfCase) {
  GCFSStructuredQuery_Filter_FilterType_OneOfCase_GPBUnsetOneOfCase = 0,
  GCFSStructuredQuery_Filter_FilterType_OneOfCase_CompositeFilter = 1,
  GCFSStructuredQuery_Filter_FilterType_OneOfCase_FieldFilter = 2,
  GCFSStructuredQuery_Filter_FilterType_OneOfCase_UnaryFilter = 3,
};

/**
 * A filter.
 **/
@interface GCFSStructuredQuery_Filter : GPBMessage

/** The type of filter. */
@property(nonatomic, readonly) GCFSStructuredQuery_Filter_FilterType_OneOfCase filterTypeOneOfCase;

/** A composite filter. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_CompositeFilter *compositeFilter;

/** A filter on a document field. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_FieldFilter *fieldFilter;

/** A filter that takes exactly one argument. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_UnaryFilter *unaryFilter;

@end

/**
 * Clears whatever value was set for the oneof 'filterType'.
 **/
void GCFSStructuredQuery_Filter_ClearFilterTypeOneOfCase(GCFSStructuredQuery_Filter *message);

#pragma mark - GCFSStructuredQuery_CompositeFilter

typedef GPB_ENUM(GCFSStructuredQuery_CompositeFilter_FieldNumber) {
  GCFSStructuredQuery_CompositeFilter_FieldNumber_Op = 1,
  GCFSStructuredQuery_CompositeFilter_FieldNumber_FiltersArray = 2,
};

/**
 * A filter that merges multiple other filters using the given operator.
 **/
@interface GCFSStructuredQuery_CompositeFilter : GPBMessage

/** The operator for combining multiple filters. */
@property(nonatomic, readwrite) GCFSStructuredQuery_CompositeFilter_Operator op;

/**
 * The list of filters to combine.
 * Must contain at least one filter.
 **/
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<GCFSStructuredQuery_Filter*> *filtersArray;
/** The number of items in @c filtersArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger filtersArray_Count;

@end

/**
 * Fetches the raw value of a @c GCFSStructuredQuery_CompositeFilter's @c op property, even
 * if the value was not defined by the enum at the time the code was generated.
 **/
int32_t GCFSStructuredQuery_CompositeFilter_Op_RawValue(GCFSStructuredQuery_CompositeFilter *message);
/**
 * Sets the raw value of an @c GCFSStructuredQuery_CompositeFilter's @c op property, allowing
 * it to be set to a value that was not defined by the enum at the time the code
 * was generated.
 **/
void SetGCFSStructuredQuery_CompositeFilter_Op_RawValue(GCFSStructuredQuery_CompositeFilter *message, int32_t value);

#pragma mark - GCFSStructuredQuery_FieldFilter

typedef GPB_ENUM(GCFSStructuredQuery_FieldFilter_FieldNumber) {
  GCFSStructuredQuery_FieldFilter_FieldNumber_Field = 1,
  GCFSStructuredQuery_FieldFilter_FieldNumber_Op = 2,
  GCFSStructuredQuery_FieldFilter_FieldNumber_Value = 3,
};

/**
 * A filter on a specific field.
 **/
@interface GCFSStructuredQuery_FieldFilter : GPBMessage

/** The field to filter by. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_FieldReference *field;
/** Test to see if @c field has been set. */
@property(nonatomic, readwrite) BOOL hasField;

/** The operator to filter by. */
@property(nonatomic, readwrite) GCFSStructuredQuery_FieldFilter_Operator op;

/** The value to compare to. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSValue *value;
/** Test to see if @c value has been set. */
@property(nonatomic, readwrite) BOOL hasValue;

@end

/**
 * Fetches the raw value of a @c GCFSStructuredQuery_FieldFilter's @c op property, even
 * if the value was not defined by the enum at the time the code was generated.
 **/
int32_t GCFSStructuredQuery_FieldFilter_Op_RawValue(GCFSStructuredQuery_FieldFilter *message);
/**
 * Sets the raw value of an @c GCFSStructuredQuery_FieldFilter's @c op property, allowing
 * it to be set to a value that was not defined by the enum at the time the code
 * was generated.
 **/
void SetGCFSStructuredQuery_FieldFilter_Op_RawValue(GCFSStructuredQuery_FieldFilter *message, int32_t value);

#pragma mark - GCFSStructuredQuery_UnaryFilter

typedef GPB_ENUM(GCFSStructuredQuery_UnaryFilter_FieldNumber) {
  GCFSStructuredQuery_UnaryFilter_FieldNumber_Op = 1,
  GCFSStructuredQuery_UnaryFilter_FieldNumber_Field = 2,
};

typedef GPB_ENUM(GCFSStructuredQuery_UnaryFilter_OperandType_OneOfCase) {
  GCFSStructuredQuery_UnaryFilter_OperandType_OneOfCase_GPBUnsetOneOfCase = 0,
  GCFSStructuredQuery_UnaryFilter_OperandType_OneOfCase_Field = 2,
};

/**
 * A filter with a single operand.
 **/
@interface GCFSStructuredQuery_UnaryFilter : GPBMessage

/** The unary operator to apply. */
@property(nonatomic, readwrite) GCFSStructuredQuery_UnaryFilter_Operator op;

/** The argument to the filter. */
@property(nonatomic, readonly) GCFSStructuredQuery_UnaryFilter_OperandType_OneOfCase operandTypeOneOfCase;

/** The field to which to apply the operator. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_FieldReference *field;

@end

/**
 * Fetches the raw value of a @c GCFSStructuredQuery_UnaryFilter's @c op property, even
 * if the value was not defined by the enum at the time the code was generated.
 **/
int32_t GCFSStructuredQuery_UnaryFilter_Op_RawValue(GCFSStructuredQuery_UnaryFilter *message);
/**
 * Sets the raw value of an @c GCFSStructuredQuery_UnaryFilter's @c op property, allowing
 * it to be set to a value that was not defined by the enum at the time the code
 * was generated.
 **/
void SetGCFSStructuredQuery_UnaryFilter_Op_RawValue(GCFSStructuredQuery_UnaryFilter *message, int32_t value);

/**
 * Clears whatever value was set for the oneof 'operandType'.
 **/
void GCFSStructuredQuery_UnaryFilter_ClearOperandTypeOneOfCase(GCFSStructuredQuery_UnaryFilter *message);

#pragma mark - GCFSStructuredQuery_Order

typedef GPB_ENUM(GCFSStructuredQuery_Order_FieldNumber) {
  GCFSStructuredQuery_Order_FieldNumber_Field = 1,
  GCFSStructuredQuery_Order_FieldNumber_Direction = 2,
};

/**
 * An order on a field.
 **/
@interface GCFSStructuredQuery_Order : GPBMessage

/** The field to order by. */
@property(nonatomic, readwrite, strong, null_resettable) GCFSStructuredQuery_FieldReference *field;
/** Test to see if @c field has been set. */
@property(nonatomic, readwrite) BOOL hasField;

/** The direction to order by. Defaults to `ASCENDING`. */
@property(nonatomic, readwrite) GCFSStructuredQuery_Direction direction;

@end

/**
 * Fetches the raw value of a @c GCFSStructuredQuery_Order's @c direction property, even
 * if the value was not defined by the enum at the time the code was generated.
 **/
int32_t GCFSStructuredQuery_Order_Direction_RawValue(GCFSStructuredQuery_Order *message);
/**
 * Sets the raw value of an @c GCFSStructuredQuery_Order's @c direction property, allowing
 * it to be set to a value that was not defined by the enum at the time the code
 * was generated.
 **/
void SetGCFSStructuredQuery_Order_Direction_RawValue(GCFSStructuredQuery_Order *message, int32_t value);

#pragma mark - GCFSStructuredQuery_FieldReference

typedef GPB_ENUM(GCFSStructuredQuery_FieldReference_FieldNumber) {
  GCFSStructuredQuery_FieldReference_FieldNumber_FieldPath = 2,
};

/**
 * A reference to a field, such as `max(messages.time) as max_time`.
 **/
@interface GCFSStructuredQuery_FieldReference : GPBMessage

@property(nonatomic, readwrite, copy, null_resettable) NSString *fieldPath;

@end

#pragma mark - GCFSStructuredQuery_Projection

typedef GPB_ENUM(GCFSStructuredQuery_Projection_FieldNumber) {
  GCFSStructuredQuery_Projection_FieldNumber_FieldsArray = 2,
};

/**
 * The projection of document's fields to return.
 **/
@interface GCFSStructuredQuery_Projection : GPBMessage

/**
 * The fields to return.
 *
 * If empty, all fields are returned. To only return the name
 * of the document, use `['__name__']`.
 **/
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<GCFSStructuredQuery_FieldReference*> *fieldsArray;
/** The number of items in @c fieldsArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger fieldsArray_Count;

@end

#pragma mark - GCFSCursor

typedef GPB_ENUM(GCFSCursor_FieldNumber) {
  GCFSCursor_FieldNumber_ValuesArray = 1,
  GCFSCursor_FieldNumber_Before = 2,
};

/**
 * A position in a query result set.
 **/
@interface GCFSCursor : GPBMessage

/**
 * The values that represent a position, in the order they appear in
 * the order by clause of a query.
 *
 * Can contain fewer values than specified in the order by clause.
 **/
@property(nonatomic, readwrite, strong, null_resettable) NSMutableArray<GCFSValue*> *valuesArray;
/** The number of items in @c valuesArray without causing the array to be created. */
@property(nonatomic, readonly) NSUInteger valuesArray_Count;

/**
 * If the position is just before or just after the given values, relative
 * to the sort order defined by the query.
 **/
@property(nonatomic, readwrite) BOOL before;

@end

NS_ASSUME_NONNULL_END

CF_EXTERN_C_END

#pragma clang diagnostic pop

// @@protoc_insertion_point(global_scope)
