import SwiftUI
import WebKit
import AppKit

struct GmailWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webConfig = WKWebViewConfiguration()
        webConfig.defaultWebpagePreferences.allowsContentJavaScript = true
        webConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfig.websiteDataStore = .default()

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "unread")
        // Disable WebAuthn/Passkeys for Google domains to avoid OS authorization errors and use password/2FA instead
        let disablePasskeysJS = #"""
        (function(){
          try {
            var host = location.hostname || "";
            if (/\.google\.com$/.test(host) || host === "google.com") {
              try { Object.defineProperty(window, 'PublicKeyCredential', { value: undefined, configurable: true }); } catch(e) {}
              if (navigator.credentials) {
                try { navigator.credentials.create = async function(){ throw new Error('passkeys disabled'); }; } catch(e) {}
                try { navigator.credentials.get = async function(){ throw new Error('passkeys disabled'); }; } catch(e) {}
              }
            }
          } catch(e) {}
        })();
        """#
        let disableScript = WKUserScript(source: disablePasskeysJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(disableScript)
        webConfig.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // Spoof a modern Safari user agent so Gmail treats this as a supported browser
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true

        // Clear Gmail site data once so Gmail re-evaluates the new user agent and stops showing the unsupported banner
        let didClearKey = "DidClearGmailData_V2"
        let request = URLRequest(url: url)
        if !UserDefaults.standard.bool(forKey: didClearKey) {
            let store = webConfig.websiteDataStore
            let types: Set<String> = [
                WKWebsiteDataTypeCookies,
                WKWebsiteDataTypeLocalStorage,
                WKWebsiteDataTypeSessionStorage,
                WKWebsiteDataTypeIndexedDBDatabases,
                WKWebsiteDataTypeServiceWorkerRegistrations,
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeFetchCache,
                WKWebsiteDataTypeOfflineWebApplicationCache
            ]
            store.fetchDataRecords(ofTypes: types) { records in
                let hosts = [
                    "mail.google.com",
                    "gmail.com",
                    "google.com",
                    "accounts.google.com",
                    "apis.google.com",
                    "clients6.google.com"
                ]
                let matches = records.filter { record in
                    hosts.contains { host in record.displayName.contains(host) }
                }
                if matches.isEmpty {
                    webView.load(request)
                    return
                }
                store.removeData(ofTypes: types, for: matches) {
                    UserDefaults.standard.set(true, forKey: didClearKey)
                    webView.load(request)
                }
            }
        } else {
            webView.load(request)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // When URL changes (menu selection), navigate without losing cookies (same data store)
        if nsView.url?.host != url.host || nsView.url?.absoluteString != url.absoluteString {
            nsView.load(URLRequest(url: url))
        }
    }

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
