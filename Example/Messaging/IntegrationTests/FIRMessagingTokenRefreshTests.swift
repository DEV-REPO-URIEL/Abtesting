/*
 * Copyright 2019 Google LLC
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

// macOS requests a user password when accessing the Keychain for the first time,
// so the tests may fail. Disable integration tests on macOS so far.
// TODO: Configure the tests to run on macOS without requesting the keychain password.
#if !TARGET_OS_OSX

  import FirebaseCore
  import FirebaseInstanceID
  import FirebaseMessaging
  import XCTest

  // This class should be only used once to ensure the test is independent
  class fakeAppDelegate: NSObject, MessagingDelegate {
    var messaging = Messaging.messaging()
    var delegateIsCalled = false

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
      delegateIsCalled = true
    }
  }

  class FIRMessagingTokenRefreshTests: XCTestCase {
    var app: FirebaseApp!
    var instanceID: InstanceID?
    var messaging: Messaging?

    override class func setUp() {
      FirebaseApp.configure()
    }

    override func setUp() {
      instanceID = InstanceID.instanceID()
      messaging = Messaging.messaging()
    }

    override func tearDown() {
      instanceID = nil
      messaging = nil
    }

    func testDeleteTokenWithTokenRefreshDelegatesAndNotifications() {
      let expectation = self.expectation(description: "delegate method and notification are called")
      assertTokenWithAuthorizedEntity()

      let notificationExpectation = self.expectation(forNotification: NSNotification.Name
        .MessagingRegistrationTokenRefreshed,
                                                     object: nil,
                                                     handler: nil)

      let testDelegate = fakeAppDelegate()
      messaging?.delegate = testDelegate
      testDelegate.delegateIsCalled = false

      guard let messaging = self.messaging else {
        return
      }
      messaging.deleteFCMToken(forSenderID: tokenAuthorizedEntity(), completion: { error in
        XCTAssertNil(error)
        XCTAssertTrue(testDelegate.delegateIsCalled)
        expectation.fulfill()
      })

      wait(for: [expectation, notificationExpectation], timeout: 5)
    }

    // pragma mark - Helpers
    func assertTokenWithAuthorizedEntity() {
      let expectation = self.expectation(description: "tokenWithAuthorizedEntity")
      guard let messaging = self.messaging else {
        return
      }
      messaging.retrieveFCMToken(forSenderID: tokenAuthorizedEntity()) { token, error in
        XCTAssertNil(error)
        XCTAssertNotNil(token)
        expectation.fulfill()
      }
      wait(for: [expectation], timeout: 5)
    }

    func tokenAuthorizedEntity() -> String {
      guard let app = FirebaseApp.app() else {
        return ""
      }
      return app.options.gcmSenderID
    }
  }
#endif // !TARGET_OS_OSX
