/*
 * Copyright 2023 Google LLC
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
import FirebaseFirestoreSwift

private struct Fruit: Codable, Identifiable, Equatable {
  @DocumentID var id: String?
  var name: String
  var isFavourite: Bool
}

struct FavouriteFruitsAsyncSequenceView: View {
  @State fileprivate var fruits: [Fruit] = []

  @State var showOnlyFavourites = true

  var body: some View {
    List(fruits) { fruit in
      Text(fruit.name)
    }
    .task {
      do {
        let collection = Firestore.firestore().collection("fruits")
        for try await fruits in collection.snapshotSequence(Fruit.self) {
          self.fruits = fruits
        }
      } catch {
        print(error)
      }
    }
    .animation(.default, value: fruits)
    .navigationTitle("Fruits")
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: toggleFilter) {
          Image(systemName: showOnlyFavourites
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle")
        }
      }
    }
  }

  func toggleFilter() {
    showOnlyFavourites.toggle()
  }
}

struct FavouriteFruitsAsyncSequenceView_Previews: PreviewProvider {
  static var previews: some View {
    FavouriteFruitsAsyncSequenceView()
  }
}
