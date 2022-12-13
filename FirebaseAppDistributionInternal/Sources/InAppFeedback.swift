// Copyright 2022 Google LLC
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
import UIKit

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  @objc(feedbackViewController) public static func feedbackViewController() -> UIViewController {
    let frameworkBundle = Bundle(for: self)

    let resourceBundleURL = frameworkBundle.url(
      forResource: "AppDistributionInternalResources",
      withExtension: "bundle"
    )
    let resourceBundle = Bundle(url: resourceBundleURL)

    let storyboard = UIStoryboard(
      name: "FIRAppDistributionInternalStoryboard",
      bundle: resourceBundle
    )
    let vc = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf")
    return vc
  }
}
