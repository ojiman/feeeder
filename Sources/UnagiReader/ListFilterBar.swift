import SwiftUI
import AppKit

/// The list filter (specification 3.1.4): a magnifier at the right of the list title; pressing it, or `/`, puts the system's search
/// field in place of the title line. It sits below the toolbar band, on the title line of `ListHeader`, so it takes clicks like any
/// control in the column.
struct ListFilterBar: View {
    @Binding var text: String
    let shown: Bool
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if shown {
                ListFilterField(text: $text, close: close)
                    .frame(height: 22)
            } else {
                Spacer(minLength: 0)
                Button(action: open) { Image(systemName: "magnifyingglass") }
                    .buttonStyle(.borderless)
                    .help("記事を絞り込む (/)").accessibilityLabel("記事を絞り込む")
            }
        }
        .padding(.horizontal, ListHeader.sideMargin - 4)
        .frame(height: ListHeader.titleLine)
        .padding(.top, ListHeader.bandHeight + ListHeader.crossCentre - ListHeader.titleLine / 2)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// The system's search field. The list follows its text, but not while Japanese text is being composed in it: the text is handed on
/// only when the field's editor has no marked text, and again when the composition is committed. `Esc` in an empty field closes it.
struct ListFilterField: NSViewRepresentable {
    @Binding var text: String
    let close: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "絞り込み"
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
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
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)), !textView.hasMarkedText(), textView.string.isEmpty else { return false }
            parent.close()
            return true
        }
    }
}
