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

import Foundation

/// CocoaPod related utility functions. The enum type is used as a namespace here instead of having
/// root functions, and no cases should be added to it.
public enum CocoaPodUtils {
  // MARK: - Public API

  public struct VersionedPod: Decodable {
    /// Public name of the pod.
    let name: String

    /// The version of the pod.
    let version: String?
  }

  /// Information associated with an installed pod.
  public struct PodInfo {
    let versionedPod: VersionedPod

    /// The pod dependencies
    let dependencies: [String]

    /// The location of the pod on disk.
    let installedLocation: URL

    var name: String { return versionedPod.name }
    var version: String { return versionedPod.version ?? "" }
  }

  /// Executes the `pod cache clean --all` command to remove any cached CocoaPods.
  public static func cleanPodCache() {
    let result = Shell.executeCommandFromScript("pod cache clean --all", outputToConsole: false)
    switch result {
    case let .error(code):
      fatalError("Could not clean the pod cache, the command exited with \(code). Try running the" +
        "command in Terminal to see what's wrong.")
    case .success:
      // No need to do anything else, continue on.
      print("Successfully cleaned pod cache.")
      return
    }
  }

  /// Gets metadata from installed Pods. Reads the `Podfile.lock` file and parses it.
  public static func installedPodsInfo(inProjectDir projectDir: URL) -> [PodInfo] {
    // Read from the Podfile.lock to get the installed versions and names.
    let podfileLock: String
    do {
      podfileLock = try String(contentsOf: projectDir.appendingPathComponent("Podfile.lock"))
    } catch {
      fatalError("Could not read contents of `Podfile.lock` to get installed Pod info in " +
        "\(projectDir): \(error)")
    }

    // Get the pods in the format of [PodInfo].
    return loadPodInfoFromPodfileLock(contents: podfileLock)
  }

  /// Install an array of pods in a specific directory, returning an array of PodInfo for each pod
  /// that was installed.
  @discardableResult
  public static func installPods(_ pods: [VersionedPod],
                                 inDir directory: URL,
                                 customSpecRepos: [URL]? = nil) -> [PodInfo] {
    let fileManager = FileManager.default
    // Ensure the directory exists, otherwise we can't install all subspecs.
    guard fileManager.directoryExists(at: directory) else {
      fatalError("Attempted to install subpecs (\(pods)) in a directory that doesn't exist: " +
        "\(directory)")
    }

    // Ensure there are actual podspecs to install.
    guard !pods.isEmpty else {
      fatalError("Attempted to install an empty array of subspecs")
    }

    // Attempt to write the Podfile to disk.
    do {
      try writePodfile(for: pods, toDirectory: directory, customSpecRepos: customSpecRepos)
    } catch let FileManager.FileError.directoryNotFound(path) {
      fatalError("Failed to write Podfile with pods \(pods) at path \(path)")
    } catch let FileManager.FileError.writeToFileFailed(path, error) {
      fatalError("Failed to write Podfile for all pods at path: \(path), error: \(error)")
    } catch {
      fatalError("Unspecified error writing Podfile for all pods to disk: \(error)")
    }

    // Run pod install on the directory that contains the Podfile and blank Xcode project.
    let result = Shell.executeCommandFromScript("pod _1.8.4_ install", workingDir: directory)
    switch result {
    case let .error(code, output):
      fatalError("""
      `pod install` failed with exit code \(code) while trying to install pods:
      \(pods)

      Output from `pod install`:
      \(output)
      """)
    case let .success(output):
      // Print the output to the console and return the information for all installed pods.
      print(output)
      return installedPodsInfo(inProjectDir: directory)
    }
  }

  /// Load installed Pods from the contents of a `Podfile.lock` file.
  ///
  /// - Parameter contents: The contents of a `Podfile.lock` file.
  /// - Returns: An array of PodInfo structs.
  public static func loadPodInfoFromPodfileLock(contents: String) -> [PodInfo] {
    // This pattern matches a pod name with its version (two to three components)
    // Examples:
    //  - FirebaseUI/Google (4.1.1):
    //  - GoogleSignIn (4.0.2):

    // Force unwrap the regular expression since we know it will work, it's a constant being passed
    // in. If any changes are made, be sure to run this script to ensure it works.
    let podRegex = try! NSRegularExpression(pattern: " - (.+) \\((\\d+\\.\\d+\\.?\\d*)\\)",
                                            options: [])
    let depRegex: NSRegularExpression = try! NSRegularExpression(pattern: " - (.+).*",
                                            options: [])
    let quotes = CharacterSet(charactersIn: "\"")
    var pods: [String: String] = [:]
    var deps: [String: [String]] = [:]
    var currentPod: String?
    contents.components(separatedBy: .newlines).forEach { line in
      if let (pod, version) = detectVersion(fromLine: line, matching: podRegex) {
        let corePod = pod.components(separatedBy: "/")[0]
        currentPod = corePod.trimmingCharacters(in: quotes)
        pods[currentPod!] = version
      } else if let curPod = currentPod {
        let matches = depRegex.matches(in: line, range: NSRange(location: 0, length: line.utf8.count))
        // Match something like - GTMSessionFetcher/Full (= 1.3.0)
        if let match = matches.first {
          let depLine = (line as NSString).substring(with: match.range(at: 0)) as String
          // Split leading dash, spaces, and subspecs.
          let dep = depLine.components(separatedBy: [" ","/","-"])[3]
          print ("Dependency -- \(depLine) for \(curPod) with \(dep)")
          deps[curPod]?.append(dep)
        }
      }
    }
    // Generate an InstalledPod for each Pod found.
    let podsDir = projectDir.appendingPathComponent("Pods")
    var installedPods: [PodInfo] = []
    for (podName, version) in pods {
      let podDir = podsDir.appendingPathComponent(podName)
      guard FileManager.default.directoryExists(at: podDir) else {
        fatalError("Directory for \(podName) doesn't exist at \(podDir) - failed while getting " +
          "information for installed Pods.")
      }
      let podInfo = PodInfo(versionedPod: VersionedPod(name: podName, version: version),
                            dependencies: deps[podName] ?? [], installedLocation: podDir)
      installedPods.append(podInfo)
    }
    return installedPods
  }

  public static func updateRepos() {
    let result = Shell.executeCommandFromScript("pod repo update")
    switch result {
    case let .error(_, output):
      fatalError("Command `pod repo update` failed: \(output)")
    case .success:
      return
    }
  }

  public static func podInstallPrepare(inProjectDir projectDir: URL) {
    do {
      // Create the directory and all intermediate directories.
      try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    } catch {
      // Use `do/catch` instead of `guard let tempDir = try?` so we can print the error thrown.
      fatalError("Cannot create temporary directory at beginning of script: \(error)")
    }
    // Copy the Xcode project needed in order to be able to install Pods there.
    let templateFiles = Constants.ProjectPath.requiredFilesForBuilding.map {
      paths.templateDir.appendingPathComponent($0)
    }
    for file in templateFiles {
      // Each file should be copied to the temporary project directory with the same name.
      let destination = projectDir.appendingPathComponent(file.lastPathComponent)
      do {
        if !FileManager.default.fileExists(atPath: destination.path) {
          print("Copying template file \(file) to \(destination)...")
          try FileManager.default.copyItem(at: file, to: destination)
        }
      } catch {
        fatalError("Could not copy template project to temporary directory in order to install " +
          "pods. Failed while attempting to copy \(file) to \(destination). \(error)")
      }
    }
  }

  // MARK: - Private Helpers

  // Tests the input to see if it matches a CocoaPod framework and its version.
  // Returns the framework and version or nil if match failed.
  // Used to process entries from Podfile.lock

  /// Tests the input and sees if it matches a CocoaPod framework and its version. This is used to
  /// process entries from Podfile.lock.
  ///
  /// - Parameters:
  ///   - input: A line entry from Podfile.lock.
  ///   - regex: The regex to match compared to the input.
  /// - Returns: A tuple of the framework and version, if it can be parsed.
  private static func detectVersion(fromLine input: String,
                                    matching regex: NSRegularExpression) -> (framework: String, version: String)? {
    let matches = regex.matches(in: input, range: NSRange(location: 0, length: input.utf8.count))
    let nsString = input as NSString

    guard let match = matches.first else {
      return nil
    }

    guard match.numberOfRanges == 3 else {
      print("Version number regex matches: expected 3, but found \(match.numberOfRanges).")
      return nil
    }

    let framework = nsString.substring(with: match.range(at: 1)) as String
    let version = nsString.substring(with: match.range(at: 2)) as String

    return (framework, version)
  }

  /// Create the contents of a Podfile for an array of subspecs. This assumes the array of subspecs
  /// is not empty.
  private static func generatePodfile(for pods: [VersionedPod],
                                      customSpecsRepos: [URL]? = nil) -> String {
    // Start assembling the Podfile.
    var podfile: String = ""

    // If custom Specs repos were passed in, prefix the Podfile with the custom repos followed by
    // the CocoaPods master Specs repo.
    if let customSpecsRepos = customSpecsRepos {
      let reposText = customSpecsRepos.map { "source '\($0)'" }
      podfile += """
      \(reposText.joined(separator: "\n"))
      source 'https://cdn.cocoapods.org/'

      """ // Explicit newline above to ensure it's included in the String.
    }

    // Include the minimum iOS version.
    podfile += """
    platform :ios, '\(LaunchArgs.shared.minimumIOSVersion)'
    target 'FrameworkMaker' do\n
    """

    // Loop through the subspecs passed in and use the actual Pod name.
    for pod in pods {
      let version = pod.version == nil ? "" : ", '\(pod.version!)'"
      podfile += "  pod '\(pod.name)'" + version + "\n"
    }

    podfile += "end"
    return podfile
  }

  /// Write a podfile that contains all the pods passed in to the directory passed in with a name
  /// "Podfile".
  private static func writePodfile(for pods: [VersionedPod],
                                   toDirectory directory: URL,
                                   customSpecRepos: [URL]?) throws {
    guard FileManager.default.directoryExists(at: directory) else {
      // Throw an error so the caller can provide a better error message.
      throw FileManager.FileError.directoryNotFound(path: directory.path)
    }

    // Generate the full path of the Podfile and attempt to write it to disk.
    let path = directory.appendingPathComponent("Podfile")
    let podfile = generatePodfile(for: pods, customSpecsRepos: customSpecRepos)
    do {
      try podfile.write(toFile: path.path, atomically: true, encoding: .utf8)
    } catch {
      throw FileManager.FileError.writeToFileFailed(file: path.path, error: error)
    }
  }
}
