// Copyright 2023 Google LLC
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

import Foundation

// TODO: Prefix with `@_implementationOnly` after port.
import FirebaseCoreExtension

/** @class FIRAuthRequestConfiguration
   @brief Defines configurations to be added to a request to Firebase Auth's backend.
 */
@objc(FIRAuthRequestConfiguration) public class AuthRequestConfiguration: NSObject {
  /** @property APIKey
   @brief The Firebase Auth API key used in the request.
   */
  @objc(APIKey) public let apiKey: String

  /** @property LanguageCode
   @brief The language code used in the request.
   */
  @objc public var languageCode: String?

  /// ** @property appID
  //    @brief The Firebase appID used in the request.
  // */
  @objc public var appID: String

  /** @property auth
      @brief The FIRAuth instance used in the request.
   */
  @objc public weak var auth: Auth?

  /// The heartbeat logger used to add heartbeats to the corresponding request's header.
  @objc public var heartbeatLogger: FIRHeartbeatLoggerProtocol?

  /** @property additionalFrameworkMarker
   @brief Additional framework marker that will be added as part of the header of every request.
   */
  @objc public var additionalFrameworkMarker: String?

  /** @property emulatorHostAndPort
   @brief If set, the local emulator host and port to point to instead of the remote backend.
   */
  @objc public var emulatorHostAndPort: String?

  /** @fn initWithRequestClass:APIKey:authLanguage:
   @brief Designated initializer.
   @param apiKey The API key to be used in the request.
   */
  @objc(initWithAPIKey:appID:auth:)
  public init(apiKey: String, appID: String, auth: Auth? = nil) {
    self.apiKey = apiKey
    self.appID = appID
    self.auth = auth
  }

  @objc(initWithAPIKey:appID:auth:heartbeatLogger:)
  public init(apiKey: String,
              appID: String,
              auth: Auth? = nil,
              heartbeatLogger: FIRHeartbeatLoggerProtocol? = nil) {
    self.apiKey = apiKey
    self.appID = appID
    self.auth = auth
    self.heartbeatLogger = heartbeatLogger
  }
}
