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

class HeartbeatsPayloadTests: XCTestCase {
  func testEmptyPayload() {
    XCTAssertEqual(
      HeartbeatsPayload.emptyPayload,
      HeartbeatsPayload(heartbeats: [])
    )
  }

  func testEncodeAndDecode() throws {
    // Given
    let heartbeatsPayload = HeartbeatsPayload(
      heartbeats: [
        .init(agent: "agent_1", dates: [Date()]),
      ]
    )

    // When
    let encodedPayload = try JSONEncoder().encode(heartbeatsPayload)
    let decodedPayload = try JSONDecoder().decode(HeartbeatsPayload.self, from: encodedPayload)

    // Then
    XCTAssertEqual(decodedPayload, heartbeatsPayload)
  }

  func testGetHeaderValue() throws {
    // Given
    let date1 = Date(timeIntervalSince1970: 1_635_739_200) // 2021-11-01
    let date2 = date1.addingTimeInterval(60 * 60 * 24) // 2021-11-02
    let date3 = date2.addingTimeInterval(60 * 60 * 24) // 2021-11-03
    let date4 = date3.addingTimeInterval(60 * 60 * 24) // 2021-11-04
    let date5 = date4.addingTimeInterval(60 * 60 * 24) // 2021-11-05

    let heartbeatsPayload = HeartbeatsPayload(
      heartbeats: [
        .init(agent: "agent_1", dates: [date1, date2]),
        .init(agent: "agent_2", dates: [date3, date4]),
        .init(agent: "agent_3", dates: [date5]),
      ]
    )

    // When
    let headerValue = heartbeatsPayload.headerValue()

    // Then
    try assertEqualPayloadStrings(
      headerValue,
      """
      {
        "version": 2,
        "heartbeats": [
          {
            "agent": "agent_1",
            "dates": ["2021-11-01", "2021-11-02"]
          },
          {
            "agent": "agent_2",
            "dates": ["2021-11-03", "2021-11-04"]
          },
          {
            "agent": "agent_3",
            "dates": ["2021-11-05"]
          }
        ]
      }
      """
    )
  }

  func testGetHeaderValue_WhenEmptyPayload_ReturnsEmptyString() {
    // Given
    let heartbeatsPayload = HeartbeatsPayload.emptyPayload

    // When
    let headerValue = heartbeatsPayload.headerValue()

    // Then
    XCTAssertEqual(headerValue, "")
  }
}
