import SwiftUI
import ReaderCore

/// The note editor. Plain Markdown text; a line that starts with `#` is a heading and a line that starts with `-` or `1.` is a list item
/// (only their look changes, see `NoteTextEditor`). Saved as it is typed, exactly as typed.
/// Nothing but the person writes here: by typing, pasting or 「記事をノートに送る」 (decisions 0049, 0059).
struct NoteEditor: View {
    @Bindable var store: ReaderStore
    /// How 「記事をノートに送る」 reaches the editor (specification 3.3).
    var link: NoteEditorLink? = nil
    @State private var error: String?
    var body: some View {
        if let note = store.note {
            NoteTextEditor(text: note.text, onChange: { text in
                do { try store.saveNote(text: text, at: .now); return true } catch { self.error = error.localizedDescription; return false }
            }, link: link)
            .overlay(alignment: .topLeading) {
                if note.text.isEmpty {
                    Text(String(localized: "Write in your own words. Start a line with # for a heading.", bundle: ReaderLocalization.bundle))
                        .font(.body).foregroundStyle(.tertiary).padding(.horizontal, 21).padding(.vertical, 12).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppPalette.surfaceColor)
            .alert(String(localized: "Could Not Save", bundle: ReaderLocalization.bundle), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(String(localized: "Close", bundle: ReaderLocalization.bundle)) { error = nil }
            } message: { Text(error ?? "") }
        } else {
            ContentUnavailableView(String(localized: "Note Not Found", bundle: ReaderLocalization.bundle), systemImage: "questionmark.folder")
        }
    }
}
