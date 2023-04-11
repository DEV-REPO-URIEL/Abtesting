// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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

#if os(iOS)

  import Foundation
  import XCTest

  import FirebaseCore
  @testable import FirebaseAuth
  import SafariServices

  class PhoneAuthProviderTests: RPCBaseTests {
    static let kFakeAuthorizedDomain = "test.firebaseapp.com"
    private let kFakeAccessToken = "fakeAccessToken"
    private let kFakeIDToken = "fakeIDToken"
    private let kFakeProviderID = "fakeProviderID"
    static let kFakeAPIKey = "asdfghjkl"
    static let kFakeEmulatorHost = "emulatorhost"
    static let kFakeEmulatorPort = 12345
    static let kFakeClientID = "123456.apps.googleusercontent.com"
    static let kFakeFirebaseAppID = "1:123456789:ios:123abc456def"
    static let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
    static let kFakeTenantID = "tenantID"
    static let kFakeReverseClientID = "com.googleusercontent.apps.123456"

    private let kTestVerificationID = "verificationID"
    private let kTestVerificationCode = "verificationCode"
    private let kTestPhoneNumber = "55555555"
    private let kTestReceipt = "receipt"
    private let kTestSecret = "secret"
    private let kVerificationIDKey = "sessionInfo"
    private let kFakeEncodedFirebaseAppID = "app-1-123456789-ios-123abc456def"
    private let kFakeReCAPTCHAToken = "fakeReCAPTCHAToken"

    // Switches for testing different Phone Auth test flows
    // TODO: Consider using an enum for these instead.
    static var testTenantID = false
    static var testCancel = false
    static var testErrorString = false
    static var testInternalError = false
    static var testInvalidClientID = false
    static var testUnknownError = false
    static var testAppID = false
    static var testEmulator = false
    static var testAppCheck = false

    static var auth: Auth?

    /** @fn testCredentialWithVerificationID
        @brief Tests the @c credentialWithToken method to make sure that it returns a valid AuthCredential instance.
     */
    func testCredentialWithVerificationID() throws {
      initApp(#function)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let credential = provider.credential(withVerificationID: kTestVerificationID,
                                           verificationCode: kTestVerificationCode)
      XCTAssertEqual(credential.verificationID, kTestVerificationID)
      XCTAssertEqual(credential.verificationCode, kTestVerificationCode)
      XCTAssertNil(credential.temporaryProof)
      XCTAssertNil(credential.phoneNumber)
    }

    /** @fn testVerifyEmptyPhoneNumber
        @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an empty phone
            number was provided.
     */
    func testVerifyEmptyPhoneNumber() throws {
      initApp(#function)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: #function)

      // Empty phone number is checked on the client side so no backend RPC is faked.
      provider.verifyPhoneNumber("", uiDelegate: nil) { verificationID, error in
        XCTAssertNotNil(error)
        XCTAssertNil(verificationID)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingPhoneNumber.rawValue)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testVerifyInvalidPhoneNumber
        @brief Tests a failed invocation @c verifyPhoneNumber:completion: because an invalid phone
            number was provided.
     */
    func testVerifyInvalidPhoneNumber() throws {
      try internalTestVerify(valid: false, function: #function)
    }

    /** @fn testVerifyPhoneNumber
        @brief Tests a successful invocation of @c verifyPhoneNumber:completion:.
     */
    func testVerifyPhoneNumber() throws {
      try internalTestVerify(valid: true, function: #function)
    }

    /** @fn testVerifyPhoneNumberInTestMode
        @brief Tests a successful invocation of @c verifyPhoneNumber:completion: when app verification
            is disabled.
     */
    func testVerifyPhoneNumberInTestMode() throws {
      try internalTestVerify(valid: true, function: #function, testMode: true)
    }

    /** @fn testVerifyPhoneNumberInTestModeFailure
        @brief Tests a failed invocation of @c verifyPhoneNumber:completion: when app verification
            is disabled.
     */
    func testVerifyPhoneNumberInTestModeFailure() throws {
      try internalTestVerify(valid: false, function: #function, testMode: true)
    }

    // TODO: Also need to be able to fake getToken from AuthAPNSTokenManager.
    /** @fn testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow
        @brief Tests a successful invocation of @c verifyPhoneNumber:UIDelegate:completion:.
     */
    func testVerifyPhoneNumberUIDelegateFirebaseAppIdFlow() throws {
      try internalTestVerify(valid: true, function: #function, reCAPTCHAfallback: true)
    }

    private func internalTestVerify(valid: Bool, function: String, testMode: Bool = false,
                                    reCAPTCHAfallback: Bool = false) throws {
      initApp(function, testMode: testMode, reCAPTCHAfallback: reCAPTCHAfallback)
      let auth = try XCTUnwrap(PhoneAuthProviderTests.auth)
      let provider = PhoneAuthProvider.provider(auth: auth)
      let expectation = self.expectation(description: #function)
      var group = DispatchGroup()
      if reCAPTCHAfallback {
        // 1. Create a group to synchronize request creation by the fake rpcIssuer.
        group = createGroup()
      }

      let requestExpectation = self.expectation(description: "verifyRequester")
      rpcIssuer?.verifyRequester = { request in
        XCTAssertEqual(request.phoneNumber, self.kTestPhoneNumber)
        if reCAPTCHAfallback {
          XCTAssertNil(request.appCredential)
          XCTAssertEqual(request.reCAPTCHAToken, self.kFakeReCAPTCHAToken)
        } else if testMode {
          XCTAssertNil(request.appCredential)
          XCTAssertNil(request.reCAPTCHAToken)
        } else {
          XCTAssertEqual(request.appCredential?.receipt, self.kTestReceipt)
          XCTAssertEqual(request.appCredential?.secret, self.kTestSecret)
        }
        requestExpectation.fulfill()
        do {
          if valid {
            // Response for the underlying SendVerificationCode RPC call.
            try self.rpcIssuer?
              .respond(withJSON: [self.kVerificationIDKey: self.kTestVerificationID])
          } else {
            try self.rpcIssuer?.respond(serverErrorMessage: "INVALID_PHONE_NUMBER")
          }
        } catch {
          XCTFail("Failure sending response: \(error)")
        }
      }

      if reCAPTCHAfallback {
        // Use fake authURLPresenter so we can test the parameters that get sent to it.
        PhoneAuthProviderTests.auth?.authURLPresenter =
          FakePresenter(urlString: PhoneAuthProviderTests.kFakeRedirectURLStringWithReCAPTCHAToken,
                        firebaseAppID: PhoneAuthProviderTests.kFakeFirebaseAppID)
      }
      let uiDelegate = reCAPTCHAfallback ? FakeUIDelegate() : nil

      // 2. After setting up the parameters, call `verifyPhoneNumber`.
      provider
        .verifyPhoneNumber(kTestPhoneNumber, uiDelegate: uiDelegate) { verificationID, error in

          // 8. After the response triggers the callback in the FakePresenter, verify the response.
          XCTAssertTrue(Thread.isMainThread)
          if valid {
            XCTAssertNil(error)
            XCTAssertEqual(verificationID, self.kTestVerificationID)
          } else {
            XCTAssertNotNil(error)
            XCTAssertNil(verificationID)
            XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidPhoneNumber.rawValue)
          }
          expectation.fulfill()
        }
      if reCAPTCHAfallback {
        // 3. Wait for the fake rpcIssuer to leave the group.
        group.wait()
      }

      // 4. After the fake rpcIssuer leaves the group, trigger the fake network response.
      if reCAPTCHAfallback {
        // Response for the underlying GetProjectConfig RPC call.
        try rpcIssuer?.respond(
          withJSON: ["projectId": "kFakeProjectID",
                     "authorizedDomains": [PhoneAuthProviderTests.kFakeAuthorizedDomain]]
        )
      }
      waitForExpectations(timeout: 555)
    }

    // TODO: verify all options are needed for PhoneAuthTests
    private func initApp(_ functionName: String, useAppID: Bool = true,
                         scheme: String = PhoneAuthProviderTests.kFakeEncodedFirebaseAppID,
                         testMode: Bool = false, reCAPTCHAfallback: Bool = false) {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = PhoneAuthProviderTests.kFakeAPIKey
      options.projectID = "myProjectID"
      if useAppID {
        options.googleAppID = PhoneAuthProviderTests.kFakeFirebaseAppID
      } else {
        // Use the clientID.
        options.clientID = PhoneAuthProviderTests.kFakeClientID
      }

      let strippedName = functionName.replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
      FirebaseApp.configure(name: strippedName, options: options)
      let auth = Auth.auth(app: FirebaseApp.app(name: strippedName)!)

      kAuthGlobalWorkQueue.sync {
        // Wait for Auth protectedDataInitialization to finish.
        PhoneAuthProviderTests.auth = auth
        if testMode {
          // Disable app verification.
          let settings = AuthSettings()
          settings.isAppVerificationDisabledForTesting = true
          auth.settings = settings
        } else if !reCAPTCHAfallback {
          // Fake out appCredentialManager flow.
          auth.appCredentialManager.credential = AuthAppCredential(receipt: kTestReceipt,
                                                                   secret: kTestSecret)
        }
        auth.notificationManager.immediateCallbackForTestFaking = true
        auth.mainBundleUrlTypes = [["CFBundleURLSchemes": [scheme]]]
      }
    }

    private class FakeApplication: Application {
      var delegate: UIApplicationDelegate?
    }

    class FakePresenter: NSObject, FIRAuthWebViewControllerDelegate {
      func webViewController(_ webViewController: AuthWebViewController,
                             canHandle URL: URL) -> Bool {
        XCTFail("Do not call")
        return false
      }

      func webViewControllerDidCancel(_ webViewController: AuthWebViewController) {
        XCTFail("Do not call")
      }

      func webViewController(_ webViewController: AuthWebViewController,
                             didFailWithError error: Error) {
        XCTFail("Do not call")
      }

      func present(_ presentURL: URL,
                   uiDelegate UIDelegate: AuthUIDelegate?,
                   callbackMatcher: @escaping (URL?) -> Bool,
                   completion: @escaping (URL?, Error?) -> Void) {
        // 5. Verify flow triggers present in the FakePresenter class with the right parameters.
        XCTAssertEqual(presentURL.scheme, "https")
        XCTAssertEqual(presentURL.host, kFakeAuthorizedDomain)
        XCTAssertEqual(presentURL.path, "/__/auth/handler")

        let actualURLComponents = URLComponents(url: presentURL, resolvingAgainstBaseURL: false)
        guard let _ = actualURLComponents?.queryItems else {
          XCTFail("Failed to get queryItems")
          return
        }
        let params = AuthWebUtils.dictionary(withHttpArgumentsString: presentURL.query)
        XCTAssertEqual(params["ibi"], Bundle.main.bundleIdentifier)
        XCTAssertEqual(params["apiKey"], PhoneAuthProviderTests.kFakeAPIKey)
        XCTAssertEqual(params["authType"], "verifyApp")
        XCTAssertNotNil(params["v"])
        if OAuthProviderTests.testTenantID {
          XCTAssertEqual(params["tid"], OAuthProviderTests.kFakeTenantID)
        } else {
          XCTAssertNil(params["tid"])
        }
        let appCheckToken = presentURL.fragment
        let verifyAppCheckToken = OAuthProviderTests.testAppCheck ? "fac=fakeAppCheckToken" : nil
        XCTAssertEqual(appCheckToken, verifyAppCheckToken)

        var redirectURL = ""
        if let firebaseAppID {
          XCTAssertEqual(params["appId"], firebaseAppID)
          redirectURL = "\(kFakeEncodedFirebaseAppID)\(urlString)"
        } else if let clientID {
          XCTAssertEqual(params["clientId"], clientID)
          redirectURL = "\(kFakeReverseClientID)\(urlString)"
        }

        // 6. Test callbackMatcher
        // Verify that the URL is rejected by the callback matcher without the event ID.
        XCTAssertFalse(callbackMatcher(URL(string: "\(redirectURL)")))

        // Verify that the URL is accepted by the callback matcher with the matching event ID.
        guard let eventID = params["eventId"] else {
          XCTFail("Failed to get eventID")
          return
        }
        let redirectWithEventID = "\(redirectURL)%26eventId%3D\(eventID)"
        let originalComponents = URLComponents(string: redirectWithEventID)!
        XCTAssertTrue(callbackMatcher(originalComponents.url))

        var components = originalComponents
        components.query = "https"
        XCTAssertFalse(callbackMatcher(components.url))

        components = originalComponents
        components.host = "badhost"
        XCTAssertFalse(callbackMatcher(components.url))

        components = originalComponents
        components.path = "badpath"
        XCTAssertFalse(callbackMatcher(components.url))

        components = originalComponents
        components.query = "badquery"
        XCTAssertFalse(callbackMatcher(components.url))

        // 7. Do the callback to the original call.
        kAuthGlobalWorkQueue.async {
          completion(URL(string: "\(kFakeEncodedFirebaseAppID)\(self.urlString)") ?? nil, nil)
        }
      }

      let urlString: String
      let clientID: String?
      let firebaseAppID: String?

      init(urlString: String, clientID: String? = nil, firebaseAppID: String? = nil) {
        self.urlString = urlString
        self.clientID = clientID
        self.firebaseAppID = firebaseAppID
      }
    }

    private class FakeUIDelegate: NSObject, AuthUIDelegate {
      func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                   completion: (() -> Void)? = nil) {
        guard let safariController = viewControllerToPresent as? SFSafariViewController,
              let delegate = safariController.delegate as? AuthURLPresenter,
              let uiDelegate = delegate.uiDelegate as? FakeUIDelegate else {
          XCTFail("Failed to get presentURL from controller")
          return
        }
        XCTAssertEqual(self, uiDelegate)
      }

      func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        XCTFail("Implement me")
      }
    }

    private let kFakeRedirectURLStringInvalidClientID =
      "com.googleusercontent.apps.123456://firebaseauth/" +
      "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcal" +
      "lback%3FfirebaseError%3D%257B%2522code%2522%253A%2522auth%252Finvalid-oauth-client-id%2522%252" +
      "C%2522message%2522%253A%2522The%2520OAuth%2520client%2520ID%2520provided%2520is%2520either%252" +
      "0invalid%2520or%2520does%2520not%2520match%2520the%2520specified%2520API%2520key.%2522%257D%26" +
      "authType%3DverifyApp"

    private static let kFakeRedirectURLStringWithReCAPTCHAToken =
      "://firebaseauth/" +
      "link?deep_link_id=https%3A%2F%2Fexample.firebaseapp.com%2F__%2Fauth%2Fcallback%3FauthType%" +
      "3DverifyApp%26recaptchaToken%3DfakeReCAPTCHAToken"
  }
#endif
