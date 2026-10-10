import SwiftUI
import ReaderCore

/// The theme's one note. Plain text; a line that starts with `#` is a heading. Saved as it is typed, exactly as typed.
/// Nothing but the person writes here (decision 0019: a summary the person sends is the only text that arrives from elsewhere).
struct NoteEditor: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @State private var error: String?
    var body: some View {
        if let theme = store.theme(id: themeID) {
            TextEditor(text: Binding(get: { theme.note }, set: { text in
                do { try store.saveNote(themeID: themeID, text: text, at: .now) } catch { self.error = error.localizedDescription }
            }))
            .font(.body).accessibilityLabel("ノート")
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .overlay(alignment: .topLeading) {
                if theme.note.isEmpty {
                    Text("このテーマについて、自分の言葉で書きます。「#」で始まる行は見出しです。")
                        .font(.body).foregroundStyle(.tertiary).padding(.horizontal, 21).padding(.vertical, 12).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
            .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("閉じる") { error = nil }
            } message: { Text(error ?? "") }
        } else {
            ContentUnavailableView("テーマが見つかりません", systemImage: "questionmark.folder")
        }
    }
}
