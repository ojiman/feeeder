import SwiftUI
import AppKit

/// The list filter in the list's band (specification 3.1.4, decision 0057): only a magnifier at the right; clicking it, or `/`, puts the
/// system's search field across the band. The field stays while it has text; left empty, it turns back into the magnifier.
struct ListFilterBar: View {
    @Binding var text: String
    let shown: Bool
    /// The list starts at the window's left edge (the sidebar is folded), under the window buttons.
    var atLeftEdge = false
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if shown {
                ListFilterField(text: $text, close: close).frame(height: 22)
            } else {
                Spacer(minLength: 0)
                BandButton(id: "filter", symbol: "magnifyingglass", help: "記事を絞り込む (/)", label: "記事を絞り込む", action: open)
            }
        }
        .padding(.horizontal, 12)
        .padding(.leading, atLeftEdge ? ArticleBand.windowButtonsWidth : 0)
        .frame(height: ArticleBand.controlLine)
        .padding(.top, ArticleBand.controlTop)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// The system's search field. The list follows its text, but not while Japanese text is being composed in it: the text is handed on
/// only when the field's editor has no marked text, and again when the composition is committed. `Esc` in an empty field, or leaving it
/// empty, closes it.
struct ListFilterField: NSViewRepresentable {
    @Binding var text: String
    let close: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "絞り込み"
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        // The ✕ clears the field through its action, with no text-change notice.
        field.target = context.coordinator; field.action = #selector(Coordinator.searched(_:))
        field.stringValue = text
        field.setAccessibilityLabel("記事を絞り込む")
        // Take the keyboard when the field appears (`/` or the magnifier).
        DispatchQueue.main.async { [weak field] in field?.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        let composing = (field.currentEditor() as? NSTextView)?.hasMarkedText() == true
        if !composing, field.stringValue != text { field.stringValue = text }
    }

    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: ListFilterField
        init(_ parent: ListFilterField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            Self.hand(field.stringValue, from: field, to: &parent.text)
        }
        /// The text is handed to the list only when nothing is being composed.
        static func hand(_ value: String, from field: NSSearchField, to text: inout String) {
            guard (field.currentEditor() as? NSTextView)?.hasMarkedText() != true, text != value else { return }
            text = value
        }
        @objc func searched(_ field: NSSearchField) { Self.hand(field.stringValue, from: field, to: &parent.text) }
        /// The keyboard went elsewhere: an empty field turns back into the magnifier.
        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField, field.stringValue.isEmpty else { return }
            parent.close()
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)), !textView.hasMarkedText(), textView.string.isEmpty else { return false }
            parent.close()
            return true
        }
    }
}
