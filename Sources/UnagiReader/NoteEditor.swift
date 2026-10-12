import SwiftUI
import ReaderCore

/// The note editor. Plain Markdown text; a line that starts with `#` is a heading and a line that starts with `-` or `1.` is a list item
/// (only their look changes, see `NoteTextEditor`). Saved as it is typed, exactly as typed.
/// Nothing but the person writes here (decision 0049).
struct NoteEditor: View {
    @Bindable var store: ReaderStore
    @State private var error: String?
    var body: some View {
        if let note = store.note {
            NoteTextEditor(text: note.text) { text in
                do { try store.saveNote(text: text, at: .now); return true } catch { self.error = error.localizedDescription; return false }
            }
            .overlay(alignment: .topLeading) {
                if note.text.isEmpty {
                    Text("自分の言葉で書きます。「#」で始まる行は見出しです。")
                        .font(.body).foregroundStyle(.tertiary).padding(.horizontal, 21).padding(.vertical, 12).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppPalette.surfaceColor)
            .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("閉じる") { error = nil }
            } message: { Text(error ?? "") }
        } else {
            ContentUnavailableView("ノートが見つかりません", systemImage: "questionmark.folder")
        }
    }
}
