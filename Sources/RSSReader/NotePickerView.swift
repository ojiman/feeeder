import SwiftUI
import ReaderCore

/// Opened by `t` and by the toolbar icon. One text field filters the notes; ↑/↓ move the highlight and Return
/// adds the article to (or removes it from) the highlighted note, or creates a new one. Rows can also be clicked.
struct NotePickerView: View {
    @Bindable var store: ReaderStore
    let articleID: UUID
    let onMessage: (String) -> Void
    @State private var query = ""
    @State private var highlighted: Int?
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    private var memberOf: Set<UUID> { Set(store.noteIDs(containing: articleID)) }
    private var rows: [NotePickerRow] {
        NotePicker.rows(notes: store.notes.map { ($0.id, $0.title) }, memberOf: memberOf, query: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ノートに入れる").font(.headline)
            TextField("ノートを探す、または新しい名前", text: $query.singleLine())
                .focused($fieldFocused)
                .onSubmit(activateHighlighted)
                .onKeyPress(.return) {
                    guard NSEvent.modifierFlags.contains(.command),
                          let action = NotePicker.explicitAction(rows: rows, query: query) else { return .ignored }
                    run(action); return .handled
                }
                .onKeyPress(.upArrow) { highlighted = NotePicker.move(highlighted, by: -1, count: rows.count); return .handled }
                .onKeyPress(.downArrow) { highlighted = NotePicker.move(highlighted, by: 1, count: rows.count); return .handled }
                .accessibilityLabel("ノートを探す、または新しい名前")
            if rows.isEmpty {
                Text("まだノートがありません。名前を入力すると、新しく作ってこの記事を入れられます。")
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
        .onAppear { fieldFocused = true; highlighted = NotePicker.defaultHighlight(rows: rows, query: query) }
        .onChange(of: query) { _, _ in highlighted = NotePicker.defaultHighlight(rows: rows, query: query) }
    }

    private func rowView(_ row: NotePickerRow, highlighted: Bool) -> some View {
        let symbol: String
        switch row.kind {
        case .note: symbol = row.included ? "checkmark.square.fill" : "square"
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

    private func perform(for row: NotePickerRow) {
        switch row.kind {
        case .note(let id): run(.toggle(id))
        case .create(let name): run(.create(name))
        }
    }
    private func activateHighlighted() {
        guard let action = NotePicker.action(rows: rows, highlighted: highlighted) else { return }
        run(action)
    }
    private func run(_ action: NotePickerAction) {
        do {
            switch action {
            case .toggle(let id):
                switch try store.toggleNote(id, for: articleID, at: .now) {
                case .added(let title): onMessage("「\(title)」に入れました")
                case .removed(let title): onMessage("「\(title)」から外しました")
                }
            case .create(let name):
                // A new note starts with its title as the first line (the title is the first line, decision 0019).
                let note = try store.createNote(text: "# \(name)\n", adding: articleID, at: .now)
                onMessage("「\(note.title)」に入れました")
                query = ""
            }
            error = nil
            highlighted = NotePicker.defaultHighlight(rows: rows, query: query)
        } catch { self.error = error.localizedDescription }
    }
}
