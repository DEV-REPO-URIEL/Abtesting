/*
 * Copyright 2021 Google LLC
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

import GRPC
import Darwin

@objc public class GRPCStatusShim: NSObject {
  private var status: GRPCStatus
  @objc override public init() {
    status = GRPCStatus.ok
  }

  @objc public init(status: UInt8, message: String) {
    self.status = GRPCStatus(code: GRPCStatus.Code(rawValue: Int(status))!, message: message)
  }

  @objc public func errorCode() -> Int {
    return status.code.rawValue
  }

  @objc public func errorMessage() -> String {
    return status.message ?? ""
  }

  @objc public func ok() -> Bool {
    return status.isOk
  }
}
