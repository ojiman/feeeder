import SwiftUI
import ReaderCore

/// Opened by `t` and by the toolbar icon. One text field filters the themes; ↑/↓ move the highlight and Return
/// adds the article to (or removes it from) the highlighted theme, or creates a new one. Rows can also be clicked.
struct ThemePickerView: View {
    @Bindable var store: ReaderStore
    let articleID: UUID
    let onMessage: (String) -> Void
    @State private var query = ""
    @State private var highlighted: Int?
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    private var memberOf: Set<UUID> { Set(store.themeIDs(containing: articleID)) }
    private var rows: [ThemePickerRow] {
        ThemePicker.rows(themes: store.themes.map { ($0.id, $0.name) }, memberOf: memberOf, query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("テーマに入れる").font(.headline)
            TextField("テーマを探す、または新しい名前", text: $query)
                .focused($fieldFocused)
                .onSubmit(activateHighlighted)
                .onKeyPress(.return) {
                    guard NSEvent.modifierFlags.contains(.command),
                          let action = ThemePicker.explicitAction(rows: rows, query: query) else { return .ignored }
                    run(action); return .handled
                }
                .onKeyPress(.upArrow) { highlighted = ThemePicker.move(highlighted, by: -1, count: rows.count); return .handled }
                .onKeyPress(.downArrow) { highlighted = ThemePicker.move(highlighted, by: 1, count: rows.count); return .handled }
                .accessibilityLabel("テーマを探す、または新しい名前")
            if rows.isEmpty {
                Text("まだテーマがありません。名前を入力すると、新しく作ってこの記事を入れられます。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            rowView(row, highlighted: index == highlighted)
                        }
                    }
                }.frame(maxHeight: 220)
            }
            Text("↑↓で選び、Returnで入れる／外す。⌘Returnで入力した名前で作る。Escで閉じる。").font(.caption2).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(14).frame(width: 300)
        .onAppear { fieldFocused = true; highlighted = ThemePicker.defaultHighlight(rows: rows, query: query) }
        .onChange(of: query) { _, _ in highlighted = ThemePicker.defaultHighlight(rows: rows, query: query) }
    }

    private func rowView(_ row: ThemePickerRow, highlighted: Bool) -> some View {
        let symbol: String
        switch row.kind {
        case .theme: symbol = row.included ? "checkmark.square.fill" : "square"
        case .create: symbol = "plus.square"
        }
        return Button { perform(for: row) } label: {
            HStack {
                Image(systemName: symbol).foregroundStyle(row.included ? Color.orange : Color.secondary)
                Text(row.title).lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle()).padding(.vertical, 3).padding(.horizontal, 4)
            .background(highlighted ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.title)
        .accessibilityValue(row.included ? "入っています" : "入っていません")
    }

    private func perform(for row: ThemePickerRow) {
        switch row.kind {
        case .theme(let id): run(.toggle(id))
        case .create(let name): run(.create(name))
        }
    }
    private func activateHighlighted() {
        guard let action = ThemePicker.action(rows: rows, highlighted: highlighted) else { return }
        run(action)
    }
    private func run(_ action: ThemePickerAction) {
        do {
            switch action {
            case .toggle(let id):
                switch try store.toggleTheme(id, for: articleID, at: .now) {
                case .added(let name): onMessage("「\(name)」に入れました")
                case .removed(let name): onMessage("「\(name)」から外しました")
                }
            case .create(let name):
                let theme = try store.createTheme(name: name, adding: articleID, at: .now)
                onMessage("「\(theme.name)」に入れました")
                query = ""
            }
            error = nil
            highlighted = ThemePicker.defaultHighlight(rows: rows, query: query)
        } catch { self.error = error.localizedDescription }
    }
}
