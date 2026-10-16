import AppKit
import SwiftUI
import Testing
import ReaderCore
@testable import UnagiReader

// Checks PRD-19: putting text into the note at the caret, for 「記事をノートに送る」 (specification 3.3).
@Suite(.serialized) @MainActor struct NoteInsertionTests {
    final class Sink {
        var changes: [String] = []
        var saves = true
        func save(_ text: String) -> Bool { changes.append(text); return saves }
    }
    /// The store's text, as `NoteEditor` passes it: a saved change comes back to the editor, a failed one does not.
    @Observable final class Store { var text: String; init(_ text: String) { self.text = text } }
    struct Host: View {
        let store: Store; let sink: Sink; let link: NoteEditorLink
        var body: some View {
            NoteTextEditor(text: store.text, onChange: { text in
                guard sink.save(text) else { return false }
                store.text = text; return true
            }, link: link)
        }
    }
    struct Rig { let window: NSWindow; let view: NSTextView; let other: NSTextField; let sink: Sink; let link: NoteEditorLink }

    /// The editor beside another control that can hold the keyboard, as the article or the list does in the app.
    func rig(_ text: String, link: NoteEditorLink = NoteEditorLink(), sink: Sink = Sink()) throws -> Rig {
        let host = NSHostingView(rootView: Host(store: Store(text), sink: sink, link: link))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 360)
        let other = NSTextField(frame: NSRect(x: 0, y: 370, width: 200, height: 24))
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        content.addSubview(host); content.addSubview(other)
        let window = NSWindow(contentRect: content.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = content
        host.layoutSubtreeIfNeeded()
        return Rig(window: window, view: try #require(textView(in: host)), other: other, sink: sink, link: link)
    }
    func textView(in view: NSView) -> NSTextView? {
        if let found = view as? NSTextView { return found }
        return view.subviews.lazy.compactMap { textView(in: $0) }.first
    }
    /// The person puts the caret (or a selection) somewhere in the note, then the keyboard goes back to the article.
    func leaveCaret(_ range: NSRange, in r: Rig) {
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(range)
        r.window.makeFirstResponder(r.other)
    }

    @Test func aNoteNeverUsedTakesTheTextAtItsEnd() throws {
        let r = try rig("メモ"); defer { r.window.close() }
        #expect(r.link.insert("[A](https://example.com/a)") == .inserted)
        #expect(r.view.string == "メモ\n[A](https://example.com/a)\n")
        #expect(r.link.insert("[B](https://example.com/b)") == .inserted)          // the next one goes after it
        #expect(r.view.string == "メモ\n[A](https://example.com/a)\n[B](https://example.com/b)\n")
    }

    @Test func anEmptyNoteGetsTheTextAndALineEnd() throws {
        let r = try rig(""); defer { r.window.close() }
        #expect(r.link.insert("X") == .inserted)
        #expect(r.view.string == "X\n")
    }

    @Test func itGoesAfterTheCaretWhereThePersonLeftIt() throws {
        let r = try rig("一行目\n二行目"); defer { r.window.close() }
        leaveCaret(NSRange(location: 3, length: 0), in: r)                          // the end of the first line
        #expect(r.link.insert("X") == .inserted)
        #expect(r.view.string == "一行目\nX\n二行目")                                  // a line break follows already: no empty line
        #expect(r.view.selectedRange() == NSRange(location: 5, length: 0))            // the caret after the text
    }

    @Test func atTheStartOfALineNoBreakGoesBefore() throws {
        let r = try rig("一行目\n二行目"); defer { r.window.close() }
        leaveCaret(NSRange(location: 4, length: 0), in: r)
        #expect(r.link.insert("X") == .inserted)
        #expect(r.view.string == "一行目\nX\n二行目")
    }

    @Test func aSelectionInTheNoteIsNotReplaced() throws {
        let r = try rig("hello world"); defer { r.window.close() }
        leaveCaret(NSRange(location: 0, length: 5), in: r)
        #expect(r.link.insert("X") == .inserted)
        #expect(r.view.string == "hello\nX\n world")
    }

    @Test func everyKindOfLineBreakCountsAsTheStartOfALine() throws {
        for text in ["a\r", "a\u{2028}", "a\u{2029}"] {
            let r = try rig(text); defer { r.window.close() }
            #expect(r.link.insert("X") == .inserted)
            #expect(r.view.string == text + "X\n")
        }
    }

    @Test func itIsSavedOnceAndOneUndoRemovesIt() throws {
        let r = try rig("メモ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.insertText("です", replacementRange: NSRange(location: 2, length: 0))   // typing just before does not join the undo step
        r.window.makeFirstResponder(r.other)
        pumpRunLoop(0.05)                                                           // the key press is another event, as in the app
        #expect(r.link.insert("X") == .inserted)
        #expect(r.sink.changes == ["メモです", "メモです\nX\n"])
        r.view.undoManager?.undo()
        #expect(r.view.string == "メモです", "after undo: \(r.view.string.debugDescription)")
        #expect(r.sink.changes.last == "メモです")
        r.view.undoManager?.redo()
        #expect(r.view.string == "メモです\nX\n")
    }

    @Test func theKeyboardStaysWhereItWas() throws {
        let r = try rig("メモ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.other)
        let before = r.window.firstResponder
        #expect(r.link.insert("X") == .inserted)
        #expect(r.window.firstResponder === before)
    }

    @Test func whileJapaneseIsComposedNothingIsInserted() throws {
        let r = try rig("メモ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 2, length: 0))
        r.view.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: 2, length: 0))
        #expect(r.link.canInsert == false)
        #expect(r.link.insert("X") == .composing)
        #expect(r.view.string == "メモにほん")
        #expect(r.view.hasMarkedText())
        #expect(r.sink.changes.isEmpty)
        r.view.unmarkText()
        #expect(r.link.canInsert)
    }

    @Test func aFailedSaveIsReportedAndTheTextStaysInTheEditor() throws {
        let r = try rig("メモ"); defer { r.window.close() }
        r.sink.saves = false
        #expect(r.link.insert("X") == .notSaved)
        #expect(r.view.string == "メモ\nX\n")
    }

    @Test func withNoEditorShownNothingIsInsertedAndTheCallerIsTold() {
        let link = NoteEditorLink()
        #expect(link.canInsert == false)
        #expect(link.insert("X") == .noEditor)
    }

    @Test func textWaitingForTheEditorGoesAtTheEndWhenItIsShown() throws {
        let link = NoteEditorLink()
        link.insertWhenShown("X")
        let r = try rig("メモ", link: link); defer { r.window.close() }
        #expect(r.view.string == "メモ")                                              // not in the middle of the view's update
        pumpRunLoop(0.05)
        #expect(r.view.string == "メモ\nX\n", "shown: \(r.view.string.debugDescription)")
        #expect(r.sink.changes == ["メモ\nX\n"])
        #expect(r.link.insert("Y") == .inserted)                                    // once only
        #expect(r.view.string == "メモ\nX\nY\n")
    }

    @Test func anEditorThatIsAlreadyThereTakesWaitingTextAtOnceAtTheEnd() throws {
        let r = try rig("一行目\n二行目"); defer { r.window.close() }
        leaveCaret(NSRange(location: 3, length: 0), in: r)
        r.link.insertWhenShown("X")                                                  // the note was closed: the end, not the caret
        #expect(r.view.string == "一行目\n二行目\nX\n")
    }
}
