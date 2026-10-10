import SwiftUI
import ReaderCore

/// New theme (themeID == nil) or edit name and goal. The text stays when a save fails.
struct ThemeEditorSheet: View {
    @Bindable var store: ReaderStore
    let themeID: UUID?
    let onSaved: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var goal = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(themeID == nil ? "新しいテーマ" : "名前とゴールを編集").font(.title2.bold())
            TextField("テーマの名前", text: $name.singleLine()).focused($nameFocused)
            VStack(alignment: .leading, spacing: 4) {
                Text("学習ゴール（任意）").font(.caption).foregroundStyle(.secondary)
                TextField("このテーマで何を学びたいか", text: $goal.singleLine(), axis: .vertical).lineLimit(2...4)
                    .accessibilityLabel("学習ゴール")
                Text("\(goalLength)/\(Theme.goalLimit)").font(.caption2.monospacedDigit())
                    .foregroundStyle(tooLong ? Color.red : Color.secondary)
                if tooLong { Text("ゴールは\(Theme.goalLimit)文字までです。短くすると保存できます。").font(.caption).foregroundStyle(.red) }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存", action: save).keyboardShortcut(.defaultAction)
                    .disabled(SingleLineText.name(name).isEmpty || tooLong)
            }
        }
        .padding(20).frame(width: 440)
        .onAppear {
            if let themeID, let theme = store.theme(id: themeID) { name = theme.name; goal = theme.goal }
            nameFocused = true
        }
    }

    private var goalLength: Int { Theme.goalLength(goal) }
    /// Nothing is cut while the person types or pastes: over the limit the counter turns red and Save waits.
    private var tooLong: Bool { goalLength > Theme.goalLimit }

    private func save() {
        guard !SingleLineText.name(name).isEmpty, !tooLong else { return }
        do {
            if let themeID { try store.updateTheme(id: themeID, name: name, goal: goal, at: .now); onSaved(themeID) }
            else { onSaved(try store.createTheme(name: name, goal: goal, at: .now).id) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
