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

@objc(FIRVerifyClientRequest)
public class VerifyClientRequest: IdentityToolkitRequest, AuthRPCRequest {
  /// The endpoint for the verifyClient request.
  private static let verifyClientEndpoint = "verifyClient"

  /// The key for the appToken request paramenter.
  private static let appTokenKey = "appToken"

  /// The key for the isSandbox request parameter.
  private static let isSandboxKey = "isSandbox"

  /** @var response
      @brief The corresponding response for this request
   */
  @objc public var response: AuthRPCResponse = VerifyClientResponse()

  public func unencodedHTTPRequestBody() throws -> Any {
    var postBody = [String: Any]()
    if let appToken = appToken {
      postBody[Self.appTokenKey] = appToken
    }
    postBody[Self.isSandboxKey] = isSandbox
    return postBody
  }

  /// The APNS device token.
  @objc public private(set) var appToken: String?

  /// The flag that denotes if the appToken  pertains to Sandbox or Production.
  @objc public private(set) var isSandbox: Bool

  @objc public init(withAppToken: String?,
                    isSandbox: Bool,
                    requestConfiguration: AuthRequestConfiguration) {
    appToken = withAppToken
    self.isSandbox = isSandbox
    self.isSandbox = isSandbox
    super.init(endpoint: Self.verifyClientEndpoint, requestConfiguration: requestConfiguration)
  }
}
