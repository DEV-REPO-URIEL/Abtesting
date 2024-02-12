/*
 * Copyright 2022 Google LLC
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

/* Automatically generated nanopb constant definitions */
/* Generated by nanopb-0.3.9.9 */

#include "Crashlytics/Protogen/nanopb/crashlytics.nanopb.h"

/* @@protoc_insertion_point(includes) */
#if PB_PROTO_HEADER_VERSION != 30
#error Regenerate this file with the current version of nanopb generator.
#endif



const pb_field_t google_crashlytics_Report_fields[11] = {
    PB_FIELD(  1, BYTES   , SINGULAR, POINTER , FIRST, google_crashlytics_Report, sdk_version, sdk_version, 0),
    PB_FIELD(  3, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, gmp_app_id, sdk_version, 0),
    PB_FIELD(  4, UENUM   , SINGULAR, STATIC  , OTHER, google_crashlytics_Report, platform, gmp_app_id, 0),
    PB_FIELD(  5, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, installation_uuid, platform, 0),
    PB_FIELD(  6, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, build_version, installation_uuid, 0),
    PB_FIELD(  7, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, display_version, build_version, 0),
    PB_FIELD( 10, MESSAGE , SINGULAR, STATIC  , OTHER, google_crashlytics_Report, apple_payload, display_version, &google_crashlytics_FilesPayload_fields),
    PB_FIELD( 16, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, firebase_installation_id, apple_payload, 0),
    PB_FIELD( 17, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, app_quality_session_id, firebase_installation_id, 0),
    PB_FIELD( 18, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_Report, firebase_authentication_token, app_quality_session_id, 0),
    PB_LAST_FIELD
};

const pb_field_t google_crashlytics_FilesPayload_fields[2] = {
    PB_FIELD(  1, MESSAGE , REPEATED, POINTER , FIRST, google_crashlytics_FilesPayload, files, files, &google_crashlytics_FilesPayload_File_fields),
    PB_LAST_FIELD
};

const pb_field_t google_crashlytics_FilesPayload_File_fields[3] = {
    PB_FIELD(  1, BYTES   , SINGULAR, POINTER , FIRST, google_crashlytics_FilesPayload_File, filename, filename, 0),
    PB_FIELD(  2, BYTES   , SINGULAR, POINTER , OTHER, google_crashlytics_FilesPayload_File, contents, filename, 0),
    PB_LAST_FIELD
};



/* Check that field information fits in pb_field_t */
#if !defined(PB_FIELD_32BIT)
/* If you get an error here, it means that you need to define PB_FIELD_32BIT
 * compile-time option. You can do that in pb.h or on compiler command line.
 *
 * The reason you need to do this is that some of your messages contain tag
 * numbers or field sizes that are larger than what can fit in 8 or 16 bit
 * field descriptors.
 */
PB_STATIC_ASSERT((pb_membersize(google_crashlytics_Report, apple_payload) < 65536), YOU_MUST_DEFINE_PB_FIELD_32BIT_FOR_MESSAGES_google_crashlytics_Report_google_crashlytics_FilesPayload_google_crashlytics_FilesPayload_File)
#endif

#if !defined(PB_FIELD_16BIT) && !defined(PB_FIELD_32BIT)
/* If you get an error here, it means that you need to define PB_FIELD_16BIT
 * compile-time option. You can do that in pb.h or on compiler command line.
 *
 * The reason you need to do this is that some of your messages contain tag
 * numbers or field sizes that are larger than what can fit in the default
 * 8 bit descriptors.
 */
PB_STATIC_ASSERT((pb_membersize(google_crashlytics_Report, apple_payload) < 256), YOU_MUST_DEFINE_PB_FIELD_16BIT_FOR_MESSAGES_google_crashlytics_Report_google_crashlytics_FilesPayload_google_crashlytics_FilesPayload_File)
#endif


/* @@protoc_insertion_point(eof) */
