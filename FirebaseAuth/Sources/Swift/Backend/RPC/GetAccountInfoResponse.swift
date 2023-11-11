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

/** @var kErrorKey
    @brief The key for the "error" value in JSON responses from the server.
 */
private let kErrorKey = "error"

/** @class FIRGetAccountInfoResponseProviderUserInfo
    @brief Represents the provider user info part of the response from the getAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
class GetAccountInfoResponseProviderUserInfo: NSObject {
  /** @property providerID
   @brief The ID of the identity provider.
   */
  let providerID: String?

  /** @property displayName
   @brief The user's display name at the identity provider.
   */
  let displayName: String?

  /** @property photoURL
   @brief The user's photo URL at the identity provider.
   */
  let photoURL: URL?

  /** @property federatedID
   @brief The user's identifier at the identity provider.
   */
  let federatedID: String?

  /** @property email
   @brief The user's email at the identity provider.
   */
  let email: String?

  /** @property phoneNumber
   @brief A phone number associated with the user.
   */
  let phoneNumber: String?

  /** @fn initWithAPIKey:
   @brief Designated initializer.
   @param dictionary The provider user info data from endpoint.
   */
  init(dictionary: [String: Any]) {
    providerID = dictionary["providerId"] as? String
    displayName = dictionary["displayName"] as? String
    if let photoURL = dictionary["photoUrl"] as? String {
      self.photoURL = URL(string: photoURL)
    } else {
      photoURL = nil
    }
    federatedID =
      dictionary["federatedId"] as? String
    email = dictionary["email"] as? String
    phoneNumber = dictionary["phoneNumber"] as? String
  }
}

/** @class FIRGetAccountInfoResponseUser
    @brief Represents the firebase user info part of the response from the getAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
class GetAccountInfoResponseUser: NSObject {
  /** @property localID
   @brief The ID of the user.
   */
  let localID: String?

  /** @property email
   @brief The email or the user.
   */
  let email: String?

  /** @property emailVerified
   @brief Whether the email has been verified.
   */
  let emailVerified: Bool

  /** @property displayName
   @brief The display name of the user.
   */
  let displayName: String?

  /** @property photoURL
   @brief The user's photo URL.
   */
  let photoURL: URL?

  /** @property creationDate
   @brief The user's creation date.
   */
  let creationDate: Date?

  /** @property lastSignInDate
   @brief The user's last login date.
   */
  let lastLoginDate: Date?

  /** @property providerUserInfo
   @brief The user's profiles at the associated identity providers.
   */
  let providerUserInfo: [GetAccountInfoResponseProviderUserInfo]?

  /** @property passwordHash
   @brief Information about user's password.
   @remarks This is not necessarily the hash of user's actual password.
   */

  let passwordHash: String?

  /** @property phoneNumber
   @brief A phone number associated with the user.
   */
  let phoneNumber: String?

  let mfaEnrollments: [AuthProtoMFAEnrollment]?

  /** @fn initWithAPIKey:
   @brief Designated initializer.
   @param dictionary The provider user info data from endpoint.
   */
  init(dictionary: [String: Any]) {
    if let providerUserInfoData = dictionary["providerUserInfo"] as? [[String: Any]] {
      providerUserInfo = providerUserInfoData.map {
        GetAccountInfoResponseProviderUserInfo(dictionary: $0)
      }
    } else {
      providerUserInfo = nil
    }
    localID = dictionary["localId"] as? String
    displayName = dictionary["displayName"] as? String
    email = dictionary["email"] as? String
    if let photoURL = dictionary["photoUrl"] as? String {
      self.photoURL = URL(string: photoURL)
    } else {
      photoURL = nil
    }
    if let createdAt = dictionary["createdAt"] as? String,
       let timeInterval = Double(createdAt) {
      // Divide by 1000 in order to convert milliseconds to seconds.
      creationDate = Date(timeIntervalSince1970: timeInterval / 1000)
    } else {
      creationDate = nil
    }
    if let lastLoginAt = dictionary["lastLoginAt"] as? String,
       let timeInterval = Double(lastLoginAt) {
      // Divide by 1000 in order to convert milliseconds to seconds.
      lastLoginDate = Date(timeIntervalSince1970: timeInterval / 1000)
    } else {
      lastLoginDate = nil
    }

    emailVerified = dictionary["emailVerified"] as? Bool ?? false
    passwordHash = dictionary["passwordHash"] as? String
    phoneNumber = dictionary["phoneNumber"] as? String
    if let mfaEnrollmentData = dictionary["mfaInfo"] as? [[String: AnyHashable]] {
      mfaEnrollments = mfaEnrollmentData.map { AuthProtoMFAEnrollment(dictionary: $0)
      }
    } else {
      mfaEnrollments = nil
    }
  }
}

/** @class FIRGetAccountInfoResponse
    @brief Represents the response from the setAccountInfo endpoint.
    @see https://developers.google.com/identity/toolkit/web/reference/relyingparty/getAccountInfo
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetAccountInfoResponse: AuthRPCResponse {
  required init() {}

  /** @property providerUserInfo
   @brief The requested users' profiles.
   */
  var users: [GetAccountInfoResponseUser]?
  func setFields(dictionary: [String: AnyHashable]) throws {
    guard let usersData = dictionary["users"] as? [[String: AnyHashable]] else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    guard usersData.count == 1 else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: dictionary)
    }
    users = [GetAccountInfoResponseUser(dictionary: usersData[0])]
  }
}
