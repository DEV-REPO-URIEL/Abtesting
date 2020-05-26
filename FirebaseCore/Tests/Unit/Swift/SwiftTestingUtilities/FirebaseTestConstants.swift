// Copyright 2020 Google
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

public enum FirebaseTestConstants {
  enum App {
    static let firebaseDefaultAppName = "__FIRAPP_DEFAULT"
    static let googleAppIDKey = "FIRGoogleAppIDKey"
    static let firebaseAppNameKey = "FIRAppNameKey"
    static let firebaseAppIsDefaultAppKey = "FIRAppIsDefaultAppKey"
  }

  enum Options {
    static let androidClientID = "correct_android_client_id"
    static let apiKey = "correct_api_key"
    static let customizedAPIKey = "customized_api_key"
    static let clientID = "correct_client_id"
    static let trackingID = "correct_tracking_id"
    static let gcmSenderID = "correct_gcm_sender_id"
    static let googleAppID = "1:123:ios:123abc"
    static let databaseURL = "https://abc-xyz-123.firebaseio.com"
    static let storageBucket = "project-id-123.storage.firebase.com"
    static let deepLinkURLScheme = "comgoogledeeplinkurl"
    static let newDeepLinkURLScheme = "newdeeplinkurlfortest"
    static let bundleID = "com.google.FirebaseSDKTests"
    static let projectID = "abc-xyz-123"
  }
}
