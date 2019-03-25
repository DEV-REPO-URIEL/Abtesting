/*
 * Copyright 2019 Google
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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTClock.h>
#import <GoogleDataTransport/GDTStoredEvent.h>

@interface GDTStoredEventTest : GDTTestCase

@end

@implementation GDTStoredEventTest

/** Tests the default initializer. */
- (void)testInit {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"testing" target:1];
  event.clockSnapshot = [GDTClock snapshot];
  GDTStoredEvent *storedEvent = [[GDTStoredEvent alloc] initWithFileURL:[NSURL URLWithString:@"1"]
                                                                  event:event];
  XCTAssertNotNil(storedEvent);
}

/** Tests encoding and decoding. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTStoredEvent supportsSecureCoding]);
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"testing" target:1];
  event.clockSnapshot = [GDTClock snapshot];
  event.qosTier = GDTEventQoSTelemetry;
  GDTStoredEvent *storedEvent = [[GDTStoredEvent alloc] initWithFileURL:[NSURL URLWithString:@"1"]
                                                                  event:event];
  XCTAssertNotNil(storedEvent);
  XCTAssertNotNil(storedEvent.mappingID);
  XCTAssertNotNil(storedEvent.target);
  XCTAssertEqual(storedEvent.qosTier, GDTEventQoSTelemetry);
  XCTAssertNotNil(storedEvent.clockSnapshot);
  XCTAssertNil(storedEvent.customPrioritizationParams);
  XCTAssertNotNil(storedEvent.eventFileURL);
}

/** Tests equality between GDTStoredEvents. */
- (void)testIsEqualAndHash {
  GDTEvent *event1 = [[GDTEvent alloc] initWithMappingID:@"1018" target:1];
  event1.clockSnapshot = [GDTClock snapshot];
  [event1.clockSnapshot setValue:@(1553534573010) forKeyPath:@"timeMillis"];
  [event1.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
  [event1.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
  [event1.clockSnapshot setValue:@(961141365197) forKeyPath:@"uptime"];
  event1.qosTier = GDTEventQosDefault;
  event1.customPrioritizationParams = @{@"customParam1" : @"aValue1"};
  GDTStoredEvent *storedEvent1 =
  [event1 storedEventWithFileURL:[NSURL fileURLWithPath:@"/tmp/fake.txt"]];

  GDTEvent *event2 = [[GDTEvent alloc] initWithMappingID:@"1018" target:1];
  event2.clockSnapshot = [GDTClock snapshot];
  [event2.clockSnapshot setValue:@(1553534573010) forKeyPath:@"timeMillis"];
  [event2.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
  [event2.clockSnapshot setValue:@(1552576634359451) forKeyPath:@"kernelBootTime"];
  [event2.clockSnapshot setValue:@(961141365197) forKeyPath:@"uptime"];
  event2.qosTier = GDTEventQosDefault;
  event2.customPrioritizationParams = @{@"customParam1" : @"aValue1"};
  GDTStoredEvent *storedEvent2 =
  [event2 storedEventWithFileURL:[NSURL fileURLWithPath:@"/tmp/fake.txt"]];

  XCTAssertEqual([storedEvent1 hash], [storedEvent2 hash]);
  XCTAssertEqualObjects(storedEvent1, storedEvent2);

  // This only really tests that changing the timezoneOffsetSeconds value causes a change in hash.
  [storedEvent2.clockSnapshot setValue:@(-25201) forKeyPath:@"timezoneOffsetSeconds"];

  XCTAssertNotEqual([storedEvent1 hash], [storedEvent2 hash]);
  XCTAssertNotEqualObjects(storedEvent1, storedEvent2);
}

@end
