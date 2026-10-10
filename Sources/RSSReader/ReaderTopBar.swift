import SwiftUI
import ReaderCore

/// Above the reader on a theme's note face: move between the theme's articles without leaving the note.
/// `⌥⌘↑` and `⌥⌘↓` work while the cursor is in the note (the text system does not use them).
struct ReaderTopBar: View {
    let entries: [ThemeArticleEntry]
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onChoose: (UUID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) { Image(systemName: "chevron.left") }
                .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                .disabled(!canPrevious).help("前の記事 (⌥⌘↑)").accessibilityLabel("前の記事")
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                .disabled(!canNext).help("次の記事 (⌥⌘↓)").accessibilityLabel("次の記事")
            Menu {
                if entries.isEmpty { Text("このテーマに記事はありません") }
                ForEach(entries, id: \.id) { entry in
                    Button { onChoose(entry.id) } label: {
                        if entry.isCurrent { Label(entry.title, systemImage: "checkmark") } else { Text(entry.title) }
                    }
                }
            } label: {
                Text(entries.first(where: \.isCurrent)?.title ?? "記事を選ぶ").lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.borderlessButton).accessibilityLabel("このテーマの記事")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
