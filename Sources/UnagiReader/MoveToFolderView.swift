import SwiftUI
import ReaderCore

/// 「フォルダへ移動…」: type to narrow the existing folders, or type a name that is not a folder yet and move into it in the same step.
/// ↑↓ choose, Return moves, Esc closes (the same keys as the small chooser of 「ノートに要約を送る」). The candidates come from `FolderPicker`.
struct MoveToFolderView: View {
    let folders: [String]
    let current: String
    let onMove: (String) -> Void
    let onClose: () -> Void
    /// What is typed when the chooser opens (empty; the tests and snapshots start with a word).
    var initialQuery = ""
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool
    private var entries: [FolderPicker.Entry] { FolderPicker.entries(query: query, folders: folders, current: current) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("フォルダ名", text: $query.singleLine())
                .textFieldStyle(.roundedBorder).focused($focused)
                .accessibilityLabel("移動先のフォルダ名")
                .onSubmit { choose(highlighted) }
                .onKeyPress(.upArrow) { highlighted = max(0, highlighted - 1); return .handled }
                .onKeyPress(.downArrow) { highlighted = min(max(0, entries.count - 1), highlighted + 1); return .handled }
                .onKeyPress(.escape) { onClose(); return .handled }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    Button { choose(index) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: symbol(entry)).foregroundStyle(.secondary).frame(width: 18)
                            Text(title(entry)).lineLimit(1)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 6).padding(.vertical, 5).contentShape(Rectangle())
                            .background(highlighted == index ? AppPalette.selectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).accessibilityLabel(title(entry))
                }
            }
        }
        .padding(12).frame(width: 260)
        .onAppear { query = initialQuery; focused = true }
        .onChange(of: query) { highlighted = 0 }
    }

    private func choose(_ index: Int) {
        guard entries.indices.contains(index) else { return }
        onMove(entries[index].folder)
    }
    private func symbol(_ entry: FolderPicker.Entry) -> String {
        switch entry { case .unfiled: "tray"; case .existing: "folder"; case .create: "folder.badge.plus" }
    }
    private func title(_ entry: FolderPicker.Entry) -> String {
        switch entry { case .unfiled: "未分類"; case .existing(let name): name; case .create(let name): "「\(name)」を作って移動" }
    }
}
