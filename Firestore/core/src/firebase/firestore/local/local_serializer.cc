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

#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"

#include <cstdlib>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/target.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::ObjectValue;
using model::SnapshotVersion;
using nanopb::Reader;
using nanopb::Tag;
using nanopb::Writer;
using util::Status;

void LocalSerializer::EncodeMaybeDocument(
    Writer* writer, const model::MaybeDocument& maybe_doc) const {
  switch (maybe_doc.type()) {
    case model::MaybeDocument::Type::Document:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeDocument(writer, static_cast<const model::Document&>(maybe_doc));
      });
      return;

    case model::MaybeDocument::Type::NoDocument:
      writer->WriteTag(
          {PB_WT_STRING, firestore_client_MaybeDocument_no_document_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        EncodeNoDocument(writer,
                         static_cast<const model::NoDocument&>(maybe_doc));
      });
      return;

    case model::MaybeDocument::Type::Unknown:
      // TODO(rsgowman)
      abort();
  }

  UNREACHABLE();
}

std::unique_ptr<model::MaybeDocument> LocalSerializer::DecodeMaybeDocument(
    Reader* reader) const {
  std::unique_ptr<model::MaybeDocument> result;

  while (reader->good()) {
    switch (reader->ReadTag().field_number) {
      case firestore_client_MaybeDocument_document_tag:
        reader->RequireWireType(PB_WT_STRING);

        // TODO(rsgowman): If multiple 'document' values are found, we should
        // merge them (rather than using the last one.)
        result =
            reader->ReadNestedMessage<model::Document>([&](Reader* reader) {
              return rpc_serializer_.DecodeDocument(reader);
            });
        break;

      case firestore_client_MaybeDocument_no_document_tag:
        reader->RequireWireType(PB_WT_STRING);

        // TODO(rsgowman): If multiple 'no_document' values are found, we should
        // merge them (rather than using the last one.)
        result = reader->ReadNestedMessage<model::NoDocument>(
            [&](Reader* reader) { return DecodeNoDocument(reader); });
        break;

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField();
    }
  }

  if (!result) {
    reader->update_status(Status(FirestoreErrorCode::DataLoss,
                                 "Invalid MaybeDocument message: Neither "
                                 "'no_document' nor 'document' fields set."));
    return {};
  }
  return result;
}

void LocalSerializer::EncodeDocument(Writer* writer,
                                     const model::Document& doc) const {
  // Encode Document.name
  writer->WriteTag({PB_WT_STRING, google_firestore_v1beta1_Document_name_tag});
  writer->WriteString(rpc_serializer_.EncodeKey(doc.key()));

  // Encode Document.fields (unless it's empty)
  const ObjectValue& object_value = doc.data().object_value();
  if (!object_value.internal_value.empty()) {
    rpc_serializer_.EncodeObjectMap(
        writer, object_value.internal_value,
        google_firestore_v1beta1_Document_fields_tag,
        google_firestore_v1beta1_Document_FieldsEntry_key_tag,
        google_firestore_v1beta1_Document_FieldsEntry_value_tag);
  }

  // Encode Document.update_time
  writer->WriteTag(
      {PB_WT_STRING, google_firestore_v1beta1_Document_update_time_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeVersion(writer, doc.version());
  });

  // Ignore Document.create_time. (We don't use this in our on-disk protos.)
}

void LocalSerializer::EncodeNoDocument(Writer* writer,
                                       const model::NoDocument& no_doc) const {
  // Encode NoDocument.name
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_name_tag});
  writer->WriteString(rpc_serializer_.EncodeKey(no_doc.key()));

  // Encode NoDocument.read_time
  writer->WriteTag({PB_WT_STRING, firestore_client_NoDocument_read_time_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeVersion(writer, no_doc.version());
  });
}

std::unique_ptr<model::NoDocument> LocalSerializer::DecodeNoDocument(
    Reader* reader) const {
  std::string name;
  absl::optional<Timestamp> version = Timestamp{};

  while (reader->good()) {
    switch (reader->ReadTag().field_number) {
      case firestore_client_NoDocument_name_tag:
        reader->RequireWireType(PB_WT_STRING);
        name = reader->ReadString();
        break;

      case firestore_client_NoDocument_read_time_tag:
        reader->RequireWireType(PB_WT_STRING);
        version = reader->ReadNestedMessage<Timestamp>(
            rpc_serializer_.DecodeTimestamp);
        break;

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField();
        break;
    }
  }

  if (!reader->status().ok()) return nullptr;
  return absl::make_unique<model::NoDocument>(rpc_serializer_.DecodeKey(name),
                                              SnapshotVersion{*version});
}

void LocalSerializer::EncodeQueryData(Writer* writer,
                                      const QueryData& query_data) const {
  writer->WriteTag({PB_WT_VARINT, firestore_client_Target_target_id_tag});
  writer->WriteInteger(query_data.target_id());

  writer->WriteTag(
      {PB_WT_STRING, firestore_client_Target_snapshot_version_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    rpc_serializer_.EncodeTimestamp(writer,
                                    query_data.snapshot_version().timestamp());
  });

  writer->WriteTag({PB_WT_STRING, firestore_client_Target_resume_token_tag});
  writer->WriteBytes(query_data.resume_token());

  const Query& query = query_data.query();
  if (query.IsDocumentQuery()) {
    // TODO(rsgowman): Implement. Probably like this (once EncodeDocumentsTarget
    // exists):
    /*
    writer->WriteTag({PB_WT_STRING, firestore_client_Target_documents_tag});
    writer->WriteNestedMessage([&](Writer* writer) {
      rpc_serializer_.EncodeDocumentsTarget(writer, query);
    });
    */
    abort();
  } else {
    writer->WriteTag({PB_WT_STRING, firestore_client_Target_query_tag});
    writer->WriteNestedMessage([&](Writer* writer) {
      rpc_serializer_.EncodeQueryTarget(writer, query);
    });
  }
}

absl::optional<QueryData> LocalSerializer::DecodeQueryData(
    Reader* reader) const {
  model::TargetId target_id = 0;
  absl::optional<Timestamp> version = Timestamp{};
  std::vector<uint8_t> resume_token;
  absl::optional<Query> query = Query::Invalid();

  while (reader->good()) {
    switch (reader->ReadTag().field_number) {
      case firestore_client_Target_target_id_tag:
        reader->RequireWireType(PB_WT_VARINT);
        // TODO(rsgowman): How to handle truncation of integer types?
        target_id = static_cast<model::TargetId>(reader->ReadInteger());
        break;

      case firestore_client_Target_snapshot_version_tag:
        reader->RequireWireType(PB_WT_STRING);
        version = reader->ReadNestedMessage<Timestamp>(
            rpc_serializer_.DecodeTimestamp);
        break;

      case firestore_client_Target_resume_token_tag:
        reader->RequireWireType(PB_WT_STRING);
        resume_token = reader->ReadBytes();
        break;

      case firestore_client_Target_query_tag:
        reader->RequireWireType(PB_WT_STRING);
        // TODO(rsgowman): Clear 'documents' field (since query and documents
        // are part of a 'oneof').
        query =
            reader->ReadNestedMessage<Query>(rpc_serializer_.DecodeQueryTarget);
        break;

      case firestore_client_Target_documents_tag:
        reader->RequireWireType(PB_WT_STRING);
        // Clear 'query' field (since query and documents are part of a 'oneof')
        query = Query::Invalid();
        // TODO(rsgowman): Implement.
        abort();

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField();
        break;
    }
  }

  if (!reader->status().ok()) return {};
  return QueryData(*std::move(query), target_id, QueryPurpose::kListen,
                   SnapshotVersion{*std::move(version)},
                   std::move(resume_token));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
