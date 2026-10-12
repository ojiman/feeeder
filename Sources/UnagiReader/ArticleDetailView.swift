import SwiftUI
import ReaderCore

struct ArticleDetailView: View {
    let article: Article
    let content: ArticleContent?
    let expiry: Date?
    /// The article is within retention, so its page may be fetched even when the feed gave no text at all (「全文を取得」).
    var canFetchPage = false
    let loading: Bool
    let updateAvailable: Bool
    let error: String?
    let initialAnchor: String?
    let initialOffset: Double
    let onScroll: (String, Double) -> Void
    let onInteraction: () -> Void
    let onUpdate: () -> Void
    let onReload: () -> Void
    let onDisplayBegin: () -> Void
    let onDisplayed: () -> Void
    let imageLoader: ReaderImageLoader
    var pageForward = true
    /// False while the original page covers the reader text: the page's slide-out is the only motion then (one motion at a time).
    var pageMotion = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var available: Bool { content?.articleID == article.id && (expiry ?? .distantPast) > .now }
    private var date: String { article.publishedAt == .distantPast ? "公開日時不明" : article.publishedAt.formatted(.dateTime.year().month().day()) }
    var body: some View {
        VStack(spacing: 0) {
            if (available || canFetchPage) && !loading {
                HStack {
                    Spacer()
                    Button(content?.coverage == .extracted ? "本文を再取得" : "全文を取得", action: onReload).buttonStyle(.link)
                        .help("原文のページから本文を取り込みます。取得できない場合は、今の本文をそのまま表示します。")
                        .disabled(article.originalURL.flatMap { ArticleURL.validated($0) } == nil)
                }.font(.caption).padding(.horizontal, 16).padding(.vertical, 6)
            }
            if loading || updateAvailable || error != nil {
                HStack {
                    if loading { Label("本文を確認中", systemImage: "arrow.down.doc") }
                    if updateAvailable { Button("取得した本文に切り替える", action: onUpdate).buttonStyle(.link) }
                    if let error { Text(error) }
                }.font(.caption).foregroundStyle(.secondary).padding(12)
            }
            NativeArticleText(articleID: article.id, title: article.title, publisher: article.publisher.uppercased(), date: date,
                coverage: available ? content!.coverage.label : "本文は利用できません",
                paragraphs: available ? content!.paragraphs : [],
                unavailable: available ? nil : (article.contentDeletedAt != nil ? "本文とRSS要約は削除済みです。" : "本文を利用できません。"),
                initialAnchor: initialAnchor, initialOffset: initialOffset, reduceMotion: reduceMotion || !pageMotion, onScroll: onScroll, onInteraction: onInteraction, onDisplayBegin: onDisplayBegin, onDisplayed: onDisplayed,
                imageLoader: imageLoader, heroURL: available ? article.imageURL.flatMap { ArticleURL.validated($0) } : nil,
                bodyParagraphs: available ? content!.bodyParagraphs : nil, pageForward: pageForward)
        }.background(AppPalette.surfaceColor)
    }
}
