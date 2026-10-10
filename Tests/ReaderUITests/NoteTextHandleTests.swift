import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

/// The note's native bridge. Waiting pumps the run loop (a `Task.sleep` can stop the whole test process, see the N4 record).
@Suite(.serialized) @MainActor struct NoteTextHandleTests {
    private func pump(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

    private func hostedTextView(_ text: String) -> (NSWindow, NSTextView, NoteTextHandle) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.isEditable = true; view.allowsUndo = true; view.string = text
        window.contentView = scroll
        let handle = NoteTextHandle(); handle.attach(view)
        window.makeFirstResponder(view)
        return (window, view, handle)
    }

    /// A bare text view whose "save" writes the text back into it, like the binding of the real editor does.
    private func save(into view: NSTextView) -> (String) throws -> Void {
        { [unowned view] text in view.string = text }
    }

    @Test func replaceChangesOnlyTheRangeAndIsOneUndoStep() throws {
        let text = "前の行\r\n😀と👨‍👩‍👧とe\u{301}の本文\r\n後ろの行"
        let (window, view, handle) = hostedTextView(text)
        defer { window.close() }
        let range = (text as NSString).range(of: "😀と👨‍👩‍👧とe\u{301}の本文")
        #expect(try handle.replace(range, with: "書き直し", save: save(into: view)))
        #expect(view.string == "前の行\r\n書き直し\r\n後ろの行")                         // only the range changed
        pump(0.05)                                                                       // the person presses ⌘Z in a later event
        let undo = try #require(view.undoManager)
        #expect(undo.canUndo && undo.undoActionName == "ノートへの採用")
        undo.undo()
        #expect(view.string == text)                                                    // exactly the original, with its CRLF and emoji
        #expect(undo.canRedo && !undo.canUndo)
        undo.redo()
        #expect(view.string == "前の行\r\n書き直し\r\n後ろの行" && undo.canUndo)
        pump(0.05)
        undo.undo()
        #expect(view.string == text)                                                    // and it can go back again
    }

    @Test func aZeroLengthRangeInsertsAndAnOutOfRangeEditChangesNothing() throws {
        let (window, view, handle) = hostedTextView("ab")
        defer { window.close() }
        #expect(try handle.replace(NSRange(location: 1, length: 0), with: "X", save: save(into: view)))
        #expect(view.string == "aXb")
        #expect(try !handle.replace(NSRange(location: 2, length: 5), with: "Y", save: save(into: view)))
        #expect(try !handle.replace(NSRange(location: -1, length: 0), with: "Y", save: save(into: view)))
        #expect(view.string == "aXb")
    }

    @Test func aFailedSaveThrowsAndRegistersNoUndoStep() throws {
        let (window, view, handle) = hostedTextView("固定")
        defer { window.close() }
        struct Refused: Error {}
        let undo = try #require(view.undoManager)
        #expect(throws: Refused.self) { try handle.replace(NSRange(location: 0, length: 1), with: "x", save: { _ in throw Refused() }) }
        #expect(view.string == "固定" && !undo.canUndo)
    }

    @Test func theLocatorFindsTheEditorsTextViewAndAnEditReachesTheStoreAndUndoReturns() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let theme = try store.createTheme(name: "T", at: .now)
        try store.saveNote(themeID: theme.id, text: "# 見出し\n元の文章です。", at: .now)
        let handle = NoteTextHandle()
        let selection = SelectionBox()
        let host = NSHostingView(rootView: EditorHost(store: store, themeID: theme.id, handle: handle, box: selection))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        for _ in 0..<100 { host.layoutSubtreeIfNeeded(); if handle.isMounted { break }; pump(0.02) }
        #expect(handle.isMounted && handle.string == "# 見出し\n元の文章です。")
        let range = ("# 見出し\n元の文章です。" as NSString).range(of: "元の文章です。")
        window.makeKeyAndOrderFront(nil)
        let saver: (String) throws -> Void = { try store.saveNote(themeID: theme.id, text: $0, at: .now) }
        #expect(try handle.replace(range, with: "読みやすい文章です。", save: saver))
        for _ in 0..<100 { if theme.note == "# 見出し\n読みやすい文章です。" && handle.string == theme.note { break }; pump(0.02) }
        #expect(theme.note == "# 見出し\n読みやすい文章です。")                              // saved through the editor's own path
        #expect(handle.string == "# 見出し\n読みやすい文章です。")                            // and the text view shows it
        let undo = try #require(handle.textView?.undoManager)
        undo.undo()
        for _ in 0..<100 { if theme.note == "# 見出し\n元の文章です。" && handle.string == theme.note { break }; pump(0.02) }
        #expect(theme.note == "# 見出し\n元の文章です。" && handle.string == "# 見出し\n元の文章です。")   // undo reached the store and the view
        undo.redo()
        for _ in 0..<100 { if theme.note == "# 見出し\n読みやすい文章です。" && handle.string == theme.note { break }; pump(0.02) }
        #expect(theme.note == "# 見出し\n読みやすい文章です。" && handle.string == theme.note)
    }
}

@MainActor private final class SelectionBox { var value: TextSelection? }

private struct EditorHost: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    let handle: NoteTextHandle
    let box: SelectionBox
    @State private var selection: TextSelection?
    var body: some View { NoteEditor(store: store, themeID: themeID, selection: $selection) }
}
