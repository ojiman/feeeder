import SwiftUI
import ReaderCore

/// The rows under a folder field: 「未分類」, the existing folders and 「…を作って…」. Used by 「フォルダへ移動…」 and by the add sheet.
/// More than `maxRows` candidates scroll, so the sheet does not grow without end.
struct FolderCandidateList: View {
    let entries: [FolderPicker.Entry]
    let highlighted: Int?
    /// What follows the name on the row that makes a new folder: 「を作って移動」 or 「を作って追加」.
    let createTitle: (String) -> String
    var maxRows = 6
    let onChoose: (Int) -> Void

    var body: some View {
        if entries.count > maxRows { ScrollView { rows }.frame(height: CGFloat(maxRows) * 29) } else { rows }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                Button { onChoose(index) } label: {
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
    private func symbol(_ entry: FolderPicker.Entry) -> String {
        switch entry { case .unfiled: "tray"; case .existing: "folder"; case .create: "folder.badge.plus" }
    }
    private func title(_ entry: FolderPicker.Entry) -> String {
        switch entry { case .unfiled: String(localized: "Unfiled", bundle: ReaderLocalization.bundle); case .existing(let name): name; case .create(let name): createTitle(name) }
    }
}
