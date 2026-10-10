import SwiftUI
import ReaderCore

/// The [記事｜ノート] switch at the top of a theme's center column.
struct ThemeFacePicker: View {
    @Binding var face: ThemeFace
    /// On the note face the sidebar is folded away; this button shows it again and folds it again. Nil on the articles face.
    var onToggleSidebar: (() -> Void)? = nil
    var sidebarFolded = false
    var body: some View {
        HStack(spacing: 8) {
            if let onToggleSidebar {
                Button(action: onToggleSidebar) { Image(systemName: "sidebar.left") }
                    .buttonStyle(.borderless).help(sidebarFolded ? "サイドバーを表示" : "サイドバーを隠す")
                    .accessibilityLabel(sidebarFolded ? "サイドバーを表示" : "サイドバーを隠す")
            }
            Picker("表示", selection: $face) {
                Text("記事").tag(ThemeFace.articles)
                Text("ノート").tag(ThemeFace.note)
            }
            .pickerStyle(.segmented).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
        .accessibilityLabel("テーマの表示")
    }
}

/// The note face: the theme's one note in the middle column, under the face switch and the goal.
struct ThemeNotePane: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @Binding var face: ThemeFace
    let sidebarFolded: Bool
    let onToggleSidebar: () -> Void
    let onEditGoal: () -> Void
    var body: some View {
        NoteEditor(store: store, themeID: themeID)
            .navigationTitle(store.theme(id: themeID)?.name ?? "テーマ")
            .navigationSubtitle("ノート")
            .safeAreaInset(edge: .top) { VStack(spacing: 0) { ThemeFacePicker(face: $face, onToggleSidebar: onToggleSidebar, sidebarFolded: sidebarFolded); ThemeGoalStrip(goal: store.theme(id: themeID)?.goal ?? "", onEdit: onEditGoal) } }
    }
}

/// The theme's goal under the face switch. An empty goal is a quiet invitation to write one.
struct ThemeGoalStrip: View {
    let goal: String
    let onEdit: () -> Void
    var body: some View {
        Button(action: onEdit) {
            Group {
                if goal.isEmpty { Text("ゴールを書く…").foregroundStyle(.tertiary) }
                else { Text(goal).foregroundStyle(.secondary).lineLimit(2) }
            }
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8).background(.bar)
        .accessibilityLabel(goal.isEmpty ? "学習ゴールを書く" : "学習ゴール: \(goal)").accessibilityHint("名前とゴールを編集")
    }
}
