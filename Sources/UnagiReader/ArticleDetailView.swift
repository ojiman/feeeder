import SwiftUI
import ReaderCore

struct ArticleDetailView: View {
    let article: Article
    let content: ArticleContent?
    let expiry: Date?
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var available: Bool { content?.articleID == article.id && (expiry ?? .distantPast) > .now }
    private var date: String { article.publishedAt == .distantPast ? "公開日時不明" : article.publishedAt.formatted(.dateTime.year().month().day()) }
    var body: some View {
        VStack(spacing: 0) {
            if available && !loading {
                HStack {
                    Spacer()
                    Button("本文を再取得", action: onReload).buttonStyle(.link)
                        .help("原文から本文とリンクを再取得します。取得に失敗した場合は保存済み本文を表示します。")
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
                initialAnchor: initialAnchor, initialOffset: initialOffset, reduceMotion: reduceMotion, onScroll: onScroll, onInteraction: onInteraction, onDisplayBegin: onDisplayBegin, onDisplayed: onDisplayed,
                imageLoader: imageLoader, heroURL: available ? article.imageURL.flatMap { ArticleURL.validated($0) } : nil,
                bodyParagraphs: available ? content!.bodyParagraphs : nil, pageForward: pageForward)
        }.background(AppPalette.surfaceColor)
    }
}
