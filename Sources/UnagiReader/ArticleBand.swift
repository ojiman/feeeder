import SwiftUI
import ReaderCore

/// The article column's band at the top of the window (decision 0057): the translation status at the left, the article's buttons at the
/// right, in one monochrome style. The empty part moves the window, as a title bar does.
struct ArticleBand: View {
    /// As high as the band of the window buttons.
    static let height = ListHeader.bandHeight
    /// How far below the top the article's text starts, so that its first line keeps the place it had under the old toolbar.
    static let contentTop: CGFloat = 28

    let status: ArticleTranslation.State
    let showOriginal: () -> Void
    let buttons: [BandButton]

    var body: some View {
        HStack(spacing: 2) {
            TranslationStatusRow(state: status, showOriginal: showOriginal)
            Spacer(minLength: 8)
            ForEach(buttons) { $0 }
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background { BandDragArea() }
    }
}

/// One control of a band: a monochrome symbol of one size and one hit area. Colour only shows a state, through the symbol (filled).
struct BandButton: View, Identifiable {
    let id: String
    let symbol: String
    let help: String
    let label: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .regular)).frame(width: 28, height: 28).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help).accessibilityLabel(label)
        .disabled(!enabled)
    }
}

/// The empty part of a band: dragging it moves the window (the window has no title bar of its own; decision 0057).
struct BandDragArea: View {
    var body: some View {
        AppPalette.surfaceColor.contentShape(Rectangle()).gesture(WindowDragGesture())
    }
}
