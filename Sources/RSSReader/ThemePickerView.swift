import SwiftUI
import ReaderCore

/// Opened by `t` and by the toolbar icon. Checking a theme adds the article; unchecking removes it.
struct ThemePickerView: View {
    @Bindable var store: ReaderStore
    let articleID: UUID
    let onMessage: (String) -> Void
    @State private var newName = ""
    @State private var error: String?

    private var memberOf: Set<UUID> { Set(store.themeIDs(containing: articleID)) }
    private var canCreate: Bool { !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("テーマに入れる").font(.headline)
            if store.themes.isEmpty {
                Text("まだテーマがありません。下で作成すると、この記事が入ります。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(store.themes) { theme in
                            row(theme)
                        }
                    }
                }.frame(maxHeight: 220)
            }
            Divider()
            HStack {
                TextField("新しいテーマの名前", text: $newName).onSubmit(create)
                Button("作成して入れる", action: create).disabled(!canCreate)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(14).frame(width: 300)
    }

    private func row(_ theme: Theme) -> some View {
        let included = memberOf.contains(theme.id)
        return Button { toggle(theme.id) } label: {
            HStack {
                Image(systemName: included ? "checkmark.square.fill" : "square")
                    .foregroundStyle(included ? Color.orange : Color.secondary)
                Text(theme.name).lineLimit(1)
                Spacer()
            }.contentShape(Rectangle()).padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityValue(included ? "入っています" : "入っていません")
    }

    private func toggle(_ themeID: UUID) {
        do {
            switch try store.toggleTheme(themeID, for: articleID, at: .now) {
            case .added(let name): onMessage("「\(name)」に入れました")
            case .removed(let name): onMessage("「\(name)」から外しました")
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func create() {
        guard canCreate else { return }
        do {
            let theme = try store.createTheme(name: newName, adding: articleID, at: .now)
            onMessage("「\(theme.name)」に入れました")
            newName = ""; error = nil
        } catch { self.error = error.localizedDescription }
    }
}
