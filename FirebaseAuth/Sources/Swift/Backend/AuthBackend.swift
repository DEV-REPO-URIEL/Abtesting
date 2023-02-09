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
@_implementationOnly import FirebaseCore
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

public protocol AuthBackendRPCIssuer: NSObjectProtocol {
  /** @fn
      @brief Asynchronously sends a POST request.
      @param requestConfiguration The request to be made.
      @param URL The request URL.
      @param body Request body.
      @param contentType Content type of the body.
      @param handler provided that handles POST response. Invoked asynchronously on the auth global
          work queue in the future.
   */
  func asyncPostToURLWithRequestConfiguration(requestConfiguration: AuthRequestConfiguration,
                                              url: URL,
                                              body: Data?,
                                              contentType: String,
                                              completionHandler: @escaping ((Data?, Error?)
                                                -> Void))
}

public class AuthBackendRPCIssuerImplementation: NSObject, AuthBackendRPCIssuer {
  let fetcherService: GTMSessionFetcherService

  override init() {
    fetcherService = GTMSessionFetcherService()
    fetcherService.userAgent = AuthBackend.authUserAgent()
    // TODO: next line.
    // fetcherService.callbackQueue = FIRAuthGlobalWorkQueue()

    // Avoid reusing the session to prevent
    // https://github.com/firebase/firebase-ios-sdk/issues/1261
    fetcherService.reuseSession = false
  }

  public func asyncPostToURLWithRequestConfiguration(requestConfiguration: AuthRequestConfiguration,
                                                     url: URL,
                                                     body: Data?,
                                                     contentType: String,
                                                     completionHandler: @escaping ((Data?, Error?)
                                                       -> Void)) {
    let request = AuthBackend.request(withURL: url, contentType: contentType,
                                      requestConfiguration: requestConfiguration)
    let fetcher = fetcherService.fetcher(with: request)
    if let _ = requestConfiguration.emulatorHostAndPort {
      fetcher.allowLocalhostRequest = true
      fetcher.allowedInsecureSchemes = ["http"]
    }
    fetcher.bodyData = body
    fetcher.beginFetch(completionHandler: completionHandler)
  }
}

@objc(FIRAuthBackend2) public class AuthBackend: NSObject {
  static func authUserAgent() -> String {
    return "FirebaseAuth.iOS/\(FirebaseVersion()) \(GTMFetcherStandardUserAgentString(nil))"
  }

  private static var gBackendImplementation: AuthBackendImplementation?

  class func setDefaultBackendImplementationWithRPCIssuer(issuer: AuthBackendRPCIssuer?) {
    let defaultImplementation = AuthBackendRPCImplementation()
    if let issuer = issuer {
      defaultImplementation.RPCIssuer = issuer
    }
    gBackendImplementation = defaultImplementation
  }

  private class func implementation() -> AuthBackendImplementation {
    if gBackendImplementation == nil {
      gBackendImplementation = AuthBackendRPCImplementation()
    }
    return (gBackendImplementation)!
  }

  /** @fn createAuthURI:callback:
      @brief Calls the createAuthURI endpoint, which is responsible for creating the URI used by the
          IdP to authenticate the user.
      @param request The request parameters.
      @param callback The callback.
   */
  @objc public class func createAuthURI(_ request: CreateAuthURIRequest,
                                        callback: @escaping ((CreateAuthURIResponse?, Error?)
                                          -> Void)) {
    implementation().createAuthURI(request, callback: callback)
  }

  /** @fn deleteAccount:
      @brief Calls the DeleteAccount endpoint, which is responsible for deleting a user.
      @param request The request parameters.
      @param callback The callback.
   */
  @objc public class func deleteAccount(_ request: DeleteAccountRequest,
                                        callback: @escaping ((Error?) -> Void)) {
    implementation().deleteAccount(request, callback: callback)
  }

  // TODO: Why does this need to be public to be visible by unit tests? 
  public class func request(withURL url: URL,
                      contentType: String,
                      requestConfiguration: AuthRequestConfiguration) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
    let additionalFrameworkMarker = requestConfiguration
      .additionalFrameworkMarker ?? "FirebaseCore-iOS"
    let clientVersion = "iOS/FirebaseSDK/\(FirebaseVersion())/\(additionalFrameworkMarker)"
    request.setValue(clientVersion, forHTTPHeaderField: "X-Client-Version")
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    request.setValue(requestConfiguration.appID, forHTTPHeaderField: "X-Firebase-GMPID")
    // TODO:
    //  [request setValue:FIRHeaderValueFromHeartbeatsPayload(
    //                        [requestConfiguration.heartbeatLogger flushHeartbeatsIntoPayload])
    //      forHTTPHeaderField:kFirebaseHeartbeatHeader];
    let preferredLocalizations = Bundle.main.preferredLocalizations
    if preferredLocalizations.count > 0 {
      request.setValue(preferredLocalizations.first, forHTTPHeaderField: "Accept-Language")
    }
    if let languageCode = requestConfiguration.languageCode,
       languageCode.count > 0 {
      request.setValue(languageCode, forHTTPHeaderField: "X-Firebase-Locale")
    }
    return request
  }
}

protocol AuthBackendImplementation {
  func createAuthURI(_ request: CreateAuthURIRequest,
                     callback: @escaping ((CreateAuthURIResponse?, Error?) -> Void))
  func deleteAccount(_ request: DeleteAccountRequest,
                     callback: @escaping ((Error?) -> Void))
  func post(withRequest request: AuthRPCRequest,
            response: AuthRPCResponse,
            callback: @escaping ((Error?) -> Void))
}

private class AuthBackendRPCImplementation: NSObject, AuthBackendImplementation {
  var RPCIssuer: AuthBackendRPCIssuer
  override init() {
    RPCIssuer = AuthBackendRPCIssuerImplementation()
  }

  /** @fn createAuthURI:callback:
      @brief Calls the createAuthURI endpoint, which is responsible for creating the URI used by the
          IdP to authenticate the user.
      @param request The request parameters.
      @param callback The callback.
   */
  func createAuthURI(_ request: CreateAuthURIRequest,
                     callback: @escaping ((CreateAuthURIResponse?, Error?) -> Void)) {
    let response = CreateAuthURIResponse()
    post(withRequest: request, response: response) { error in
      if let error = error {
        callback(nil, error)
      } else {
        callback(response, nil)
      }
    }
  }

  /** @fn postWithRequest:response:callback:
      @brief Calls the RPC using HTTP POST.
      @remarks Possible error responses:
          @see FIRAuthInternalErrorCodeRPCRequestEncodingError
          @see FIRAuthInternalErrorCodeJSONSerializationError
          @see FIRAuthInternalErrorCodeNetworkError
          @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
          @see FIRAuthInternalErrorCodeUnexpectedResponse
          @see FIRAuthInternalErrorCodeRPCResponseDecodingError
      @param request The request.
      @param response The empty response to be filled.
      @param callback The callback for both success and failure.
   */
//  fileprivate func post(withRequest request: AuthRPCRequest,
//            response: AuthRPCResponse,
//                     callback: @escaping ((AuthRPCResponse?, Error?) -> Void)) {
//    let response = request.response
//    post(withRequest: request, response: response) { error in
//      if let error = error {
//        callback(nil, error)
//      } else {
//        callback(response, nil)
//      }
//    }
//  }

  func deleteAccount(_ request: DeleteAccountRequest, callback: @escaping ((Error?) -> Void)) {
    let response = DeleteAccountResponse()
    post(withRequest: request, response: response, callback: callback)
  }

  /** @fn postWithRequest:response:callback:
      @brief Calls the RPC using HTTP POST.
      @remarks Possible error responses:
          @see FIRAuthInternalErrorCodeRPCRequestEncodingError
          @see FIRAuthInternalErrorCodeJSONSerializationError
          @see FIRAuthInternalErrorCodeNetworkError
          @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
          @see FIRAuthInternalErrorCodeUnexpectedResponse
          @see FIRAuthInternalErrorCodeRPCResponseDecodingError
      @param request The request.
      @param response The empty response to be filled.
      @param callback The callback for both success and failure.
   */
  fileprivate func post(withRequest request: AuthRPCRequest,
            response: AuthRPCResponse,
            callback: @escaping ((Error?) -> Void)) {
    var bodyData: Data?
    if request.containsPostBody?() != nil {
      do {
        // TODO: Can unencodedHTTPRequestBody ever throw?
        let postBody = try request.unencodedHTTPRequestBody()
        var JSONWritingOptions: JSONSerialization.WritingOptions = .init(rawValue: 0)
        #if DEBUG
          JSONWritingOptions = JSONSerialization.WritingOptions.prettyPrinted
        #endif

        guard JSONSerialization.isValidJSONObject(postBody) else {
          callback(AuthErrorUtils.JSONSerializationErrorForUnencodableType())
          return
        }
        bodyData = try? JSONSerialization.data(
          withJSONObject: postBody,
          options: JSONWritingOptions
        )
        if bodyData == nil {
          // This is an untested case. This happens exclusively when there is an error in the
          // framework implementation of dataWithJSONObject:options:error:. This shouldn't normally
          // occur as isValidJSONObject: should return NO in any case we should encounter an error.
          callback(AuthErrorUtils.JSONSerializationErrorForUnencodableType())
          return
        }
      } catch {
        callback(AuthErrorUtils.RPCRequestEncodingError(underlyingError: error))
        return
      }
    }
    RPCIssuer.asyncPostToURLWithRequestConfiguration(
      requestConfiguration: request.requestConfiguration(),
      url: request.requestURL(),
      body: bodyData,
      contentType: "application/json"
    ) { data, error in
      // If there is an error with no body data at all, then this must be a
      // network error.
      guard let data = data else {
        if let error = error {
          callback(AuthErrorUtils.networkError(underlyingError: error))
          return
        } else {
          // TODO: this was ignored before
          fatalError("Internal error")
        }
      }
      // Try to decode the HTTP response data which may contain either a
      // successful response or error message.
      var dictionary: [String: Any]
      do {
        let rawDecode = try JSONSerialization.jsonObject(with: data,
                                                         options: JSONSerialization.ReadingOptions
                                                           .mutableLeaves)
        guard let decodedDictionary = rawDecode as? [String: Any] else {
          if error != nil {
            callback(AuthErrorUtils.unexpectedResponse(deserializedResponse: rawDecode,
                                                       underlyingError: error))
          } else {
            callback(AuthErrorUtils.unexpectedResponse(deserializedResponse: rawDecode))
          }
          return
        }
        dictionary = decodedDictionary
      } catch let jsonError {
        if error != nil {
          // We have an error, but we couldn't decode the body, so we have no
          // additional information other than the raw response and the
          // original NSError (the jsonError is inferred by the error code
          // (AuthErrorCodeUnexpectedHTTPResponse, and is irrelevant.)
          callback(AuthErrorUtils.unexpectedResponse(data: data, underlyingError: error))
          return
        } else {
          // This is supposed to be a "successful" response, but we couldn't
          // deserialize the body.
          callback(AuthErrorUtils.unexpectedResponse(data: data, underlyingError: jsonError))
          return
        }
      }

      // At this point we either have an error with successfully decoded
      // details in the body, or we have a response which must pass further
      // validation before we know it's truly successful. We deal with the
      // case where we have an error with successfully decoded error details
      // first:
      if error != nil {
        if let errorDictionary = dictionary["error"] as? [String: Any] {
          // TODO: port clientError
          if let errorMessage = errorDictionary["message"] as? String {
               let clientError = AuthBackendRPCImplementation.clientError(withServerErrorMessage: errorMessage,
                                                              errorDictionary: errorDictionary,
                                                              response: response)
                callback(clientError)
                return
            }
          // Not a message we know, return the message directly.
          callback(AuthErrorUtils.unexpectedErrorResponse(
            deserializedResponse: errorDictionary,
            underlyingError: error
          ))
          return
        }
        // No error message at all, return the decoded response.
        callback(AuthErrorUtils
          .unexpectedErrorResponse(deserializedResponse: dictionary, underlyingError: error))
        return
      }

      // Finally, we try to populate the response object with the JSON
      // values.
      do {
        try response.setFields(dictionary: dictionary)
      } catch {
        callback(AuthErrorUtils
          .RPCResponseDecodingError(deserializedResponse: dictionary, underlyingError: error))
        return
      }
      // In case returnIDPCredential of a verifyAssertion request is set to
      // @YES, the server may return a 200 with a response that may contain a
      // server error.
      // TODO: port clientError
        if let verifyAssertionRequest = request as? VerifyAssertionRequest {
          if verifyAssertionRequest.returnIDPCredential {
            if let errorMessage = dictionary["errorMessage"] as? String {
               let clientError = AuthBackendRPCImplementation.clientError(withServerErrorMessage: errorMessage,
                                                            errorDictionary: dictionary,
                                                            response: response)
              callback(clientError)
              return
            }
          }
        }
      callback(nil)
    }
  }
  private class func clientError(withServerErrorMessage serverErrorMessage: String,
                           errorDictionary: [String: Any],
                           response: AuthRPCResponse) -> Error {
    let split = serverErrorMessage.split(separator: ":")
    let shortErrorMessage = split.first
    let serverDetailErrorMessage = String(split.count > 1 ? split[1] : "")
    switch shortErrorMessage {
    case "USER_NOT_FOUND": return AuthErrorUtils.userNotFoundError(message: serverDetailErrorMessage)
    case "MISSING_CONTINUE_URI": return AuthErrorUtils.missingContinueURIError(message: serverDetailErrorMessage)
      // "INVALID_IDENTIFIER" can be returned by createAuthURI RPC. Considering email addresses are
      //  currently the only identifiers, we surface the FIRAuthErrorCodeInvalidEmail error code in this
      //  case.
    case "INVALID_IDENTIFIER": return AuthErrorUtils.invalidEmailError(message: serverDetailErrorMessage)
    case "INVALID_EMAIL": return AuthErrorUtils.invalidEmailError(message: serverDetailErrorMessage)
    default: fatalError("Implement missing message")
    }

  }
}
