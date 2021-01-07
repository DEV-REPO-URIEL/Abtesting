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

/// Manager for common file operations.
enum ModelFileManager {
  private static let nameSeparator = "__"
  private static let modelNamePrefix = "fbml_model"
  private static let fileManager = FileManager.default

  /// Root directory of model file storage on device.
  static var modelsDirectory: URL {
    // TODO: Reconsider force unwrapping.
    #if os(tvOS)
      return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    #else
      return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    #endif
  }

  /// Name for model file stored on device.
  private static func getDownloadedModelFileName(appName: String, modelName: String) -> String {
    return [modelNamePrefix, appName, modelName].joined(separator: nameSeparator)
  }

  /// Model name from file path.
  static func getModelNameFromFilePath(_ path: URL) -> String? {
    return path.lastPathComponent.components(separatedBy: nameSeparator).last
  }

  /// Full path of model file stored on device.
  static func getDownloadedModelFilePath(appName: String, modelName: String) -> URL {
    let modelFileName = ModelFileManager.getDownloadedModelFileName(
      appName: appName,
      modelName: modelName
    )
    return ModelFileManager.modelsDirectory
      .appendingPathComponent(modelFileName)
  }

  /// Check if file is available at URL.
  static func isFileReachable(at fileURL: URL) -> Bool {
    do {
      return try fileURL.checkResourceIsReachable()
    } catch {
      /// File unreachable.
      return false
    }
  }

  /// Move file at a location to another location.
  static func moveFile(at sourceURL: URL, to destinationURL: URL) throws {
    if isFileReachable(at: destinationURL) {
      do {
        try fileManager.removeItem(at: destinationURL)
      } catch {
        throw DownloadError
          .internalError(
            description: "Could not replace existing model file - \(error.localizedDescription)"
          )
      }
    }
    do {
      try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    } catch {
      throw DownloadError
        .internalError(description: "Unable to save model file - \(error.localizedDescription)")
    }
  }

  /// Remove model file at a specific location.
  static func removeFile(at url: URL) throws {
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw DownloadedModelError
        .internalError(
          description: "Could not delete old model file - \(error.localizedDescription)"
        )
    }
  }

  static func contentsOfModelsDirectory() throws -> [URL] {
    do {
      let directoryContents = try ModelFileManager.fileManager.contentsOfDirectory(
        at: modelsDirectory,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
      )
      return directoryContents.filter { directoryItem in
        !directoryItem.hasDirectoryPath
      }
    } catch {
      throw DownloadedModelError
        .internalError(
          description: "Could not retrieve model files in directory - \(error.localizedDescription)"
        )
    }
  }
}
