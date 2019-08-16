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

/* Automatically generated nanopb constant definitions */
/* Generated by nanopb-0.3.9.2 */

#include "fiam.nanopb.h"

/* @@protoc_insertion_point(includes) */
#if PB_PROTO_HEADER_VERSION != 30
#error Regenerate this file with the current version of nanopb generator.
#endif



const pb_field_t logs_proto_firebase_inappmessaging_CampaignAnalytics_fields[10] = {
    PB_FIELD(  1, BYTES   , OPTIONAL, POINTER , FIRST, logs_proto_firebase_inappmessaging_CampaignAnalytics, project_number, project_number, 0),
    PB_FIELD(  2, BYTES   , OPTIONAL, POINTER , OTHER, logs_proto_firebase_inappmessaging_CampaignAnalytics, campaign_id, project_number, 0),
    PB_FIELD(  3, MESSAGE , OPTIONAL, STATIC  , OTHER, logs_proto_firebase_inappmessaging_CampaignAnalytics, client_app, campaign_id, &logs_proto_firebase_inappmessaging_ClientAppInfo_fields),
    PB_FIELD(  4, INT64   , OPTIONAL, STATIC  , OTHER, logs_proto_firebase_inappmessaging_CampaignAnalytics, client_timestamp_millis, client_app, 0),
    PB_ANONYMOUS_ONEOF_FIELD(event,   5, ENUM    , ONEOF, STATIC  , OTHER, logs_proto_firebase_inappmessaging_CampaignAnalytics, event_type, client_timestamp_millis, 0),
    PB_ANONYMOUS_ONEOF_FIELD(event,   6, ENUM    , ONEOF, STATIC  , UNION, logs_proto_firebase_inappmessaging_CampaignAnalytics, dismiss_type, client_timestamp_millis, 0),
    PB_ANONYMOUS_ONEOF_FIELD(event,   7, ENUM    , ONEOF, STATIC  , UNION, logs_proto_firebase_inappmessaging_CampaignAnalytics, render_error_reason, client_timestamp_millis, 0),
    PB_ANONYMOUS_ONEOF_FIELD(event,   8, ENUM    , ONEOF, STATIC  , UNION, logs_proto_firebase_inappmessaging_CampaignAnalytics, fetch_error_reason, client_timestamp_millis, 0),
    PB_FIELD(  9, BYTES   , OPTIONAL, POINTER , OTHER, logs_proto_firebase_inappmessaging_CampaignAnalytics, fiam_sdk_version, fetch_error_reason, 0),
    PB_LAST_FIELD
};

const pb_field_t logs_proto_firebase_inappmessaging_ClientAppInfo_fields[3] = {
    PB_FIELD(  1, BYTES   , OPTIONAL, POINTER , FIRST, logs_proto_firebase_inappmessaging_ClientAppInfo, google_app_id, google_app_id, 0),
    PB_FIELD(  2, BYTES   , OPTIONAL, POINTER , OTHER, logs_proto_firebase_inappmessaging_ClientAppInfo, firebase_instance_id, google_app_id, 0),
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
PB_STATIC_ASSERT((pb_membersize(logs_proto_firebase_inappmessaging_CampaignAnalytics, client_app) < 65536), YOU_MUST_DEFINE_PB_FIELD_32BIT_FOR_MESSAGES_logs_proto_firebase_inappmessaging_CampaignAnalytics_logs_proto_firebase_inappmessaging_ClientAppInfo)
#endif

#if !defined(PB_FIELD_16BIT) && !defined(PB_FIELD_32BIT)
/* If you get an error here, it means that you need to define PB_FIELD_16BIT
 * compile-time option. You can do that in pb.h or on compiler command line.
 * 
 * The reason you need to do this is that some of your messages contain tag
 * numbers or field sizes that are larger than what can fit in the default
 * 8 bit descriptors.
 */
PB_STATIC_ASSERT((pb_membersize(logs_proto_firebase_inappmessaging_CampaignAnalytics, client_app) < 256), YOU_MUST_DEFINE_PB_FIELD_16BIT_FOR_MESSAGES_logs_proto_firebase_inappmessaging_CampaignAnalytics_logs_proto_firebase_inappmessaging_ClientAppInfo)
#endif


/* @@protoc_insertion_point(eof) */
