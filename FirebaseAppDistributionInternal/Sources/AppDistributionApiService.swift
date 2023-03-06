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
import FirebaseInstallations
import FirebaseCore

// Avoids exposing internal APIs to Swift users
@_implementationOnly import FirebaseCoreInternal

public typealias AppDistributionFetchReleasesCompletion = (_ releases: [Any]?, _ error: Error?)
  -> Void
public typealias AppDistributionFindReleaseCompletion = (_ releaseName: String?, _ error: Error?)
  -> Void
public typealias AppDistributionGenerateAuthTokenCompletion = (_ identifier: String?,
                                                               _ authTokenResult: InstallationsAuthTokenResult?,
                                                               _ error: Error?) -> Void

enum Strings {
  static let errorDomain = "com.firebase.appdistribution.api"
  static let errorDetailsKey = "details"
  static let httpGet = "GET"
  static let releaseEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/devices/-/testerApps/%@/installations/%@/releases"
  static let findReleaseEndpointUrlTemplate =
    "https://firebaseapptesters.googleapis.com/v1alpha/projects/%@/installations/%@/releases:find"
  static let installationsAuthHeader = "X-Goog-Firebase-Installations-Auth"
  static let apiHeaderKey = "X-Goog-Api-Key"
  static let apiBundleKey = "X-Ios-Bundle-Identifier"
  static let responseReleaseKey = "releases"
  static let compositeBinaryIdQueryParamName = "compositeBinaryId"
}

enum AppDistributionApiError: NSInteger {
  case ApiErrorTimeout = 0
  case ApiTokenGenerationFailure = 1
  case ApiInstallationIdentifierError = 2
  case ApiErrorUnauthenticated = 3
  case ApiErrorUnauthorized = 4
  case ApiErrorNotFound = 5
  case ApiErrorUnknownFailure = 6
  case ApiErrorParseFailure = 7
}

struct CompositeBinaryId: Codable {
  var displayVersion: String
  var buildVersion: String
  var codeHash: String
}

struct FindReleaseResponse: Codable {
  var release: String
}

@objc(FIRFADApiServiceSwift) open class AppDistributionApiService: NSObject {
  @objc(generateAuthTokenWithCompletion:) public static func generateAuthToken(completion: @escaping AppDistributionGenerateAuthTokenCompletion) {
    generateAuthToken(installations: Installations.installations(), completion: completion)
  }

  static func generateAuthToken(installations: InstallationsProtocol,
                                completion: @escaping AppDistributionGenerateAuthTokenCompletion) {
    installations.authToken(completion: { authTokenResult, error in
      var fadError: Error? = error
      if self.handleError(
        error: &fadError,
        description: "Failed to generate Firebase installation auth token",
        code: .ApiTokenGenerationFailure
      ) {
        Logger
          .logError(String(format: "Error getting auth token. Error: %@",
                           error?.localizedDescription ?? ""))
        completion(nil, nil, fadError)
        return
      }

      installations.installationID(completion: { identifier, error in
        var fadError: Error? = error
        if self.handleError(
          error: &fadError,
          description: "Failed to generate Firebase installation id",
          code: .ApiInstallationIdentifierError
        ) {
          Logger
            .logError(String(format: "Error getting installation ID. Error: %@",
                             error?.localizedDescription ?? ""))
          completion(nil, nil, fadError)
          return
        }

        completion(identifier, authTokenResult, nil)
      })
    })
  }

  @objc(fetchReleasesWithCompletion:) public static func fetchReleases(completion: @escaping AppDistributionFetchReleasesCompletion) {
    guard let app = FirebaseApp.app() else {
      return
    }

    fetchReleases(
      app: app,
      installations: Installations.installations(),
      urlSession: URLSession.shared,
      completion: completion
    )
  }

  static func fetchReleases(app: FirebaseApp, installations: InstallationsProtocol,
                            urlSession: URLSession,
                            completion: @escaping AppDistributionFetchReleasesCompletion) {
    Logger.logInfo(String(
      format: "Requesting release for app id - %@",
      app.options.googleAppID
    ))
    generateAuthToken(installations: installations) { identifier, authTokenResult, error in
      let urlString = String(
        format: Strings.releaseEndpointUrlTemplate,
        app.options.googleAppID,
        identifier!
      )
      let request = self.createHttpRequest(
        app: app,
        method: Strings.httpGet,
        url: urlString,
        authTokenResult: authTokenResult!
      )
      Logger.logInfo(String(
        format: "Url: %@ Auth token: %@ Api Key: %@",
        urlString,
        authTokenResult?.authToken ?? "",
        app.options.apiKey ?? ""
      ))

      let listReleaseDataTask = urlSession
        .dataTask(with: request as URLRequest) { data, response, error in
          var fadError = error
          let releases = self.handleReleaseResponse(
            data: data as? NSData,
            response: response,
            error: &fadError
          )
          DispatchQueue.main.async {
            completion(releases, fadError)
          }
        }

      listReleaseDataTask.resume()
    }
  }

  static func handleError(httpResponse: HTTPURLResponse?, error: inout Error?) -> Bool {
    if error != nil || httpResponse == nil {
      return handleError(
        error: &error,
        description: "Unknown http error occurred",
        code: .ApiErrorUnknownFailure
      )
    } else if httpResponse?.statusCode != 200 {
      error = createError(statusCode: httpResponse!.statusCode)
      return true
    }

    return false
  }

  static func handleError(error: inout Error?, description: String?,
                          code: AppDistributionApiError) -> Bool {
    if error != nil {
      error = createError(description: description!, code: code)
      return true
    }
    return false
  }

  static func createError(description: String, code: AppDistributionApiError) -> Error {
    let userInfo = [NSLocalizedDescriptionKey: description]
    return NSError(domain: Strings.errorDomain, code: code.rawValue, userInfo: userInfo)
  }

  static func createError(statusCode: NSInteger) -> Error {
    switch statusCode {
    case 401:
      return createError(description: "Tester not authenticated", code: .ApiErrorUnauthenticated)
    case 403, 400:
      return createError(description: "Tester not authorized", code: .ApiErrorUnauthorized)
    case 404:
      return createError(description: "Tester or releases not found", code: .ApiErrorUnauthorized)
    case 408, 504:
      return createError(description: "Request timeout", code: .ApiErrorTimeout)
    default:
      print("Unknown status code")
    }

    let description = String(format: "Unknown status code: %ld", statusCode)
    return createError(description: description, code: .ApiErrorUnknownFailure)
  }

  static func createHttpRequest(app: FirebaseApp, method: String, url: String,
                                authTokenResult: InstallationsAuthTokenResult)
    -> NSMutableURLRequest {
    return createHttpRequest(
      app: app,
      method: method,
      url: URL(string: url),
      authTokenResult: authTokenResult
    )
  }

  static func createHttpRequest(app: FirebaseApp, method: String, url: URL?,
                                authTokenResult: InstallationsAuthTokenResult)
    -> NSMutableURLRequest {
    let request = NSMutableURLRequest()
    request.url = url
    request.httpMethod = method
    request.setValue(authTokenResult.authToken, forHTTPHeaderField: Strings.installationsAuthHeader)
    request.setValue(
      app.options.apiKey,
      forHTTPHeaderField: Strings.installationsAuthHeader
    )
    request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: Strings.apiBundleKey)
    return request
  }

  static func handleReleaseResponse(data: NSData?, response: URLResponse?,
                                    error: inout Error?) -> [Any]? {
    guard let response = response else {
      return nil
    }

    let httpResponse = response as! HTTPURLResponse
    Logger
      .logInfo(String(format: "HTTPResponse status code %ld, response %@", httpResponse.statusCode,
                      httpResponse))

    if handleError(httpResponse: httpResponse, error: &error) {
      // TODO: Consider adding logging equivalent to [FIRFADApiService tryParseGoogleAPIErrorFromResponse].
      Logger
        .logError(String(format: "App tester API service error: %@",
                         error?.localizedDescription ?? ""))
      return nil
    }
    return parseApiResponseWithData(data: data, error: &error)
  }

  static func parseApiResponseWithData(data: NSData?, error: inout Error?) -> [Any]? {
    guard let data = data else {
      return nil
    }

    do {
      let serializedResponse = try JSONSerialization.jsonObject(
        with: data as Data,
        options: JSONSerialization.ReadingOptions(rawValue: 0)
      ) as? [String: Any]
      return serializedResponse![Strings.responseReleaseKey] as? [Any]
    } catch let thrownError {
      let description: String = (thrownError as NSError)
        .userInfo[NSLocalizedDescriptionKey] as? String ?? "Failed to parse response"
      error = thrownError
      _ = self.handleError(error: &error, description: description, code: .ApiErrorParseFailure)
      Logger.logError("Tester API - Error deserializing json response")
      return nil
    }
  }
}
