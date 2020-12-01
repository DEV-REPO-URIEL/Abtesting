// Copyright 2020 Google LLC
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

/// Model info object with details about pending or downloaded model.
struct ModelInfo {
  /// Model name.
  let name: String

  // TODO: revisit UserDefaultsBacked
  /// Download URL for the model file, as returned by server.
  let downloadURL: String

  /// Hash of the model, as returned by server.
  let modelHash: String

  /// Size of the model, as returned by server.
  let size: Int

  /// Local path of the model.
  var path: String?

  /// Initialize model info and create user default keys.
  init(name: String, downloadURL: String, modelHash: String, size: Int) {
    self.name = name
    self.downloadURL = downloadURL
    self.modelHash = modelHash
    self.size = size
  }

  func writeToDefaults(app: FirebaseApp, defaults: UserDefaults) {
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let defaultsPrefix = "\(bundleID).\(app.name).\(name)"
    defaults.setValue(downloadURL, forKey: "\(defaultsPrefix).model-download-url")
    defaults.setValue(modelHash, forKey: "\(defaultsPrefix).model-hash")
    defaults.setValue(size, forKey: "\(defaultsPrefix).model-size")
    defaults.setValue(path, forKey: "\(defaultsPrefix).model-path")
  }
}
