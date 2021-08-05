// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@import FirebaseAuth;
@import FirebaseABTesting;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
@import FirebaseAppDistribution;
#endif
@import Firebase;
@import FirebaseCrashlytics;
@import FirebaseCore;
@import FirebaseDatabase;
@import FirebaseDynamicLinks;
@import FirebaseFirestore;
@import FirebaseFunctions;
#if TARGET_OS_IOS || TARGET_OS_TVOS
@import FirebaseInAppMessaging;
#endif
@import FirebaseInstallations;
@import FirebaseMessaging;
@import FirebasePerformance @import FirebaseRemoteConfig;
@import FirebaseStorage;
