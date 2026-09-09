import SwiftUI
import WebKit
import ReaderCore

struct OriginalPageView: View {
    let url: URL
    let onClose: () -> Void
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Label("記事に戻る", systemImage: "chevron.left") }
                    .help("記事に戻る (Esc)")
                Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
            }.padding(10).background(.bar)
            if let failure {
                ContentUnavailableView("元ページを開けませんでした", systemImage: "wifi.exclamationmark", description: Text(failure))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                OriginalWebView(url: url, onClose: onClose, onFailure: { failure = $0 })
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onExitCommand(perform: onClose)
    }
}

private struct OriginalWebView: NSViewRepresentable {
    let url: URL
    let onClose: () -> Void
    let onFailure: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onClose: onClose, onFailure: onFailure) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // This offline development slice does not use or retain login sessions.
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        context.coordinator.installEscape(for: view)
        view.load(URLRequest(url: url))
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor); coordinator.monitor = nil }
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onClose: () -> Void
        let onFailure: (String) -> Void
        var monitor: Any?
        init(onClose: @escaping () -> Void, onFailure: @escaping (String) -> Void) { self.onClose = onClose; self.onFailure = onFailure }
        func installEscape(for view: WKWebView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak view] event in
                guard let self, let view, event.keyCode == 53, event.window === view.window,
                      (view.window?.firstResponder as? NSTextInputClient)?.hasMarkedText() != true else { return event }
                self.onClose(); return nil
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, ArticleURL.validated(url.absoluteString) != nil else { decisionHandler(.cancel); return }
            if action.targetFrame == nil { webView.load(action.request); decisionHandler(.cancel) }
            else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        private func report(_ error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { onFailure(error.localizedDescription) }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    }
}
