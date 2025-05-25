import SwiftUI
import WebKit
import AppKit
import Network
import UserNotifications

struct ContentView: View {
    @StateObject private var webViewModel = WebViewModel()

    var body: some View {
        WebViewContainer(webViewModel: webViewModel)
            .ignoresSafeArea()
    }
}

class WebViewModel: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var title: String = ""

    let baseURL = "https://thelobby.ai/lobby/Urgent"

    private var monitor: NWPathMonitor?
    private var wasOffline = false

    func updateNavigationState(canGoBack: Bool, canGoForward: Bool) {
        DispatchQueue.main.async {
            self.canGoBack = canGoBack
            self.canGoForward = canGoForward
        }
    }

    func updateLoadingState(isLoading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = isLoading
        }
    }

    func updateTitle(_ title: String) {
        DispatchQueue.main.async {
            self.title = title
        }
    }

    func startNetworkMonitor(webView: WKWebView) {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if self?.wasOffline == true {
                        webView.reload()
                    }
                    self?.wasOffline = false
                } else {
                    self?.wasOffline = true
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
    }

    func stopNetworkMonitor() {
        monitor?.cancel()
        monitor = nil
    }
}

struct WebViewContainer: NSViewRepresentable {
    @ObservedObject var webViewModel: WebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = config.userContentController

        // ✅ JS -> Swift Notification bridge
        let notificationScript = """
        window.Notification = function(title, options) {
            window.webkit.messageHandlers.sendNotification.postMessage({
                title: title,
                body: options?.body || ""
            });
            return { permission: "granted" };
        };
        Notification.requestPermission = function(callback) {
            if (callback) callback("granted");
        };
        Notification.permission = "granted";
        """
        let script = WKUserScript(source: notificationScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)
        contentController.add(context.coordinator, name: "sendNotification")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(string: webViewModel.baseURL) {
            webView.load(URLRequest(url: url))
        }

        webViewModel.startNetworkMonitor(webView: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.webViewModel.updateLoadingState(isLoading: false)
            parent.webViewModel.updateTitle(webView.title ?? "")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.webViewModel.updateLoadingState(isLoading: true)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let host = url.host ?? ""
            let isInternal = host.hasSuffix("thelobby.ai")
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false

            print("[DEBUG] URL: \(url)")
            print("[DEBUG] Navigation Type: \(navigationAction.navigationType.rawValue)")
            print("[DEBUG] isMainFrame: \(isMainFrame)")

            if isInternal {
                decisionHandler(.allow)
                return
            }

            // ✅ Open external links only if they're navigating the main frame
            if isMainFrame {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // ✅ Allow subresources, Stripe scripts, OAuth redirects inside WebView
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                print("[DEBUG] createWebViewWith for: \(url)")
                NSWorkspace.shared.open(url)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
            if !enabled { return }

            if message.name == "sendNotification",
               let payload = message.body as? [String: Any],
               let title = payload["title"] as? String,
               let body = payload["body"] as? String {
                
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }

        }
    }
}

#Preview {
    ContentView()
}
