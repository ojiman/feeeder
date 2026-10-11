import SwiftUI
import AppKit

/// A text view that takes only plain text: pasting or dropping rich text from another app inserts its plain text.
final class NoteTextView: NSTextView {
    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }
    override var acceptableDragTypes: [NSPasteboard.PasteboardType] { [.string] }
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
    override func pasteAsRichText(_ sender: Any?) { pasteAsPlainText(sender) }
}

/// The note editor: an AppKit text view (SwiftUI's `TextEditor` has no hook for display attributes of plain text). The saved text is
/// exactly what is typed: no smart quotes, dashes or replacements, no list continuation; headings and list lines only get a look
/// (`NoteEditorStyle`). Styling never touches the text and waits while Japanese text is being composed.
struct NoteTextEditor: NSViewRepresentable {
    let text: String
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NoteTextView()
        textView.isRichText = true                       // needed for attributes; paste and drop stay plain (NoteTextView)
        textView.allowsUndo = true
        textView.usesFontPanel = false; textView.usesRuler = false; textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.font = NoteEditorStyle.baseFont
        textView.typingAttributes = NoteEditorStyle.baseAttributes()
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true; textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel("ノート")
        textView.string = text
        if let storage = textView.textStorage {
            NoteEditorStyle.apply(to: storage, around: NSRange(location: 0, length: storage.length))
            storage.delegate = context.coordinator
        }
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.show(text, in: textView)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate, @MainActor NSTextStorageDelegate {
        var onChange: (String) -> Void
        weak var textView: NSTextView?
        /// A styling pass was skipped while Japanese text was being composed; it is done when the composition ends.
        private(set) var restylePending = false
        /// True while text that arrived from outside is being put in; that is not an edit by the person, so it is not saved back.
        private var applyingOutsideText = false
        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        /// Text that arrives from outside (a summary that was sent, its undo) replaces the text in one undoable edit, keeps the selection
        /// inside the text, and waits while a composition is in progress.
        func show(_ text: String, in textView: NSTextView) {
            guard !textView.hasMarkedText(), textView.string != text else { return }
            let selection = textView.selectedRange()
            let whole = NSRange(location: 0, length: (textView.string as NSString).length)
            guard textView.shouldChangeText(in: whole, replacementString: text) else { return }
            applyingOutsideText = true
            defer { applyingOutsideText = false }
            textView.textStorage?.replaceCharacters(in: whole, with: text)
            textView.didChangeText()
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            restyleIfPending(textView)
            if !applyingOutsideText { onChange(textView.string) }
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            restyleIfPending(textView)
        }

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            if textView?.hasMarkedText() == true { restylePending = true; return }
            NoteEditorStyle.apply(to: textStorage, around: editedRange)
        }

        private func restyleIfPending(_ textView: NSTextView) {
            guard restylePending, !textView.hasMarkedText(), let storage = textView.textStorage else { return }
            restylePending = false
            let selection = textView.selectedRange()
            NoteEditorStyle.apply(to: storage, around: NSRange(location: max(0, selection.location - 1), length: min(2, storage.length)))
        }
    }
}
