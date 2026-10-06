import AppKit
import WebKit
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct OriginalKeyboardTests {
    func event(_ key: String, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key,
            isARepeat: false, keyCode: 0))
    }
    @Test func nativeCommandsIgnoreModifiedInput() throws {
        #expect(ReaderKeyboardCommands.command(for: try event("j")) == .next)
        #expect(ReaderKeyboardCommands.command(for: try event("s")) == .toggleStar)
        for modifiers: NSEvent.ModifierFlags in [.command, .control, .option, .shift] {
            #expect(ReaderKeyboardCommands.command(for: try event("j", modifiers: modifiers)) == nil)
        }
    }
    @Test func hiddenDisplayCannotMarkRead() {
        let a = UUID(), b = UUID()
        #expect(!ReaderKeyboardCommands.acceptsDisplay(articleID: a, selectedID: b, contentID: a, originalVisible: false))
        #expect(!ReaderKeyboardCommands.acceptsDisplay(articleID: a, selectedID: a, contentID: a, originalVisible: true))
        #expect(!ReaderKeyboardCommands.acceptsDisplay(articleID: a, selectedID: a, contentID: b, originalVisible: false))
        #expect(ReaderKeyboardCommands.acceptsDisplay(articleID: a, selectedID: a, contentID: a, originalVisible: false))
    }
    @Test func pageCannotSendCommands() async throws {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 320, height: 240), configuration: configuration)
        var commands: [ReaderCommand] = []
        let bridge = OriginalKeyboardBridge { commands.append($0) }
        bridge.install(in: view)
        defer { bridge.uninstall() }
        view.loadHTMLString("<html><body><input id='input'><textarea></textarea><select></select><div contenteditable='true'>edit</div></body></html>", baseURL: nil)
        for _ in 0..<100 {
            if !view.isLoading { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let result = try await script("typeof window.webkit?.messageHandlers?.feeederReaderKey", in: view)
        #expect(result == "undefined")
        _ = try await script("document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'s',bubbles:true}));'done'", in: view)
        try await Task.sleep(for: .milliseconds(30))
        #expect(commands.isEmpty)
    }
    @Test func editableFieldsKeepTyping() async throws {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 320), configuration: configuration)
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view
        let receiver = CommandReceiver()
        let bridge = OriginalKeyboardBridge { _ in }
        bridge.install(in: view)
        // CLI tests cannot become the application's key window. Exercise the
        // production isolated-world script with a receiver that records its output.
        let controller = view.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "feeederReaderKey", contentWorld: OriginalKeyboardBridge.world)
        controller.add(receiver, contentWorld: OriginalKeyboardBridge.world, name: "feeederReaderKey")
        defer { bridge.uninstall(); window.close() }
        view.loadHTMLString("""
        <html><body tabindex='0'><input id='input'><textarea id='text'></textarea>
        <select id='select'><option>one</option></select><div id='edit' contenteditable='true'>edit</div>
        <iframe id='frame' srcdoc="<input id='child'>"></iframe></body></html>
        """, baseURL: nil)
        for _ in 0..<100 {
            let state = try await script("document.getElementById('input') && document.getElementById('frame')?.contentDocument?.getElementById('child') ? 'ready' : 'waiting'", in: view)
            if state == "ready" { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view)
        func send(_ key: String) throws {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: key == "j" ? 38 : key == "k" ? 40 : 1))
            view.keyDown(with: event)
        }
        for id in ["input", "text", "select", "edit"] {
            _ = try await script("document.getElementById('\(id)').focus();'done'", in: view)
            try send("j"); try await Task.sleep(for: .milliseconds(60))
            #expect(receiver.commands.isEmpty)
        }
        #expect(try await script("document.getElementById('input').value", in: view) == "j")
        _ = try await script("document.getElementById('frame').contentDocument.getElementById('child').focus();'done'", in: view)
        try send("s"); try await Task.sleep(for: .milliseconds(60))
        #expect(receiver.commands.isEmpty)
        _ = try await script("document.body.focus();'done'", in: view)
        for key in ["j", "k", "s"] { try send(key); try await Task.sleep(for: .milliseconds(60)) }
        #expect(receiver.commands == [.next, .previous, .toggleStar])
    }
    func script(_ code: String, in view: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(code) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value as? String ?? "") }
            }
        }
    }
}

@MainActor private final class CommandReceiver: NSObject, WKScriptMessageHandler {
    var commands: [ReaderCommand] = []
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let key = message.body as? String, let command = ReaderCommand(rawValue: key) { commands.append(command) }
    }
}
