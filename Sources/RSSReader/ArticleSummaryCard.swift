import SwiftUI
import ReaderCore

/// What the reader's right column shows on the note face: the article itself, or an AI summary of it.
enum ReaderPaneMode: Hashable { case original, summary }

/// The AI summary of the article that is open. Nothing is made until the person asks; the text is saved nowhere unless adopted.
struct ArticleSummaryCard: View {
    let state: ArticleSummaryModel.State
    let articleTitle: String
    let adopted: Bool
    let onRequest: () -> Void
    let onCancel: () -> Void
    let onAdopt: (ArticleSummaryModel.Summary) -> Void
    let onShowOriginal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("AIによる要約", systemImage: "sparkles").font(.headline)
                Spacer()
                Button("原文を見る", action: onShowOriginal).buttonStyle(.link)
            }
            Text(articleTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            Divider()
            content
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityElement(children: .contain).accessibilityLabel("AIによる要約")
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .idle:
            VStack(alignment: .leading, spacing: 10) {
                Text("この記事を、端末内のAIで要約します。頼んだときだけ作り、採用するまでどこにも保存しません。").font(.callout).foregroundStyle(.secondary)
                Button("要約を作る", action: onRequest).buttonStyle(.borderedProminent)
            }
        case .working:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("要約を作っています…").foregroundStyle(.secondary)
                Button("中止", action: onCancel)
            }
        case .ready(let summary):
            VStack(alignment: .leading, spacing: 12) {
                Text(summary.text).font(.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if summary.wasCut { Text("長い記事のため、最初の約3,000文字から要約しました。").font(.caption).foregroundStyle(.secondary) }
                if summary.fromThemeSummary { Text("テーマに記録したRSS要約から作りました。").font(.caption).foregroundStyle(.secondary) }
                Text("誤りを含むことがあります。原文で確かめてください。").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(adopted ? "採用しました" : "ノートに採用") { onAdopt(summary) }.disabled(adopted)
                    Button("作り直す", action: onRequest)
                }
            }
        case .unavailable(let reason):
            VStack(alignment: .leading, spacing: 10) {
                Text(Self.message(for: reason)).font(.callout).foregroundStyle(.secondary)
                if reason == .assetsMissing { Button("もう一度確かめる", action: onRequest) }
            }
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                Text("要約を作れませんでした。もう一度試すか、原文を読んでください。").font(.callout).foregroundStyle(.secondary)
                Button("もう一度", action: onRequest)
            }
        }
    }

    static func message(for reason: ArticleSummaryModel.Reason) -> String {
        switch reason {
        case .disabled: "端末内AIがオフです。Settingsで有効にできます。"
        case .noText: "この記事の本文は保持期限を過ぎているため、要約できません。"
        case .unsupported: "この Mac では端末内AIを使えません。"
        case .assetsMissing: "言語モデルの資産がありません。システム設定で取得できます。アプリは自動では取得しません。"
        }
    }
}
