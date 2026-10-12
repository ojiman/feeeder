import AppKit
import WebKit

@MainActor final class OriginalKeyboardBridge: NSObject, WKScriptMessageHandler {
    static let world = WKContentWorld.world(name: "UnagiReaderKeys")
    private weak var view: WKWebView?
    private let onCommand: (ReaderCommand) -> Void
    init(onCommand: @escaping (ReaderCommand) -> Void) {
        self.onCommand = onCommand
    }
    func install(in view: WKWebView) {
        self.view = view
        let controller = view.configuration.userContentController
        controller.add(self, contentWorld: Self.world, name: "unagiReaderKey")
        let source = """
        (() => {
          const keys = new Set(['j','k','s','Escape']);
          document.addEventListener('keydown', event => {
            if (!event.isTrusted || event.isComposing || event.keyCode === 229 || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || !keys.has(event.key)) return;
            const path = event.composedPath();
            if (!path.length) return;
            if (path.some(node => node instanceof Element &&
              (node.matches('input,textarea,select,[role="textbox"],[role="combobox"]') || node.isContentEditable || node.tagName.includes('-')))) return;
            const active = document.activeElement;
            if (!active || active.matches('input,textarea,select,iframe,[role="textbox"],[role="combobox"]') || active.isContentEditable || active.tagName.includes('-')) return;
            event.preventDefault(); event.stopImmediatePropagation();
            window.webkit.messageHandlers.unagiReaderKey.postMessage(event.key);
          }, true);
        })();
        """
        controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: Self.world))
    }
    func uninstall() {
        view?.configuration.userContentController.removeScriptMessageHandler(forName: "unagiReaderKey", contentWorld: Self.world)
        view = nil
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let view, message.webView === view, let window = view.window, NSApp.keyWindow === window,
              window.attachedSheet == nil, let responder = window.firstResponder as? NSView,
              responder.isDescendant(of: view), (responder as? NSTextInputClient)?.hasMarkedText() != true,
              let key = message.body as? String, let command = ReaderCommand(rawValue: key) else { return }
        onCommand(command)
    }
}
