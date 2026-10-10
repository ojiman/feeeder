import SwiftUI
import ReaderCore

/// The note, opened beside the article as the inspector: the theme's name and goal with previous and next article buttons, the
/// button that summarizes the article in the reader, the editor, and the two note actions under it. Every button is borderless:
/// a borderless SwiftUI button is an AppKit button, so a test can press it.
struct NotePanel: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @Binding var selection: TextSelection?
    let handle: NoteTextHandle
    let aiEnabled: Bool
    let noteActions: NoteActionModel?
    let summaries: ArticleSummaryModel?
    /// The article shown in the reader, the one 「記事から要約する」 works on.
    let article: Article?
    let summaryAdopted: Bool
    let canPrevious: Bool
    let canNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onEditGoal: () -> Void
    /// Nil when there is nothing to hand over (no goal, no note, no article).
    let onAskReview: (() -> Void)?
    let onSummarize: () -> Void
    let onAdoptSummary: (ArticleSummaryModel.Summary) -> Void
    let onNoteAdopted: (NSRange) -> Void
    let onError: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if aiEnabled, let summaries { NoteSummarySection(model: summaries, article: article, adopted: summaryAdopted, onRequest: onSummarize, onAdopt: onAdoptSummary) }
            NoteEditor(store: store, themeID: themeID, selection: $selection)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if aiEnabled, let noteActions {
                NoteActionPanel(store: store, themeID: themeID, model: noteActions, handle: handle, selection: selection, onAdopted: onNoteAdopted, onError: onError)
            }
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

/// 「記事から要約する」 and its card. Nothing is made until the person presses the button; the text is saved nowhere unless adopted.
struct NoteSummarySection: View {
    let model: ArticleSummaryModel
    let article: Article?
    let adopted: Bool
    let onRequest: () -> Void
    let onAdopt: (ArticleSummaryModel.Summary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button("記事から要約する", systemImage: "sparkles", action: onRequest)
                    .disabled(article == nil || isWorking)
                    .help("いま右に開いている記事を、端末内のAIで3文以内に要約します。押したときだけ作ります")
                if article == nil { Text("記事を選ぶと要約できます").font(.caption).foregroundStyle(.tertiary) }
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            card
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var isWorking: Bool { if case .working = model.state { return true }; return false }

    /// A summary made for another article is never shown or adopted here, whatever the model still holds.
    private var shown: ArticleSummaryModel.State {
        if case .ready(let value) = model.state, value.articleID != article?.id { return .idle }
        return model.state
    }

    @ViewBuilder private var card: some View {
        switch shown {
        case .idle: EmptyView()
        case .working:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("要約を作っています…").font(.callout).foregroundStyle(.secondary)
                Button("中止") { model.cancel() }.buttonStyle(.borderless)
            }
        case .ready(let summary):
            VStack(alignment: .leading, spacing: 6) {
                Label("AIによる要約", systemImage: "sparkles").font(.caption.weight(.semibold))
                Text(summary.text).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if summary.wasCut { Text("長い記事のため、最初の約3,000文字から要約しました。").font(.caption).foregroundStyle(.secondary) }
                if summary.fromThemeSummary { Text("テーマに記録したRSS要約から作りました。").font(.caption).foregroundStyle(.secondary) }
                Text("AIによる案です。誤りを含むことがあります。原文で確かめてください。採用は ⌘Z で戻せます。").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    Button(adopted ? "採用しました" : "ノートに採用") { onAdopt(summary) }.disabled(adopted)
                    Button("作り直す", action: onRequest)
                    Button("閉じる") { model.reset() }
                }.buttonStyle(.borderless)
            }
            .padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        case .unavailable(let reason):
            Text(Self.message(for: reason)).font(.caption).foregroundStyle(.secondary)
        case .failed:
            HStack(spacing: 10) {
                Text("要約を作れませんでした。もう一度試すか、原文を読んでください。").font(.caption).foregroundStyle(.secondary)
                Button("もう一度", action: onRequest).buttonStyle(.borderless)
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
