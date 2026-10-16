import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: its band (the ✕, the layout button, previous and next article, copy) and the
/// editor.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onCopy: () -> Void
    let onClose: () -> Void
    /// The note shows the list beside it (the layout button's state).
    let listShown: Bool
    let onSwitchLayout: () -> Void
    /// How 「記事をノートに送る」 reaches the editor (specification 3.3).
    let link: NoteEditorLink

    var body: some View {
        VStack(spacing: 0) {
            header
            NoteEditor(store: store, link: link)
        }
        .ignoresSafeArea(.container, edges: .top)                          // the band is at the top of the window, like the others
        .accessibilityElement(children: .contain).accessibilityLabel("ノート")
    }

    /// The note's band (decision 0057): the ✕ and the layout button at the left, the article arrows and copy at the right.
    private var header: some View {
        HStack(spacing: 2) {
            // The ✕ at the top left of the right column, where the original page has its own (decision 0050).
            BandButton(id: "close", symbol: "xmark", help: "ノートを閉じる (Esc)", label: "ノートを閉じる", action: onClose)
            // The two layouts of the open note (decision 0050).
            BandButton(id: "layout", symbol: listShown ? "rectangle.split.3x1" : "rectangle.split.2x1",
                       help: listShown ? "記事の一覧を隠す" : "記事の一覧を出す", label: listShown ? "記事の一覧を隠す" : "記事の一覧を出す",
                       action: onSwitchLayout)
            Spacer(minLength: 8)
            BandButton(id: "previous", symbol: "chevron.up", help: "前の記事 (⌥⌘↑)", label: "前の記事", enabled: canPrevious,
                       shortcut: KeyboardShortcut(.upArrow, modifiers: [.option, .command]), action: onPrevious)
            BandButton(id: "next", symbol: "chevron.down", help: "次の記事 (⌥⌘↓)", label: "次の記事", enabled: canNext,
                       shortcut: KeyboardShortcut(.downArrow, modifiers: [.option, .command]), action: onNext)
            // The text is copied as it is; the person pastes it into any AI they like (decision 0049).
            BandButton(id: "copy", symbol: "doc.on.doc", help: "Markdownをコピー", label: "Markdownをコピー", enabled: hasText, action: onCopy)
        }
        .bandLayout()
    }

    private var hasText: Bool {
        !(store.note?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
