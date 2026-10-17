import SwiftUI
import ReaderCore

/// The title of the article list: the name of the feed, folder or note, and how many articles it holds, at the top of the middle column,
/// below the toolbar band.
///
/// It is drawn here instead of as the window's navigation title. The system lets that title run along the whole toolbar, so a long
/// feed name left its column and ran over the article pane. Here the name stays inside the column and ends with an ellipsis when the
/// column is narrow, like the names in the sidebar.
///
/// This is a workaround for the system title, kept in this one file. To take it out: delete this file and the `overlay` that uses it
/// in `ReaderView`, and set `navigationTitle(scopeTitle)` and `navigationSubtitle` on the list again.
struct ListHeader: View {
    let title: String
    let count: Int

    /// Same left and right margin as the text of the rows below, so the title and the rows share one edge.
    static let sideMargin = NativeArticleList.Metrics.contentMargin
    /// The height of the window's toolbar band (the window buttons, the ✕ of the right column and the toolbar's buttons sit in it).
    /// The system does not tell it: the safe area of the columns reports 0 (they draw under the toolbar), so this is the toolbar's
    /// standard height. If it is wrong on another system the title block is a little off; nothing breaks.
    static let bandHeight: CGFloat = 52
    /// How far below the band the centre of the ✕ of the right column is (the ✕ of the original page: a 12 pt symbol
    /// with 10 pt around it). Measured in the running app. The first line of the title is centred on it, so the two share one height.
    static let crossCentre: CGFloat = 16
    /// The line height of the 17 pt title.
    static let titleLine: CGFloat = 21
    /// The height of the title block, which sits below the band (decision 0048). The list leaves this room above its first row.
    static let height: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1).truncationMode(.tail)
            Text(String(localized: "\(count) articles", bundle: ReaderLocalization.bundle)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.sideMargin)
        .padding(.top, Self.crossCentre - Self.titleLine / 2)
        .frame(height: Self.height, alignment: .top)
        .background(AppPalette.surfaceColor)                       // rows that scroll up under the block do not show through it
        .padding(.top, Self.bandHeight)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
