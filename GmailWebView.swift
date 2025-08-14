import SwiftUI
import WebKit
import AppKit

struct GmailWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webConfig = WKWebViewConfiguration()
        webConfig.preferences.javaScriptEnabled = true
        webConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfig.websiteDataStore = .default()

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "unread")
        webConfig.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
        webView.allowsBackForwardNavigationGestures = true

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private var lastUnreadCount: Int = 0

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.canChooseFiles = true
            panel.begin { result in
                if result == .OK {
                    completionHandler(panel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectUnreadObserver(into: webView)
        }

        private func injectUnreadObserver(into webView: WKWebView) {
            let js = #"""
            (function() {
              function getUnreadFromTitle() {
                var m = document.title && document.title.match(/\((\d+)\)/);
                return m ? parseInt(m[1], 10) : 0;
              }
              function notify() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.unread) {
                  window.webkit.messageHandlers.unread.postMessage({ count: getUnreadFromTitle() });
                }
              }
              try {
                var obs = new MutationObserver(function(){ notify(); });
                var titleEl = document.querySelector('title');
                if (titleEl) {
                  obs.observe(titleEl, { subtree: true, characterData: true, childList: true });
                } else {
                  obs.observe(document.documentElement, { subtree: true, characterData: true, childList: true });
                }
              } catch (e) {}
              setInterval(notify, 5000);
              notify();
            })();
            """#
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        @objc func handleUnreadMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let count = body["count"] as? Int else { return }
            updateDockBadge(unread: count)
            if count > lastUnreadCount {
                let delta = count - lastUnreadCount
                NotificationManager.shared.postLocalNotification(title: "New Mail", body: "\(delta) unread")
            }
            lastUnreadCount = count
        }

        // WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "unread" {
                handleUnreadMessage(message)
            }
        }

        private func updateDockBadge(unread: Int) {
            DispatchQueue.main.async {
                NSApp.dockTile.badgeLabel = unread > 0 ? String(unread) : nil
                NSApplication.shared.dockTile.display()
            }
        }
    }
}
