import SwiftUI

/// The title of the article list: the name of the feed, folder or note, and how many articles it holds, at the top of the middle column.
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
    /// The height of the title bar band the header sits in. The system does not tell it: the safe area of this view reports 0 (the list
    /// draws under the toolbar and handles the inset itself), so this is the toolbar's standard height. If it is wrong on another system
    /// the title is a little off-centre in the band; nothing breaks.
    static let bandHeight: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.tail)
            Text("\(count)件の記事").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.sideMargin)
        .frame(height: Self.bandHeight, alignment: .center)
        .allowsHitTesting(false)                                  // the band still drags the window
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
