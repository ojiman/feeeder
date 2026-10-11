import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: previous and next article buttons, sharing actions, and the editor.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let noteID: UUID
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClaude: () -> Void
    let onCopy: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            NoteEditor(store: store, noteID: noteID)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("ノート")
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(action: onPrevious) { Image(systemName: "chevron.up") }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(!canPrevious).help("前の記事 (⌥⌘↑)").accessibilityLabel("前の記事")
                Button(action: onNext) { Image(systemName: "chevron.down") }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(!canNext).help("次の記事 (⌥⌘↓)").accessibilityLabel("次の記事")
                Menu {
                    Button("Claudeで開く…", systemImage: "arrow.up.right.square", action: onClaude).disabled(!hasText)
                    Button("Markdownをコピー", systemImage: "doc.on.doc", action: onCopy).disabled(!hasText)
                    Button("Markdownとして書き出す…", systemImage: "square.and.arrow.down", action: onExport).disabled(!hasText)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("ノートを共有")
                .accessibilityIdentifier("note-share")
                .help("ノートを共有または書き出します")
            }
            .buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(AppPalette.surfaceColor)
    }

    private var hasText: Bool {
        !(store.note(id: noteID)?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
