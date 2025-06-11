import SwiftUI
import WebKit
import Network
import UserNotifications

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
    }
}

struct WebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = config.userContentController

        // JS to Swift bridge for notifications
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

        if let url = URL(string: "https://thelobby.ai/lobby/Urgent") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
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
