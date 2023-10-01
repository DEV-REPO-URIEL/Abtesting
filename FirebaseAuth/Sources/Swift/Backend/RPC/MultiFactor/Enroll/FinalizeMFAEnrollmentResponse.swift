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

class FinalizeMFAEnrollmentResponse: AuthRPCResponse {
  public required init() {}

  private(set) var idToken: String?
  private(set) var refreshToken: String?
  private(set) var phoneSessionInfo: AuthProtoFinalizeMFAPhoneResponseInfo?
  private(set) var totpSessionInfo: AuthProtoFinalizeMFATOTPEnrollmentResponseInfo?

  func setFields(dictionary: [String: AnyHashable]) throws {
    idToken = dictionary["idToken"] as? String
    refreshToken = dictionary["refreshToken"] as? String

    if let data = dictionary["phoneSessionInfo"] as? [String: AnyHashable] {
      phoneSessionInfo = AuthProtoFinalizeMFAPhoneResponseInfo(dictionary: data)
    } else if let data = dictionary["totpSessionInfo"] as? [String: AnyHashable] {
      totpSessionInfo = AuthProtoFinalizeMFATOTPEnrollmentResponseInfo(dictionary: data)
    }
  }
}
