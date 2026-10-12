import AppKit
import SwiftUI
import Testing
import ReaderCore
@testable import UnagiReader

@Suite(.serialized) @MainActor struct NoteTextEditorTests {
    final class Sink {
        var changes: [String] = []
        var saves = true
        func save(_ text: String) -> Bool { changes.append(text); return saves }
    }
    struct Rig { let host: NSHostingView<NoteTextEditor>; let window: NSWindow; let view: NSTextView; let sink: Sink }

    func rig(_ text: String, sink: Sink = Sink()) throws -> Rig {
        let host = NSHostingView(rootView: NoteTextEditor(text: text, onChange: sink.save))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        host.layoutSubtreeIfNeeded()
        return Rig(host: host, window: window, view: try #require(textView(in: host)), sink: sink)
    }
    func textView(in view: NSView) -> NSTextView? {
        if let found = view as? NSTextView { return found }
        return view.subviews.lazy.compactMap { textView(in: $0) }.first
    }
    func font(_ view: NSTextView, at index: Int) -> NSFont? { view.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont }
    func color(_ view: NSTextView, at index: Int) -> NSColor? { view.textStorage?.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor }

    @Test func showsTheTextExactlyAsGiven() throws {
        let text = "# 見出し\r\n- 項目 👨‍👩‍👧\r\n\n1) 二番目\u{2028}本文\u{0085}終わり"
        let r = try rig(text); defer { r.window.close() }
        #expect(r.view.string == text)
        #expect(r.sink.changes.isEmpty)
    }
    @Test func aLargeNoteKeepsItsTextAndStaysQuick() throws {
        let text = (0..<30_000).map { $0 % 3 == 0 ? "## 見出し \($0)" : $0 % 3 == 1 ? "- 項目 \($0)" : "本文 \($0)" }.joined(separator: "\n")
        let start = Date()
        let r = try rig(text); defer { r.window.close() }
        #expect(r.view.string == text)
        #expect(Date().timeIntervalSince(start) < 1)
    }
    @Test func headingsAndListsGetALookAndTheTextStaysTheSame() throws {
        let text = "# 大見出し\n本文\n- 項目\n   - 子\n1. 番号\n#ハッシュ"
        let r = try rig(text); defer { r.window.close() }
        let body = NoteEditorStyle.baseFont.pointSize
        #expect(try #require(font(r.view, at: 2)).pointSize > body)                       // heading text
        #expect(color(r.view, at: 0) == NoteEditorStyle.marksColor)                       // the "#"
        #expect(try #require(font(r.view, at: 7)).pointSize == body)                      // body line
        let bullet = (text as NSString).range(of: "- 項目").location
        #expect(color(r.view, at: bullet) == NoteEditorStyle.markerColor)
        let style = r.view.textStorage?.attribute(.paragraphStyle, at: bullet, effectiveRange: nil) as? NSParagraphStyle
        #expect((style?.headIndent ?? 0) > 0)
        let hashtag = (text as NSString).range(of: "#ハッシュ").location
        #expect(try #require(font(r.view, at: hashtag)).pointSize == body)               // "#" without a space is not a heading
        #expect(r.view.string == text)
    }
    @Test func typingStylesTheLineAndSavesOncePerChange() throws {
        let r = try rig(""); defer { r.window.close() }
        r.view.insertText("# ", replacementRange: NSRange(location: 0, length: 0))
        r.view.insertText("題", replacementRange: NSRange(location: 2, length: 0))
        #expect(r.view.string == "# 題")
        #expect(r.sink.changes == ["# ", "# 題"])
        #expect(try #require(font(r.view, at: 2)).pointSize > NoteEditorStyle.baseFont.pointSize)
        r.view.insertText("\n本文", replacementRange: NSRange(location: 3, length: 0))
        #expect(try #require(font(r.view, at: 5)).pointSize == NoteEditorStyle.baseFont.pointSize)
        #expect(r.sink.changes.last == "# 題\n本文")
    }
    @Test func leavingAHeadingBackToBodyRemovesItsLook() throws {
        let r = try rig("# 見出し"); defer { r.window.close() }
        r.view.insertText("", replacementRange: NSRange(location: 0, length: 1))              // delete "#"
        #expect(r.view.string == " 見出し")
        #expect(try #require(font(r.view, at: 2)).pointSize == NoteEditorStyle.baseFont.pointSize)
        #expect(color(r.view, at: 0) == NSColor.labelColor)
    }
    @Test func composingJapaneseIsNeverTouchedAndStylesWhenCommitted() throws {
        let r = try rig("# "); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 2, length: 0))
        r.view.setMarkedText("にほん", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: 2, length: 0))
        #expect(r.view.hasMarkedText())
        let coordinator = try #require(r.view.delegate as? NoteTextEditor.Coordinator)
        #expect(coordinator.restylePending)                                                    // the pass waits: nothing is restyled mid-composition
        r.view.insertText("日本", replacementRange: r.view.markedRange())
        #expect(!r.view.hasMarkedText())
        #expect(!coordinator.restylePending)
        #expect(r.view.string == "# 日本")
        #expect(try #require(font(r.view, at: 2)).pointSize > NoteEditorStyle.baseFont.pointSize)
        #expect(r.sink.changes.last == "# 日本")
    }
    @Test func cancellingACompositionRestylesToo() throws {
        let r = try rig("# "); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 2, length: 0))
        r.view.setMarkedText("あ", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 2, length: 0))
        r.view.unmarkText()
        #expect(r.view.string == "# あ")
        #expect(try #require(font(r.view, at: 2)).pointSize > NoteEditorStyle.baseFont.pointSize)
    }
    @Test func undoAndRedoRestoreTheTextAndTheLook() throws {
        let r = try rig("本文"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.insertText("# ", replacementRange: NSRange(location: 0, length: 0))
        #expect(try #require(font(r.view, at: 3)).pointSize > NoteEditorStyle.baseFont.pointSize)
        r.view.undoManager?.undo()
        #expect(r.view.string == "本文")
        #expect(try #require(font(r.view, at: 1)).pointSize == NoteEditorStyle.baseFont.pointSize)
        r.view.undoManager?.redo()
        #expect(r.view.string == "# 本文")
        #expect(try #require(font(r.view, at: 3)).pointSize > NoteEditorStyle.baseFont.pointSize)
    }
    @Test func textFromOutsideReplacesTheTextKeepsTheSelectionAndSavesNothing() throws {
        let r = try rig("あいう")
        defer { r.window.close() }
        r.view.setSelectedRange(NSRange(location: 2, length: 0))
        r.host.rootView = NoteTextEditor(text: "あいう\n\n要約", onChange: r.sink.save)
        r.host.layoutSubtreeIfNeeded()
        #expect(r.view.string == "あいう\n\n要約")
        #expect(r.view.selectedRange() == NSRange(location: 2, length: 0))
        r.host.rootView = NoteTextEditor(text: "あ", onChange: r.sink.save)
        r.host.layoutSubtreeIfNeeded()
        #expect(r.view.string == "あ")
        #expect(r.view.selectedRange().location <= 1)
        #expect(r.sink.changes.isEmpty)                                                     // not typed by the person: nothing to save
    }
    @Test func textFromOutsideWaitsWhileComposing() throws {
        let r = try rig("あ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 1, length: 0))
        r.view.setMarkedText("い", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 0))
        r.host.rootView = NoteTextEditor(text: "別の文章", onChange: r.sink.save)
        r.host.layoutSubtreeIfNeeded()
        #expect(r.view.hasMarkedText())
        #expect(r.view.string == "あい")
        r.view.unmarkText()
    }
    @Test func theSameTextFromOutsideDoesNotDisturbTheView() throws {
        let r = try rig("# 題\n- a"); defer { r.window.close() }
        r.view.setSelectedRange(NSRange(location: 3, length: 2))
        r.host.rootView = NoteTextEditor(text: "# 題\n- a", onChange: r.sink.save)
        r.host.layoutSubtreeIfNeeded()
        #expect(r.view.selectedRange() == NSRange(location: 3, length: 2))
        #expect(r.view.undoManager?.canUndo != true)
    }
    @Test func richTextPasteBecomesPlainText() throws {
        let r = try rig(""); defer { r.window.close() }
        let board = NSPasteboard(name: .init("unagi-reader-test-\(UUID())"))
        let rich = NSAttributedString(string: "太字", attributes: [.font: NSFont.boldSystemFont(ofSize: 30)])
        board.clearContents()
        board.writeObjects([rich])
        #expect(r.view.readablePasteboardTypes == [.string])
        #expect(r.view.acceptableDragTypes == [.string])
        _ = r.view.readSelection(from: board, type: .string)
        #expect(r.view.string == "太字")
        #expect(abs((font(r.view, at: 0)?.pointSize ?? 0) - NoteEditorStyle.baseFont.pointSize) < 0.01)
    }
    @Test func theViewDoesNotRewriteWhatIsTyped() throws {
        let r = try rig(""); defer { r.window.close() }
        #expect(!r.view.isAutomaticQuoteSubstitutionEnabled)
        #expect(!r.view.isAutomaticDashSubstitutionEnabled)
        #expect(!r.view.isAutomaticTextReplacementEnabled)
        #expect(!r.view.isAutomaticLinkDetectionEnabled)
        r.view.insertText("\"a\" -- b", replacementRange: NSRange(location: 0, length: 0))
        #expect(r.view.string == "\"a\" -- b")
        r.view.insertText("\n", replacementRange: NSRange(location: 8, length: 0))
        r.view.insertText("- x", replacementRange: NSRange(location: 9, length: 0))
        r.view.insertText("\n", replacementRange: NSRange(location: 12, length: 0))
        #expect(r.view.string == "\"a\" -- b\n- x\n")                                           // no list continuation
    }
    @Test func theViewIsLabelledAndDoesNotTakeFocusByItself() throws {
        let r = try rig("本文"); defer { r.window.close() }
        #expect(r.view.accessibilityLabel() == "ノート")
        #expect(r.window.firstResponder !== r.view)
    }

    // MARK: Review fixes

    func show(_ text: String, in r: Rig) {
        r.host.rootView = NoteTextEditor(text: text, onChange: r.sink.save)
        r.host.layoutSubtreeIfNeeded()
    }

    @Test func undoAndRedoAreSavedOnceEach() throws {
        let r = try rig("あ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 1, length: 0))
        r.view.insertText("い", replacementRange: NSRange(location: 1, length: 0))
        #expect(r.sink.changes == ["あい"])
        r.view.undoManager?.undo()
        #expect(r.view.string == "あ")
        #expect(r.sink.changes == ["あい", "あ"])
        r.view.undoManager?.redo()
        #expect(r.view.string == "あい")
        #expect(r.sink.changes == ["あい", "あ", "あい"])
    }
    @Test func eachEditorHasItsOwnUndoHistory() throws {
        let a = try rig("A"); defer { a.window.close() }
        a.view.insertText("1", replacementRange: NSRange(location: 1, length: 0))
        let b = try rig("B"); defer { b.window.close() }
        #expect(a.view.undoManager?.canUndo == true)
        #expect(b.view.undoManager?.canUndo != true)
        #expect(a.view.undoManager !== a.window.undoManager)
    }
    @Test func aSummaryThatArrivesWhileComposingIsKeptAndSavedAfterTheCommit() throws {
        let r = try rig("あ"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 1, length: 0))
        r.view.setMarkedText("い", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 0))
        show("あ\n\n要約ブロック", in: r)
        #expect(r.view.hasMarkedText())
        r.view.insertText("伊", replacementRange: r.view.markedRange())
        #expect(r.view.string == "あ伊\n\n要約ブロック")
        #expect(r.sink.changes.last == "あ伊\n\n要約ブロック")
    }
    @Test func aSendUndoneWhileComposingRemovesItsBlockAfterTheCommit() throws {
        let r = try rig("あ\n\n要約ブロック"); defer { r.window.close() }
        r.window.makeFirstResponder(r.view)
        r.view.setSelectedRange(NSRange(location: 1, length: 0))
        r.view.setMarkedText("い", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: 1, length: 0))
        show("あ", in: r)
        r.view.insertText("伊", replacementRange: r.view.markedRange())
        #expect(r.view.string == "あ伊")
        #expect(r.sink.changes.last == "あ伊")
    }
    @Test func aFailedSaveKeepsTheTypedTextInTheView() throws {
        let r = try rig("本文"); defer { r.window.close() }
        r.sink.saves = false
        r.view.insertText("です", replacementRange: NSRange(location: 2, length: 0))
        show("本文", in: r)                                                                  // the store rolled back: its text is the old one
        #expect(r.view.string == "本文です")
        r.sink.saves = true
        r.view.insertText("。", replacementRange: NSRange(location: 4, length: 0))
        #expect(r.sink.changes.last == "本文です。")
        show("本文です。", in: r)
        show("本文です。\n\n要約", in: r)                                                     // saving works again: outside text is shown again
        #expect(r.view.string == "本文です。\n\n要約")
    }
    @Test func deletingTheLastCharacterOfAListLineRestylesTheLastLine() throws {
        let r = try rig("本文\n- "); defer { r.window.close() }
        r.view.insertText("", replacementRange: NSRange(location: 4, length: 1))
        #expect(r.view.string == "本文\n-")
        #expect(color(r.view, at: 3) == NSColor.labelColor)
    }
    @Test func smartPasteIsOffAndCopyHandsOutPlainTextOnly() throws {
        let r = try rig("# 見出し"); defer { r.window.close() }
        #expect(!r.view.smartInsertDeleteEnabled)
        #expect(r.view.writablePasteboardTypes == [.string])
    }
    @Test func anAppendFromOutsideKeepsTheSelectionRangeAndLeavesTheTextBeforeIt() throws {
        let r = try rig("あいうえお"); defer { r.window.close() }
        r.view.setSelectedRange(NSRange(location: 1, length: 2))
        show("あいうえお\n\n要約", in: r)
        #expect(r.view.selectedRange() == NSRange(location: 1, length: 2))
        show("あいう", in: r)                                                                // the end is cut: the selection stays where it is
        #expect(r.view.selectedRange() == NSRange(location: 1, length: 2))
        #expect(r.view.string == "あいう")
    }

    @Test func theNotePanelEditorIsTheStyledViewAndTypingSavesTheStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let host = NSHostingView(rootView: NoteEditor(store: store))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        let view = try #require(textView(in: host))
        #expect(view is NoteTextView)
        view.insertText("# 見出し", replacementRange: NSRange(location: 0, length: 0))
        view.insertText("\n- 項目", replacementRange: NSRange(location: 5, length: 0))
        pumpRunLoop(0.1)
        #expect(store.note?.text == "# 見出し\n- 項目")
        #expect(view.string == "# 見出し\n- 項目")
        #expect(try #require(font(view, at: 3)).pointSize > NoteEditorStyle.baseFont.pointSize)
    }
}
