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

import UIKit

/// Firebase Auth supported identity providers and other methods of authentication
enum AuthMenu: String {
  case settings = "Settings"
  case google = "google.com"
  case apple = "apple.com"
  case twitter = "twitter.com"
  case microsoft = "microsoft.com"
  case gitHub = "github.com"
  case yahoo = "yahoo.com"
  case facebook = "facebook.com"
  case emailPassword = "password"
  case passwordless = "emailLink"
  case phoneNumber = "phone"
  case anonymous
  case custom
  case initRecaptcha

  /// More intuitively named getter for `rawValue`.
  var id: String { rawValue }

  /// The UI friendly name of the `AuthMenu`. Used for display.
  var name: String {
    switch self {
    case .settings:
      return "Settings"
    case .google:
      return "Google"
    case .apple:
      return "Apple"
    case .twitter:
      return "Twitter"
    case .microsoft:
      return "Microsoft"
    case .gitHub:
      return "GitHub"
    case .yahoo:
      return "Yahoo"
    case .facebook:
      return "Facebook"
    case .emailPassword:
      return "Email & Password Login"
    case .passwordless:
      return "Email Link/Passwordless"
    case .phoneNumber:
      return "Phone Number"
    case .anonymous:
      return "Anonymous Authentication"
    case .custom:
      return "Custom Auth System"
    case .initRecaptcha:
      return "Initialize reCAPTCHA Enterprise"
    }
  }

  /// Failable initializer to create an `AuthMenu` from it's corresponding `name` value.
  /// - Parameter rawValue: String value representing `AuthMenu`'s name or type.
  init?(rawValue: String) {
    switch rawValue {
    case "Settings":
      self = .settings
    case "Google":
      self = .google
    case "Apple":
      self = .apple
    case "Twitter":
      self = .twitter
    case "Microsoft":
      self = .microsoft
    case "GitHub":
      self = .gitHub
    case "Yahoo":
      self = .yahoo
    case "Facebook":
      self = .facebook
    case "Email & Password Login":
      self = .emailPassword
    case "Email Link/Passwordless":
      self = .passwordless
    case "Phone Number":
      self = .phoneNumber
    case "Anonymous Authentication":
      self = .anonymous
    case "Custom Auth System":
      self = .custom
    case "Initialize reCAPTCHA Enterprise":
      self = .initRecaptcha
    default: return nil
    }
  }
}

// MARK: DataSourceProvidable

extension AuthMenu: DataSourceProvidable {
  private static var providers: [AuthMenu] {
    [.google, .apple, .twitter, .microsoft, .gitHub, .yahoo, .facebook]
  }

  static var settingsSection: Section {
    let header = "Auth Settings"
    let item = Item(title: settings.name, hasNestedContent: true)
    return Section(headerDescription: header, items: [item])
  }

  static var providerSection: Section {
    let providers = self.providers.map { Item(title: $0.name) }
    let header = "Identity Providers"
    let footer = "Choose a login flow from one of the identity providers above."
    return Section(headerDescription: header, footerDescription: footer, items: providers)
  }

  static var emailPasswordSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let header = "Email and Password Login"
    let item = Item(title: emailPassword.name, hasNestedContent: true, image: image)
    return Section(headerDescription: header, items: [item])
  }

  static var otherSection: Section {
    let lockSymbol = UIImage.systemImage("lock.slash.fill", tintColor: .systemOrange)
    let phoneSymbol = UIImage.systemImage("phone.fill", tintColor: .systemOrange)
    let anonSymbol = UIImage.systemImage("questionmark.circle.fill", tintColor: .systemOrange)
    let shieldSymbol = UIImage.systemImage("lock.shield.fill", tintColor: .systemOrange)

    let otherOptions = [
      Item(title: passwordless.name, image: lockSymbol),
      Item(title: phoneNumber.name, image: phoneSymbol),
      Item(title: anonymous.name, image: anonSymbol),
      Item(title: custom.name, image: shieldSymbol),
    ]
    let header = "Other Authentication Methods"
    return Section(headerDescription: header, items: otherOptions)
  }

  static var recaptchaSection: Section {
    let image = UIImage(named: "firebaseIcon")
    let header = "Initialize reCAPTCHA Enterprise"
    let item = Item(title: initRecaptcha.name, hasNestedContent: false, image: image)
    return Section(headerDescription: header, items: [item])
  }

  static var sections: [Section] {
    [settingsSection, providerSection, emailPasswordSection, otherSection, recaptchaSection]
  }

  static var authLinkSections: [Section] {
    let allItems = AuthMenu.sections.flatMap { $0.items }
    let header = "Manage linking between providers"
    let footer =
      "Select an unchecked row to link the currently signed in user to that auth provider. To unlink the user from a linked provider, select its corresponding row marked with a checkmark."
    return [Section(headerDescription: header, footerDescription: footer, items: allItems)]
  }

  var sections: [Section] { AuthMenu.sections }
}
