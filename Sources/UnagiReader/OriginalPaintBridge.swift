import AppKit
import WebKit

/// Tells the app when the original page has painted its first content (issue #218), so that the web view can stay hidden behind the app's
/// surface until then. `didCommit` is too early: the page is still blank and transparent. The page's own scripts cannot see this: it runs
/// in its own content world, and only posts one number.
@MainActor final class OriginalPaintBridge: NSObject, WKScriptMessageHandler {
    static let world = WKContentWorld.world(name: "UnagiReaderPaint")
    private let onPainted: () -> Void
    init(onPainted: @escaping () -> Void) { self.onPainted = onPainted }

    func install(in view: WKWebView) {
        let controller = view.configuration.userContentController
        controller.add(self, contentWorld: Self.world, name: "unagiReaderPainted")
        let source = """
        (() => {
          let done = false;
          const post = () => { if (done) return; done = true; window.webkit.messageHandlers.unagiReaderPainted.postMessage(1); };
          try {
            new PerformanceObserver(list => {
              if (list.getEntries().some(entry => entry.name === 'first-contentful-paint')) post();
            }).observe({ type: 'paint', buffered: true });
          } catch (error) {}
        })();
        """
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: Self.world))
    }
    func uninstall(from view: WKWebView) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "unagiReaderPainted", contentWorld: Self.world)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onPainted()
    }
}
