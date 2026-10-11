import SwiftUI
import WebKit
import ReaderCore

struct OriginalPageView: View {
    let url: URL
    let onClose: () -> Void
    let onCommand: (ReaderCommand) -> Void
    @State private var failure: String?
    @State private var loading = true
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Label("記事に戻る", systemImage: "chevron.left") }
                    .help("記事に戻る (Esc)")
                Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if loading {
                    ProgressView().controlSize(.small).frame(width: 16, height: 16)
                        .accessibilityLabel("元ページを読み込み中")
                }
            }.padding(10).background(.bar)
            if let failure {
                OriginalFailureView(message: failure, onCommand: onCommand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                OriginalWebView(url: url, onClose: onClose, onCommand: onCommand, onFailure: { loading = false; failure = $0 }, onLoading: { loading = $0 })
            }
        }
        .background(AppPalette.surfaceColor)
    }
}

// This input target exists only after the page has failed and its editable
// web content has been removed. It never handles keys from a live page input.
@MainActor final class OriginalFailureHostingView<Content: View>: NSHostingView<Content> {
    var onCommand: (ReaderCommand) -> Void = { _ in }
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard window?.firstResponder === self, window?.attachedSheet == nil,
              let command = ReaderKeyboardCommands.command(for: event) else { super.keyDown(with: event); return }
        onCommand(command)
    }
}

private struct OriginalFailureView: NSViewRepresentable {
    let message: String
    let onCommand: (ReaderCommand) -> Void
    private var content: AnyView {
        AnyView(ContentUnavailableView("元ページを開けませんでした", systemImage: "wifi.exclamationmark", description: Text(message)))
    }
    func makeNSView(context: Context) -> OriginalFailureHostingView<AnyView> {
        let view = OriginalFailureHostingView(rootView: content)
        view.sizingOptions = []
        view.onCommand = onCommand
        return view
    }
    func updateNSView(_ view: OriginalFailureHostingView<AnyView>, context: Context) {
        view.rootView = content; view.onCommand = onCommand
    }
}

@MainActor final class OriginalReaderWebView: WKWebView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Set this window's input target without activating another application.
        // Later clicks in page inputs retain their own focus.
        if let window { window.makeFirstResponder(self) }
    }
}

private struct OriginalWebView: NSViewRepresentable {
    let url: URL
    let onClose: () -> Void
    let onCommand: (ReaderCommand) -> Void
    let onFailure: (String) -> Void
    let onLoading: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure, onLoading: onLoading) }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Original-page browsing has a separate, temporary session.
        configuration.websiteDataStore = .nonPersistent()
        let view = OriginalReaderWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        context.coordinator.keyboard = OriginalKeyboardBridge(allowsSendToNote: true, onCommand: onCommand)
        context.coordinator.keyboard?.install(in: view)
        view.load(URLRequest(url: url))
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.active = false
        view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
        coordinator.keyboard?.uninstall(); coordinator.keyboard = nil
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onFailure: (String) -> Void
        let onLoading: (Bool) -> Void
        var active = true
        var keyboard: OriginalKeyboardBridge?
        init(onFailure: @escaping (String) -> Void, onLoading: @escaping (Bool) -> Void) {
            self.onFailure = onFailure; self.onLoading = onLoading
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { if active { onLoading(true) } }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { if active { onLoading(false) } }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, ArticleURL.validated(url.absoluteString) != nil else { decisionHandler(.cancel); return }
            if action.targetFrame == nil { webView.load(action.request); decisionHandler(.cancel) }
            else { decisionHandler(.allow) }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
        private func report(_ error: Error) {
            if active && (error as NSError).code != NSURLErrorCancelled { onFailure(error.localizedDescription) }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
    }
}
