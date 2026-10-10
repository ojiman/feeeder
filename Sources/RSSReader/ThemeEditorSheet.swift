import SwiftUI
import ReaderCore

/// New theme (themeID == nil) or edit its name. The text stays when a save fails.
struct ThemeEditorSheet: View {
    @Bindable var store: ReaderStore
    let themeID: UUID?
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(themeID == nil ? "新しいテーマ" : "名前を編集").font(.title2.bold())
            TextField("テーマの名前", text: $name.singleLine()).focused($nameFocused)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存", action: save).keyboardShortcut(.defaultAction)
                    .disabled(SingleLineText.name(name).isEmpty)
            }
        }
        .padding(20).frame(width: 440)
        .onAppear {
            if let themeID, let theme = store.theme(id: themeID) { name = theme.name }
            nameFocused = true
        }
    }

    private func save() {
        guard !SingleLineText.name(name).isEmpty else { return }
        do {
            if let themeID { try store.renameTheme(id: themeID, to: name, at: .now); onSaved(themeID) }
            else { onSaved(try store.createTheme(name: name, at: .now).id) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
