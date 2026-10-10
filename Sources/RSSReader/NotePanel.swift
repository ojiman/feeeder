import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: the theme's name and goal with previous and next article buttons, and the
/// editor. Every button is borderless: a borderless SwiftUI button is an AppKit button, so a test can press it.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onEditGoal: () -> Void
    /// Nil when there is nothing to hand over (no goal, no note, no article).
    let onAskReview: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            NoteEditor(store: store, themeID: themeID)
        }
        .accessibilityElement(children: .contain).accessibilityLabel("ノート")
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(store.theme(id: themeID)?.name ?? "テーマ").font(.headline).lineLimit(1)
                Spacer(minLength: 0)
                if let onAskReview {
                    Button("Claudeでレビューを頼む", systemImage: "paperplane", action: onAskReview)
                        .help("ゴールとノートを、確認したうえで Claude へ渡して、ノートのレビューを頼みます")
                }
                Button(action: onPrevious) { Image(systemName: "chevron.up") }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
                    .disabled(!canPrevious).help("前の記事 (⌥⌘↑)").accessibilityLabel("前の記事")
                Button(action: onNext) { Image(systemName: "chevron.down") }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command])
                    .disabled(!canNext).help("次の記事 (⌥⌘↓)").accessibilityLabel("次の記事")
            }
            .buttonStyle(.borderless).padding(.horizontal, 12).padding(.vertical, 8)
            ThemeGoalStrip(goal: store.theme(id: themeID)?.goal ?? "", onEdit: onEditGoal)
        }
        .background(.bar)
    }
}
