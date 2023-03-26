// Copyright 2023 Google LLC
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

#if os(iOS)

  import Foundation
  import UIKit
  import WebKit

  // TODO: Uncomment after FIRAuth.m is gone.
  // public protocol AuthWebViewControllerDelegate: AnyObject {
//  func webViewControllerDidCancel(_ controller: AuthWebViewController)
//  func webViewController(_ controller: AuthWebViewController, canHandle url: URL) -> Bool
//  func webViewController(_ controller: AuthWebViewController, didFailWithError error: Error)
  // }

  @objc(FIRAuthWebViewController) public class AuthWebViewController: UIViewController,
    WKNavigationDelegate {
    // MARK: - Properties

    private var url: URL
    private weak var delegate: FIRAuthWebViewControllerDelegate?
    private weak var webView: AuthWebView?

    // MARK: - Initialization

    @objc(initWithURL:delegate:) public init(url: URL, delegate: FIRAuthWebViewControllerDelegate) {
      self.url = url
      self.delegate = delegate
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override public func loadView() {
      let webView = AuthWebView(frame: UIScreen.main.bounds)
      webView.webView.navigationDelegate = self
      view = webView
      self.webView = webView
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancel)
      )
    }

    override public func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      webView?.webView.load(URLRequest(url: url))
    }

    // MARK: - Actions

    @objc private func cancel() {
      delegate?.webViewControllerDidCancel(self)
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      let canHandleURL = delegate?.webViewController(
        self,
        canHandle: navigationAction.request.url ?? url
      ) ?? false
      if canHandleURL {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    }

    public func webView(_ webView: WKWebView,
                        didStartProvisionalNavigation navigation: WKNavigation!) {
      self.webView?.spinner.isHidden = false
      self.webView?.spinner.startAnimating()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      self.webView?.spinner.isHidden = true
      self.webView?.spinner.stopAnimating()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                        withError error: Error) {
      if (error as NSError).domain == NSURLErrorDomain,
         (error as NSError).code == NSURLErrorCancelled {
        // It's okay for the page to be redirected before it is completely loaded.  See b/32028062 .
        return
      }
      // Forward notification to our delegate.
      self.webView(webView, didFinish: navigation)
      delegate?.webViewController(self, didFailWithError: error)
    }
  }
#endif
