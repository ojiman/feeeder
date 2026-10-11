import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: previous and next article buttons (and the Claude button), and the
/// editor. The note's title is its first line, so the header has no title of its own. Every button is borderless: a borderless SwiftUI button is an AppKit button, so a test can press it.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let noteID: UUID
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    /// Nil when there is nothing to hand over (no note, no article).
    let onAskReview: (() -> Void)?

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
                if let onAskReview {
                    Button("Claudeでレビューを頼む", systemImage: "paperplane", action: onAskReview)
                        .lineLimit(1).fixedSize()
                        .help("ノートを、確認したうえで Claude へ渡して、レビューを頼みます")
                }
                Button(action: onPrevious) { Image(systemName: "chevron.up") }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(!canPrevious).help("前の記事 (⌥⌘↑)").accessibilityLabel("前の記事")
                Button(action: onNext) { Image(systemName: "chevron.down") }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(!canNext).help("次の記事 (⌥⌘↓)").accessibilityLabel("次の記事")
            }
            .buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(.bar)
    }
}
