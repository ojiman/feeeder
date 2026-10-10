import AppKit
import WebKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct OriginalKeyboardTests {
    @Test func failedOriginalKeepsEscapeAndNavigation() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let first = UUID(), next = UUID()
        var original = OriginalPageState()
        let opened = original.open(articleID: first, url: "http://127.0.0.1:1/failing")
        #expect(opened)
        var reader = ReaderSelectionState(); reader.select(first)
        reader.recordScroll(articleID: first, anchor: "paragraph-7", offset: 23.5)
        let errorPane = OriginalFailureHostingView(rootView: Text("合成ネットワーク失敗"))
        var commands: [ReaderCommand] = []
        errorPane.onCommand = { command in
            commands.append(command)
            switch command {
            case .next: reader.select(next); original.selectionChanged(to: next)
            case .previous: reader.select(first); original.selectionChanged(to: first)
            case .closeOriginal: original.close(); reader.returnFromOriginal()
            default: break
            }
        }
        window.contentView = errorPane
        #expect(window.firstResponder === errorPane)
        errorPane.keyDown(with: try event("j")); #expect(original.url == nil && reader.selectedArticleID == next)
        errorPane.keyDown(with: try event("k")); #expect(original.url == nil && reader.selectedArticleID == first)
        errorPane.keyDown(with: try event("s")); errorPane.keyDown(with: try event("t"))
        errorPane.keyDown(with: try event("j", modifiers: .command))
        errorPane.keyDown(with: try event("Escape"))
        #expect(commands == [.next, .previous, .toggleStar, .notePicker, .closeOriginal])
        #expect(original.url == nil && reader.selectedArticleID == first)
        #expect(reader.scrollAnchors[first] == "paragraph-7" && reader.scrollOffsets[first] == 23.5)
    }
    @Test func mountingOriginalPageTransfersKeyboardFocus() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSView(frame: window.contentView!.bounds)
        window.contentView = host
        let reader = NSTextView(frame: host.bounds)
        host.addSubview(reader); window.makeFirstResponder(reader)
        let original = OriginalReaderWebView(frame: host.bounds, configuration: WKWebViewConfiguration())
        host.addSubview(original)
        #expect(window.firstResponder === original)
    }
    func event(_ key: String, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key,
            isARepeat: false, keyCode: key == "Escape" ? 53 : 0))
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

@MainActor struct ShortcutResponderTests {
    @Test func onlyAnEditableTextViewOrAFieldCountsAsTextInput() {
        let note = NSTextView(); note.isEditable = true
        let reader = NSTextView(); reader.isEditable = false; reader.isSelectable = true
        #expect(ReaderKeyboardCommands.isTextInput(note))
        #expect(!ReaderKeyboardCommands.isTextInput(reader))
        #expect(ReaderKeyboardCommands.isTextInput(NSTextField()))
        #expect(!ReaderKeyboardCommands.isTextInput(NSTableView()))
        #expect(!ReaderKeyboardCommands.isTextInput(nil))
    }
    @Test func markedTextInTheNoteBlocksEveryShortcut() {
        let note = NSTextView(); note.isEditable = true
        #expect(!ReaderKeyboardCommands.hasMarkedText(note))
        note.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(ReaderKeyboardCommands.hasMarkedText(note))
        #expect(!ReaderShortcutPolicy.permits(textInput: ReaderKeyboardCommands.isTextInput(note), markedText: ReaderKeyboardCommands.hasMarkedText(note), sheet: false, originalPage: false))
    }
    @Test func theReadOnlyReaderDoesNotBlockShortcuts() {
        let reader = NSTextView(); reader.isEditable = false
        #expect(ReaderShortcutPolicy.permits(textInput: ReaderKeyboardCommands.isTextInput(reader), markedText: ReaderKeyboardCommands.hasMarkedText(reader), sheet: false, originalPage: false))
    }
}
