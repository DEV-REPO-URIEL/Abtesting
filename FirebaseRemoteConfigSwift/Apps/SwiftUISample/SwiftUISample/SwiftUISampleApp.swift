/*
 * Copyright 2022 Google LLC
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
import FirebaseCore
import FirebaseRemoteConfig
import FirebaseRemoteConfigSwift

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    let config = RemoteConfig.remoteConfig()
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    config.configSettings = settings
    try? config.setDefaults(from: ["mobileweek":["section 0": "Breakfast"]])
    //      return true
    //
    //    }
    
    _ = RemoteConfig.remoteConfig().add(onConfigUpdateListener: { error in
      guard error == nil else {
        return
      }
      RemoteConfig.remoteConfig().activate { changed, error in
        guard error == nil && changed else {
          return
        }
      }
    })
    return true
  }
}

@main
struct SwiftUISampleApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup {
      ContentView(realtimeToggle: false)
    }
  }
    
}
