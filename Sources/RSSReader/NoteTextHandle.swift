import SwiftUI
import AppKit

/// A way to edit the note through its own text view, so that an edit is a real text-system edit: one undo step (⌘Z), and the
/// editor's save-as-you-type path stores the result. The text view is looked up when it is needed: it is the editable text view
/// that is not a field editor (the note editor is the only multi-line editor in the app), in the key window first.
@MainActor final class NoteTextHandle {
    private var attached: NSTextView?
    /// The note the editor should be showing. Used to pick the right text view when more than one window has an editor.
    var expectedText: () -> String? = { nil }
    /// For tests that host a bare text view; the app never sets it.
    func attach(_ view: NSTextView?) { attached = view }

    var textView: NSTextView? {
        if let attached { return attached }
        let windows = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 } + NSApp.windows
        let candidates = windows.flatMap { Self.all(in: $0.contentView) }
        if let expected = expectedText(), let match = candidates.first(where: { String($0.string) == expected }) { return match }
        return candidates.first
    }
    var isMounted: Bool { textView != nil }
    var selectedRange: NSRange? { textView?.selectedRange() }
    var string: String? { textView?.string }

    /// Replaces `range` of the text the note editor shows with `text`, by handing the whole new text to `save` (the same path as
    /// typing), and registers one undo step with the editor's undo manager that puts the old text back through `save` (and a redo
    /// that applies the new text again). Returns false, and changes nothing, when no text view is mounted or the range is not inside
    /// the text. Throws what `save` throws; nothing is registered then. The text view follows the saved text through its binding.
    @discardableResult func replace(_ range: NSRange, with text: String, actionName: String = "ノートへの採用", save: @escaping (String) throws -> Void) throws -> Bool {
        guard let view = textView else { return false }
        let old = String(view.string)                      // a copy: the text view's own string is mutable storage
        let oldNS = old as NSString
        guard range.location >= 0, NSMaxRange(range) <= oldNS.length else { return false }
        let new = oldNS.replacingCharacters(in: range, with: text)
        try save(new)
        if let undo = view.undoManager { Self.register(old: old, new: new, save: save, undo: undo, actionName: actionName) }
        return true
    }

    private static func register(old: String, new: String, save: @escaping (String) throws -> Void, undo: UndoManager, actionName: String) {
        undo.registerUndo(withTarget: undo) { manager in
            try? save(old)
            register(old: new, new: old, save: save, undo: manager, actionName: actionName)   // registered during an undo, it is the redo
        }
        undo.setActionName(actionName)
    }

    /// Every editable text view that is not a field editor, in the order of the view tree.
    private static func all(in view: NSView?) -> [NSTextView] {
        guard let view else { return [] }
        let here: [NSTextView] = (view as? NSTextView).map { $0.isEditable && !$0.isFieldEditor ? [$0] : [] } ?? []
        return here + view.subviews.flatMap { all(in: $0) }
    }
}
