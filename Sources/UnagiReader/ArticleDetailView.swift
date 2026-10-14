import SwiftUI
import ReaderCore

struct ArticleDetailView: View {
    let article: Article
    let content: ArticleContent?
    let expiry: Date?
    let updateAvailable: Bool
    let error: String?
    let initialAnchor: String?
    let initialOffset: Double
    let onScroll: (String, Double) -> Void
    let onInteraction: () -> Void
    let onUpdate: () -> Void
    let onDisplayBegin: () -> Void
    let onDisplayed: () -> Void
    let imageLoader: ReaderImageLoader
    var pageForward = true
    /// False while the original page covers the reader text: the page's slide-out is the only motion then (one motion at a time).
    var pageMotion = true
    /// The translated title and paragraphs to show in place of the original (specification 3.6). The status is in the article band.
    var translated: TranslatedArticle? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var available: Bool { content?.articleID == article.id && (expiry ?? .distantPast) > .now }
    private var date: String { article.publishedAt == .distantPast ? "公開日時不明" : article.publishedAt.formatted(.dateTime.year().month().day()) }
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: ArticleBand.contentTop)              // the text starts where it did under the old toolbar
            if updateAvailable || error != nil {
                HStack {
                    if updateAvailable { Button("取得した本文に切り替える", action: onUpdate).buttonStyle(.link) }
                    if let error { Text(error) }
                }.font(.caption).foregroundStyle(.secondary).padding(12)
            }
            NativeArticleText(articleID: article.id, title: translated?.title ?? article.title, publisher: article.publisher.uppercased(), date: date,
                paragraphs: available ? (translated?.paragraphs.map(\.text) ?? content!.paragraphs) : [],
                unavailable: available ? nil : (article.contentDeletedAt != nil ? "本文とRSS要約は削除済みです。" : "本文を利用できません。"),
                initialAnchor: initialAnchor, initialOffset: initialOffset, reduceMotion: reduceMotion || !pageMotion, onScroll: onScroll, onInteraction: onInteraction, onDisplayBegin: onDisplayBegin, onDisplayed: onDisplayed,
                imageLoader: imageLoader, heroURL: available ? article.imageURL.flatMap { ArticleURL.validated($0) } : nil,
                bodyParagraphs: available ? (translated?.paragraphs ?? content!.bodyParagraphs) : nil, pageForward: pageForward)
        }.background(AppPalette.surfaceColor)
    }
}
