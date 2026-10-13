import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: the ✕, previous and next article buttons, the copy button, and the editor.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            NoteEditor(store: store)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("ノート")
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // The ✕ at the top left of the right column, where the original page has its own (decision 0050).
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)) }
                    .help("ノートを閉じる (Esc)").accessibilityLabel("ノートを閉じる")
                Spacer(minLength: 0)
                Button(action: onPrevious) { Image(systemName: "chevron.up") }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(!canPrevious).help("前の記事 (⌥⌘↑)").accessibilityLabel("前の記事")
                Button(action: onNext) { Image(systemName: "chevron.down") }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(!canNext).help("次の記事 (⌥⌘↓)").accessibilityLabel("次の記事")
                // The text is copied as it is; the person pastes it into any AI they like (decision 0049).
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                    .disabled(!hasText).help("Markdownをコピー").accessibilityLabel("Markdownをコピー")
            }
            .buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(AppPalette.surfaceColor)
    }

    private var hasText: Bool {
        !(store.note?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
