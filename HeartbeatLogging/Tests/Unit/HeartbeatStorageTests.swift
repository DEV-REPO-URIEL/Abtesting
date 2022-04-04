// Copyright 2021 Google LLC
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

import XCTest
@testable import HeartbeatLogging

class HeartbeatStorageTests: XCTestCase {
  // MARK: - Instance Management

  func testGettingInstance_WithSameID_ReturnsSameInstance() {
    // Given
    let heartbeatStorage1 = HeartbeatStorage.getInstance(id: "sparky")
    // When
    let heartbeatStorage2 = HeartbeatStorage.getInstance(id: "sparky")
    // Then
    XCTAssert(
      heartbeatStorage1 === heartbeatStorage1,
      "Instances should reference the same object."
    )

    addTeardownBlock { [weak heartbeatStorage1, weak heartbeatStorage2] in
      XCTAssertNil(heartbeatStorage1)
      XCTAssertNil(heartbeatStorage2)
    }
  }

  func testGettingInstance_WithDifferentID_ReturnsDifferentInstances() {
    // Given
    let heartbeatStorage1 = HeartbeatStorage.getInstance(id: "sparky_jr")
    // When
    let heartbeatStorage2 = HeartbeatStorage.getInstance(id: "sparky_sr")
    // Then
    XCTAssert(
      heartbeatStorage1 !== heartbeatStorage2,
      "Instances should NOT reference the same object."
    )

    addTeardownBlock { [weak heartbeatStorage1, weak heartbeatStorage2] in
      XCTAssertNil(heartbeatStorage1)
      XCTAssertNil(heartbeatStorage2)
    }
  }

  func testCachedInstancesCannotBeRetainedWeakly() {
    // Given
    var strongHeartbeatStorage: HeartbeatStorage? = .getInstance(id: "sparky")
    weak var weakHeartbeatStorage: HeartbeatStorage? = .getInstance(id: "sparky")
    XCTAssert(
      strongHeartbeatStorage === weakHeartbeatStorage,
      "Instances should reference the same object."
    )

    // When
    strongHeartbeatStorage = nil

    // Then
    XCTAssertNil(strongHeartbeatStorage)
    XCTAssertNil(weakHeartbeatStorage)
  }

  func testCachedInstancesAreRemovedUponDeinitAndCanBeRetainedStrongly() {
    // Given
    var heartbeatStorage1: HeartbeatStorage? = .getInstance(id: "sparky")
    var heartbeatStorage2: HeartbeatStorage? = .getInstance(id: "sparky")
    XCTAssert(
      heartbeatStorage1 === heartbeatStorage2,
      "Instances should reference the same object."
    )

    // When
    heartbeatStorage1 = nil
    XCTAssertNil(heartbeatStorage1)
    XCTAssertNotNil(heartbeatStorage2)

    // Then
    heartbeatStorage2 = nil
    XCTAssertNil(heartbeatStorage2)
  }
}

// MARK: - HeartbeatStorageProtocol

// TODO: Do these make sense?
func savingToStorage_WhenWriteFails_ReturnsNil() {}
func savingToStorage_WhenEncodingFails_ReturnsNil() {}

extension HeartbeatStorageTests {
  func testGetAndResetDefaultsToClearingStorage() throws {
    // Given
    let heartbeatStorage = HeartbeatStorage(id: #file, storage: StorageFake())
    heartbeatStorage.readAndWriteAsync { _ in
      HeartbeatInfo(capacity: 1)
    }
    // When
    try heartbeatStorage.getAndReset()
    // Then
    try heartbeatStorage.getAndReset { heartbeatInfo in
      XCTAssertNil(heartbeatInfo)
      return heartbeatInfo
    }
  }

  func testGetAndResetThrowsIfSaveFails() {
    // Given
    let expectation = expectation(description: #function)
    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #file, storage: storageFake)

    // When
    storageFake.onWrite = { _ in
      expectation.fulfill()
      throw DummyError.error
    }

    // Then
    XCTAssertThrowsError(try heartbeatStorage.getAndReset())
    wait(for: [expectation], timeout: 0.5)
  }

  func loadingFromStorage_WhenDecodingFails_ReturnsNil() throws {
    // Given
    let expectation = expectation(description: #function)
    expectation.expectedFulfillmentCount = 4

    let storageFake = StorageFake()
    let decoderFake = DecoderFake()
    let heartbeatStorage = HeartbeatStorage(
      id: #file,
      storage: storageFake,
      decoder: decoderFake
    )

    // When
    decoderFake.onDecode = {
      expectation.fulfill() // Fulfilled 2 times.
      throw DummyError.error
    }

    // Then
    heartbeatStorage.readAndWriteAsync { heartbeatInfo in
      expectation.fulfill() // Fulfilled 1 time.
      XCTAssertNil(heartbeatInfo)
      return nil
    }

    try heartbeatStorage.getAndReset { heartbeatInfo in
      expectation.fulfill() // Fulfilled 1 time.
      XCTAssertNil(heartbeatInfo)
      return nil
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func loadingFromStorage_WhenReadFails_ReturnsNil() throws {
    // Given
    let expectation = expectation(description: #function)
    expectation.expectedFulfillmentCount = 4

    let storageFake = StorageFake()
    let heartbeatStorage = HeartbeatStorage(id: #file, storage: storageFake)

    // When
    storageFake.onRead = {
      expectation.fulfill() // Fulfilled 2 times.
      throw DummyError.error
    }

    // Then
    heartbeatStorage.readAndWriteAsync { heartbeatInfo in
      expectation.fulfill() // Fulfilled 1 time.
      XCTAssertNil(heartbeatInfo)
      return nil
    }

    try heartbeatStorage.getAndReset { heartbeatInfo in
      expectation.fulfill() // Fulfilled 1 time.
      XCTAssertNil(heartbeatInfo)
      return nil
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func testReadAndWriteThenGetAndSet() {
    let storage = HeartbeatStorage(id: #file, storage: StorageFake())

    let expectation = expectation(description: #function)

    storage.readAndWriteAsync { heartbeatInfo in
      XCTAssertNil(heartbeatInfo)
      expectation.fulfill()
      return heartbeatInfo
    }

    wait(for: [expectation], timeout: 0.5)
  }

  func testOperationsAreSynrononizedSerially() throws {
    // Given
    var expectations: [XCTestExpectation] = []
    let heartbeatStorage = HeartbeatStorage(id: #file, storage: StorageFake())

    // When
    for i in 0 ... 1000 {
      let expectation = expectation(description: "\(#function)_\(i)")

      expectations.append(expectation)

      let transform: HeartbeatInfoTransform = { heartbeatInfo in
        expectation.fulfill()
        return heartbeatInfo
      }

      if /* randomChoice */ .random() {
        heartbeatStorage.readAndWriteAsync(using: transform)
      } else {
        try heartbeatStorage.getAndReset(using: transform)
      }
    }

    // Then
    wait(for: expectations, timeout: 1.0, enforceOrder: true)
  }

  // MARK: - HeartbeatStorage + StorageFactory

  // TODO: Implement factory tests.

  // MARK: - Fakes

  enum DummyError: Error {
    case error
  }

  class EncoderFake: AnyEncoder {
    var onEncode: (() throws -> Void)?

    func encode<T>(_ value: T) throws -> Data where T: Encodable {
      try onEncode?()
      return try JSONEncoder().encode(value)
    }
  }

  class DecoderFake: AnyDecoder {
    var onDecode: (() throws -> Void)?

    func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
      try onDecode?()
      return try JSONDecoder().decode(type, from: data)
    }
  }

  class StorageFake: Storage {
    private var data: Data?

    var onRead: (() throws -> Data)?
    var onWrite: ((Data?) throws -> Void)?

    func read() throws -> Data {
      if let onRead = onRead {
        return try onRead()
      } else {
        return try data ?? { throw DummyError.error }()
      }
    }

    func write(_ value: Data?) throws {
      if let onWrite = onWrite {
        return try onWrite(value)
      } else {
        data = value
      }
    }
  }
}
