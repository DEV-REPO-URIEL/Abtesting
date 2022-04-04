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

import Foundation

/// A type that provides a basic logger API.
public protocol Logger {
  associatedtype Logs
  func log(_ info: String)
  func flush(limit: Int?) -> Logs
}

// MARK: - HeartbeatLogger

/// A  logger object that provides API to log and flush heartbeats from a synchronized storage container.
public final class HeartbeatController {
  /// The thread-safe storage object to log and flush heartbeats from.
  private let storage: HeartbeatStorage

  /// Public initializer.
  ///
  /// - Parameter id: The `id` to associate this logger's internal storage with.
  public init(id: String) {
    let storage = StorageFactory.makeStorage(id: id)
    self.storage = HeartbeatStorage(id: id, storage: storage)
  }

  /// This initializer has `internal`access control and is ideal for injecting a storage container for testing.
  ///
  /// - Parameters:
  ///   - storage: The logger's internal storage object.
  init(storage: HeartbeatStorage) {
    self.storage = storage
  }
}

extension HeartbeatController: Logger {
  // TODO: - Re-evaluate below doc comment (move implementation explanation).
  /// Asynchronously attempts to log a new heartbeat.
  ///
  /// For each heartbeat type (i.e. daily, weekly, & monthly), a new heartbeat will be logged to a queue
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Parameter info: A `String?` identifier to associate a new heartbeat with.
  public func log(_ info: String) {
    let newHeartbeat = Heartbeat(info: info)
    storage.readWriteAsync { heartbeatData in
      for type in heartbeatData.types {
        heartbeatData.offer(newHeartbeat, type: type)
      }
    }
  }

  // TODO: - Re-evaluate below doc comment (move implementation explanation).
  /// Synchronously flushes heartbeats from storage.
  ///
  /// A round robin approach is used to fairly flush heartbeats of different types (daily, weekly, and monthly).
  ///
  /// - Note: This API is thread-safe.
  ///
  /// - Parameter limit: The max number of heartbeats to flush if not `nil`; otherwise, all
  /// heartbeats will be flushed from storage..
  /// - Returns: The flushed heartbeats in the form of `HeartbeatData`.
  @discardableResult
  public func flush(limit: Int? = nil) -> HeartbeatData {
    var flushed = HeartbeatData()
    storage.readWriteSync { heartbeatData in
      var (isFlushing, flushedCount) = (true, 0)
      while isFlushing {
        isFlushing = false
        for type in heartbeatData.types {
          if let limit = limit, flushedCount >= limit {
            // The given `limit` has been reached, so flushing should stop.
            break
          }
          // Flush a heartbeat from storage and save to `flushed`.
          if let flushedHeartbeat = heartbeatData.request(type: type) {
            if flushed.offer(flushedHeartbeat, type: type) {
              // Increment and indicate the flush is still in progress.
              flushedCount += 1
              isFlushing = true
            }
          }
        }
      }
    }
    return flushed
  }
}
