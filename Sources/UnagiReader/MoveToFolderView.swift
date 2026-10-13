import SwiftUI
import ReaderCore

/// 「フォルダへ移動…」: type to narrow the existing folders, or type a name that is not a folder yet and move into it in the same step.
/// ↑↓ choose, Return moves, Esc closes (the same keys as the subscription form's folder field). The candidates come from `FolderPicker`.
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
            FolderCandidateList(entries: entries, highlighted: highlighted, createSuffix: "を作って移動", onChoose: choose)
        }
        .padding(12).frame(width: 260)
        .onAppear { query = initialQuery; focused = true }
        .onChange(of: query) { highlighted = 0 }
    }

    private func choose(_ index: Int) {
        guard entries.indices.contains(index) else { return }
        onMove(entries[index].folder)
    }
}
