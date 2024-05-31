/*
 * Copyright 2020 Google LLC
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

import Foundation

import FirebaseManifest
import Utils

enum InitializeRelease {
  static func setupRepo(gitRoot: URL) -> String {
    let manifest = FirebaseManifest.shared
    let branch = createVersionBranch(path: gitRoot, version: manifest.version)
    updatePodspecs(path: gitRoot, manifest: manifest)
    updatePodfiles(path: gitRoot, version: manifest.version)
    updateSwiftPackageVersion(path: gitRoot, version: manifest.version)
    return branch
  }

  /// The branch is based on the minor version to represent this is the branch for subsequent
  /// patches.
  private static func createVersionBranch(path: URL, version: String) -> String {
    let versionParts = version.split(separator: ".")
    let minorVersion = "\(versionParts[0]).\(versionParts[1])"
    let branch = "version-\(minorVersion)"
    Shell.executeCommand("git checkout \(branch) 2>/dev/null || git checkout -b \(branch)", workingDir: path)
    return branch
  }

  /// Update the podspec versions.
  private static func updatePodspecs(path: URL, manifest: FirebaseManifest.Manifest) {
    for pod in manifest.pods {
      let version = manifest.versionString(pod)
      let podspecPath = path.appendingPathComponent("\(pod.name).podspec")
      if pod.name == "Firebase" || version.hasSuffix(".0.0") {
        updateFirebasePodspec(path: podspecPath, manifest: manifest)
      } else {
        // Pods depending on GoogleAppMeasurement and FirebaseFirestoreInternal specs
        // should pin the dependency to the new version.
        for dep in ["GoogleAppMeasurement", "FirebaseFirestoreInternal"] {
          updateDependenciesToLatest(dependency: dep, pod: pod, version: version, path: path)
        }
//
//        if version.hasSuffix(".0.0") {
//          print("mango: It's a major version update!")
//          path.appendingPathComponent("\().podspec")
//          updateFirebasePodspec(path: <#T##URL#>, manifest: <#T##Manifest#>)
//        }
//
      }
    }
  }

  /// Pods depending on GoogleAppMeasurement and FirebaseFirestoreInternal specs
  /// should pin the dependency to the new version.
  private static func updateDependenciesToLatest(dependency: String,
                                                 pod: Pod,
                                                 version: String,
                                                 path: URL) {
    let scripts: String = [
      #"-e "s|(\.dependency '"# + dependency + #"/?.*',).*|\1 '\#(version)'|""#,
      // Replace the pod's `version` attribute with the new version.
      #"-e "s|(\.version.*=[[:space:]]*) '.*|\1 '\#(version)'|""#,
    ].joined(separator: " ")

    let command = "sed -i.bak -E \(scripts) \(pod.podspecName())"
    Shell.executeCommand(command, workingDir: path)
  }

  // This function patches the versions in the Firebase.podspec. It uses Swift instead of sed
  // like the other version patching.
  // TODO: Choose one or the other mechanism.
  // TODO: If we keep Swift, consider using Scanner.
  private static func updateFirebasePodspec(path: URL, manifest: FirebaseManifest.Manifest) {
    let podspecFile = path
      print(podspecFile)
    var contents = ""
    do {
      contents = try String(contentsOfFile: podspecFile.path, encoding: .utf8)
    } catch {
      fatalError("Could not read Firebase podspec. \(error)")
    }
    let firebaseVersion = manifest.version
    for firebasePod in manifest.pods {
      let pod = firebasePod.name
      let version = firebasePod.isBeta ? firebaseVersion + "-beta" : firebaseVersion
      if pod == "Firebase" {
        // TODO: This block is redundant with `updatePodspecs`. Decide to go with Swift or sed.
        guard let range = contents.range(of: "s.version") else {
          fatalError("Could not find version of Firebase pod in podspec at \(podspecFile)")
        }
        // Replace version in string like s.version = '6.9.0'
        updateVersion(&contents, in: range, to: version)

      } else {
          print("foo")
        // Iterate through all the ranges of `pod`'s occurrences.
          print(pod)
        for range in contents.ranges(of: pod) {
            print(range)
          // Replace version in string like ss.dependency 'FirebaseCore', '6.3.0'.
          updateVersion(&contents, in: range, to: version)
        }
          print("baz")
      }
    }
    do {
      try contents.write(to: podspecFile, atomically: false, encoding: .utf8)
    } catch {
      fatalError("Failed to write \(podspecFile.path). \(error)")
    }
  }

  /// Update the existing version to the given version by writing to a given string using the
  /// provided range.
  /// - Parameters:
  ///   - contents: A reference to a String containing a version that will be updated.
  ///   - range: The range containing a version substring that will be updated.
  ///   - version: The version string to update to.
  private static func updateVersion(_ contents: inout String, in range: Range<String.Index>,
                                    to version: String) {
      print("bar1")
    var versionStartIndex = contents.index(after: range.upperBound)
    while !contents[versionStartIndex].isWholeNumber {
      versionStartIndex = contents.index(after: versionStartIndex)
    }
      print("bar2")
    var versionEndIndex = contents.index(after: versionStartIndex)
    while contents[versionEndIndex] != "'" {
      versionEndIndex = contents.index(after: versionEndIndex)
    }
      print("bar3")
    contents.replaceSubrange(versionStartIndex ..< versionEndIndex, with: version)
      print("bar3")
  }

  private static func updatePodfiles(path: URL, version: String) {
    // Update the Podfiles across the repo.
    let firestorePodfile = path.appendingPathComponent("Firestore")
      .appendingPathComponent("Example")
    let collisionPodfile = path.appendingPathComponent("SymbolCollisionTest")
    let sedCommand = "sed -i.bak -e \"s#\\(pod " +
      "'Firebase/CoreOnly',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"
    Shell.executeCommand(sedCommand, workingDir: firestorePodfile)

    let sedCommand2 = "sed -i.bak -e \"s#\\(pod " +
      "'Firebase',[[:space:]]*'\\).*'#\\1\(version)'#\" Podfile"
    Shell.executeCommand(sedCommand2, workingDir: collisionPodfile)
  }

  private static func updateSwiftPackageVersion(path: URL, version: String) {
    // Match strings like `let firebaseVersion = "7.7.0"` and update the version.
    Shell.executeCommand("sed -i.bak -e \"s/\\(let firebaseVersion.*=[[:space:]]*\\).*/\\1" +
      "\\\"\(version)\\\"/\" Package.swift", workingDir: path)
  }
}
