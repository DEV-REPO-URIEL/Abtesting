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

import SwiftUI
import FirebaseFirestore

@available(iOS 14.0, macOS 11.0, macCatalyst 14.0, tvOS 14.0, watchOS 7.0, *)
internal class FirestoreQueryObservable<T>: ObservableObject {
  @Published var result: T

  private let firestore = Firestore.firestore()
  private var listener: ListenerRegistration?

  private var setupListener: (() -> Void)!

  internal var shouldUpdateListener = true
  internal var configuration: FirestoreQuery<T>.Configuration {
    didSet {
      // prevent never-ending update cycle when updating the error field
      guard shouldUpdateListener else { return }

      removeListener()
      setupListener()
    }
  }

  init<U: FirestoreDocumentReferable & Codable>(configuration: FirestoreQuery<T>.Configuration)
    where T == FirestoreQueryResult<U> {
    result = FirestoreQueryResult()
    self.configuration = configuration

    setupListener = createListener { [weak self] querySnapshot, error in
      if let error = error {
        self?.result.items = []

        self?.result.error = error
        self?.result.results = .failure(error)
        self?.projectError(error)
        return
      } else {
        self?.result.error = nil
        self?.projectError(nil)
      }

      guard let documents = querySnapshot?.documents else {
        self?.result.items = []
        self?.result.results = .success([])
        return
      }

      let decodedDocuments: [U] = documents.compactMap { queryDocumentSnapshot in
        let result = Result { try queryDocumentSnapshot.decode(as: U.self) }
        switch result {
        case let .success(decodedDocument):
          return decodedDocument
        case let .failure(error):
          self?.result.error = error
          self?.projectError(error)
          return nil
        }
      }

      if let error = self?.result.error,
        self?.configuration.decodingFailureStrategy == .raise {
        self?.result.items = []
        self?.result.results = .failure(error)
      } else {
        self?.result.items = decodedDocuments
        self?.result.results = .success(decodedDocuments)
      }

      self?.result.delete = { [weak self] documentID in
        guard let self = self else { return }

        self.firestore.collection(self.configuration.path).document(documentID).delete()
      }
      self?.result.add = { [weak self] document in
        guard let self = self else { return }

        _ = try? self.firestore.collection(self.configuration.path)
          .addDocument(from: document)
      }

      self?.objectWillChange.send()
    }
    setupListener()
  }

  init<U: Decodable>(configuration: FirestoreQuery<T>.Configuration) where T == [U] {
    result = []
    self.configuration = configuration
    setupListener = createListener { [weak self] querySnapshot, error in
      if let error = error {
        self?.result = []
        self?.projectError(error)
        return
      } else {
        self?.projectError(nil)
      }

      guard let documents = querySnapshot?.documents else {
        self?.result = []
        return
      }

      let decodedDocuments: [U] = documents.compactMap { queryDocumentSnapshot in
        let result = Result { try queryDocumentSnapshot.data(as: U.self) }
        switch result {
        case let .success(decodedDocument):
          return decodedDocument
        case let .failure(error):
          self?.projectError(error)
          return nil
        }
      }

      if self?.configuration.error != nil {
        if configuration.decodingFailureStrategy == .raise {
          self?.result = []
        } else {
          self?.result = decodedDocuments
        }
      } else {
        self?.result = decodedDocuments
      }
    }

    setupListener()
  }

  init<U: Decodable>(configuration: FirestoreQuery<T>.Configuration)
    where T == Result<[U], Error> {
    result = .success([])
    self.configuration = configuration
    setupListener = createListener { [weak self] querySnapshot, error in
      if let error = error {
        self?.result = .failure(error)
        self?.projectError(error)
        return
      } else {
        self?.projectError(nil)
      }

      guard let documents = querySnapshot?.documents else {
        self?.result = .success([])
        return
      }

      let decodedDocuments: [U] = documents.compactMap { queryDocumentSnapshot in
        let result = Result { try queryDocumentSnapshot.data(as: U.self) }
        switch result {
        case let .success(decodedDocument):
          return decodedDocument
        case let .failure(error):
          self?.projectError(error)
          return nil
        }
      }

      if let error = self?.configuration.error {
        if configuration.decodingFailureStrategy == .raise {
          self?.result = .failure(error)
        } else {
          self?.result = .success(decodedDocuments)
        }
      } else {
        self?.result = .success(decodedDocuments)
      }
    }

    setupListener()
  }

  deinit {
    removeListener()
  }

  private func createListener(with handler: @escaping (QuerySnapshot?, Error?) -> Void)
    -> () -> Void {
    return {
      var query: Query = self.firestore.collection(self.configuration.path)

      for predicate in self.configuration.predicates {
        switch predicate {
        case let .isEqualTo(field, value):
          query = query.whereField(field, isEqualTo: value)
        case let .isIn(field, values):
          query = query.whereField(field, in: values)
        case let .isNotIn(field, values):
          query = query.whereField(field, notIn: values)
        case let .arrayContains(field, value):
          query = query.whereField(field, arrayContains: value)
        case let .arrayContainsAny(field, values):
          query = query.whereField(field, arrayContainsAny: values)
        case let .isLessThan(field, value):
          query = query.whereField(field, isLessThan: value)
        case let .isGreaterThan(field, value):
          query = query.whereField(field, isGreaterThan: value)
        case let .isLessThanOrEqualTo(field, value):
          query = query.whereField(field, isLessThanOrEqualTo: value)
        case let .isGreaterThanOrEqualTo(field, value):
          query = query.whereField(field, isGreaterThanOrEqualTo: value)
        case let .orderBy(field, value):
          query = query.order(by: field, descending: value)
        case let .limitTo(field):
          query = query.limit(to: field)
        case let .limitToLast(field):
          query = query.limit(toLast: field)
        }
      }

      self.listener = query.addSnapshotListener(handler)
    }
  }

  private func projectError(_ error: Error?) {
    shouldUpdateListener = false
    configuration.error = error
    shouldUpdateListener = true
  }

  private func removeListener() {
    listener?.remove()
    listener = nil
  }
}
