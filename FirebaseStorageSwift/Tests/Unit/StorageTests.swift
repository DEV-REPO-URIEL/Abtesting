// Copyright 2022 Google LLC
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

import FirebaseCore
@testable import FirebaseStorage

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import SharedTestUtilities

import XCTest

@MainActor
class StorageTests: XCTestCase {
  func testBucketNotEnforced() throws {
    let app = try getApp(bucket: "")
    let storage = Storage.storage(app: app)
    _ = storage.reference(forURL: "gs://benwu-test1.storage.firebase.com/child")
    _ = storage.reference(forURL: "gs://benwu-test2.storage.firebase.com/child")
  }

  func testBucketEnforced() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://benwu-test1.storage.firebase.com")
    _ = storage.reference(forURL: "gs://benwu-test1.storage.firebase.com/child")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = storage.reference(forURL: "gs://benwu-test2.storage.firebase.com/child")
    })
  }

  func testInitWithCustomUrl() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertEqual("gs://foo-bar.appspot.com/", storage.reference().description)
    let storage2 = Storage.storage(app: app, url: "gs://foo-bar.appspot.com/")
    XCTAssertEqual("gs://foo-bar.appspot.com/", storage2.reference().description)
  }

  func testInitWithWrongScheme() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = Storage.storage(app: app, url: "http://foo-bar.appspot.com")
    })
  }

  func testInitWithNoScheme() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = Storage.storage(app: app, url: "foo-bar.appspot.com")
    })
  }

  func testInitWithoutURL() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertNoThrow(try ExceptionCatcher.catchException {
      _ = Storage.storage(app: app)
    })
  }

  func testInitWithPath() throws {
    let app = try getApp(bucket: "bucket")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = Storage.storage(app: app, url: "gs://foo-bar.appspot.com/child")
    })
  }

  func testInitWithDefaultAndCustomUrl() throws {
    let app = try getApp(bucket: "bucket")
    let defaultInstance = Storage.storage(app: app)
    let customInstance = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertEqual("gs://foo-bar.appspot.com/", customInstance.reference().description)
    XCTAssertEqual("gs://bucket/", defaultInstance.reference().description)
  }

  func testStorageDefaultApp() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    XCTAssertEqual(storage.app.name, app.name)
  }

  func testStorageNoBucketInConfig() throws {
    let app = try getApp(bucket: "nil") // Special case code in getApp for "nil".
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = Storage.storage(app: app)
    })
  }

  func testStorageEmptyBucketInConfig() throws {
    let app = try getApp(bucket: "")
    let storage = Storage.storage(app: app)
    let ref = storage.reference(forURL: "gs://bucket/path/to/object")
    XCTAssertEqual(ref.bucket, "bucket")
  }

  func testStorageWrongBucketInConfig() throws {
    let app = try getApp(bucket: "notMyBucket")
    let storage = Storage.storage(app: app)
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      _ = storage.reference(forURL: "gs://bucket/path/to/object")
    })
  }

  func testUseEmulator() throws {
    let app = try getApp(bucket: "bucket-for-testUseEmulator")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    storage.useEmulator(withHost: "localhost", port: 8080)
    XCTAssertNoThrow(storage.reference())
  }

  func testUseEmulatorValidatesHost() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      storage.useEmulator(withHost: "", port: 8080)
    })
  }

  func testUseEmulatorValidatesPort() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://foo-bar.appspot.com")
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      storage.useEmulator(withHost: "localhost", port: -1)
    })
  }

  func testUseEmulatorCannotBeCalledAfterObtainingReference() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app, url: "gs://benwu-test1.storage.firebase.com")
    _ = storage.reference()
    XCTAssertThrowsError(try ExceptionCatcher.catchException {
      storage.useEmulator(withHost: "localhost", port: 8080)
    })
  }

  func testEqual() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let copy = try XCTUnwrap(storage.copy() as? Storage)
    XCTAssertEqual(storage.app.name, copy.app.name)
    XCTAssertEqual(storage.hash, copy.hash)
  }

  func testNotEqual() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let secondApp = try getApp(bucket: "bucket2")
    let storage2 = Storage.storage(app: secondApp)
    XCTAssertNotEqual(storage, storage2)
    XCTAssertNotEqual(storage.hash, storage2.hash)
  }

  func testhash() throws {
    let app = try getApp(bucket: "bucket")
    let storage = Storage.storage(app: app)
    let copy = try XCTUnwrap(storage.copy() as? Storage)
    XCTAssertEqual(storage.app.name, copy.app.name)
  }

  // MARK: Private Helpers

  private static var appDictionary: [String: FirebaseApp] = [:]

  private func getApp(bucket: String) throws -> FirebaseApp {
    let savedApp = StorageTests.appDictionary[bucket]
    guard savedApp == nil else {
      return try XCTUnwrap(savedApp)
    }
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "myProjectID"
    if bucket != "nil" {
      options.storageBucket = bucket
    }
    let name = "StorageTests\(bucket)"
    FirebaseApp.configure(name: name, options: options)
    let app = try! XCTUnwrap(FirebaseApp.app(name: name))
    StorageTests.appDictionary[bucket] = app
    return try XCTUnwrap(app)
  }
}
