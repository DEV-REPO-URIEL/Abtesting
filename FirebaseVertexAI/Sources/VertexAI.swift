// Copyright 2024 Google LLC
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

import FirebaseAppCheckInterop
import FirebaseCore
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
@_implementationOnly import FirebaseCoreExtension

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public class VertexAI: NSObject {
  // MARK: - Public APIs

  /// The default `VertexAI` instance.
  ///
  /// - Returns: An instance of `VertexAI`, configured with the default `FirebaseApp`.
  public static func vertexAI() -> VertexAI {
    guard let app = FirebaseApp.app() else {
      fatalError("No instance of the default Firebase app was found.")
    }

    return vertexAI(app: app)
  }

  /// Creates an instance of `VertexAI` configured with a custom `FirebaseApp`.
  ///
  /// - Parameter app: The custom `FirebaseApp` used for initialization.
  /// - Returns: A `VertexAI` instance, configured with the custom `FirebaseApp`.
  public static func vertexAI(app: FirebaseApp) -> VertexAI {
    guard let provider = ComponentType<VertexAIProvider>.instance(for: VertexAIProvider.self,
                                                                  in: app.container) else {
      fatalError("No \(VertexAIProvider.self) instance found for Firebase app: \(app.name)")
    }

    return provider.vertexAI()
  }

  /// Initializes a generative model with the given parameters.
  ///
  /// - Parameters:
  ///   - modelName: The name of the model to use, e.g., `"gemini-1.0-pro"`; see
  ///     [Gemini
  ///     models](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/models#gemini-models)
  ///     for a list of supported model names.
  ///   - location: The location identifier, e.g., `us-central1`; see
  ///     [Vertex AI
  ///     regions](https://cloud.google.com/vertex-ai/docs/general/locations#vertex-ai-regions)
  ///     for a list of supported locations.
  ///   - generationConfig: The content generation parameters your model should use.
  ///   - safetySettings: A value describing what types of harmful content your model should allow.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  public func generativeModel(modelName: String, location: String,
                              generationConfig: GenerationConfig? = nil,
                              safetySettings: [SafetySetting]? = nil,
                              requestOptions: RequestOptions = RequestOptions())
    -> GenerativeModel {
    let modelResourceName = modelResourceName(modelName: modelName, location: location)

    guard let apiKey = app.options.apiKey else {
      fatalError("The Firebase app named \"\(app.name)\" has no API key in its configuration.")
    }

    return GenerativeModel(
      name: modelResourceName,
      apiKey: apiKey,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      requestOptions: requestOptions,
      appCheck: appCheck
    )
  }

  // MARK: - Private

  /// The `FirebaseApp` associated with this `VertexAI` instance.
  private let app: FirebaseApp

  private let appCheck: AppCheckInterop?

  init(app: FirebaseApp) {
    self.app = app
    appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self, in: app.container)
  }

  private func modelResourceName(modelName: String, location: String) -> String {
    if modelName.contains("/") {
      return modelName
    }
    guard let projectID = app.options.projectID else {
      fatalError("The Firebase app named \"\(app.name)\" has no project ID in its configuration.")
    }
    guard !location.isEmpty else {
      fatalError("""
      No location specified; see
      https://cloud.google.com/vertex-ai/generative-ai/docs/learn/locations#available-regions for a
      list of available regions.
      """)
    }

    return "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelName)"
  }
}
