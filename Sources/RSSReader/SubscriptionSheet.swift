import SwiftUI
import ReaderCore

struct SubscriptionSheet: View {
    let store: ReaderStore
    var feed: Feed?
    let onImported: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var xml = ""
    @State private var manualXML = false
    @State private var etag: String?
    @State private var lastModified: String?
    @State private var title = ""
    @State private var folder = ""
    @State private var busy = false
    @State private var error: String?
    @State private var result: ParsedFeed?
    @State private var parseTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(feed == nil ? "購読を追加" : "購読を編集").font(.title2.bold())
            if let feed {
                TextField("購読名", text: $title)
                TextField("フォルダ（任意・1階層）", text: $folder)
                if let url = feed.sourceURL { Text(url).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                Text("ツールバーの更新ボタンで最新の記事を取得できます。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("RSS / AtomのURLを入力して、記事を取得します。")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("フィードURL（https://…）", text: $source).disabled(busy)
                Toggle("XMLを直接入力（合成サンプル・トラブル確認用）", isOn: $manualXML).font(.caption).disabled(busy)
                if manualXML {
                    TextEditor(text: $xml).font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 240).border(.quaternary)
                        .accessibilityLabel("フィードXML").disabled(busy)
                    HStack {
                        Menu("合成サンプルを入力") {
                            ForEach(FeedExample.allCases, id: \.self) { example in
                                Button(example.rawValue) { source = example.url; xml = example.xml; result = nil }
                            }
                        }
                        .disabled(busy)
                        Spacer()
                        Text("RSS 1.0 / RSS 2.0 / Atom · 2MBまで").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let result, result.skippedEntries > 0 {
                    Text("識別子も記事URLもない\(result.skippedEntries)件を取り込めません。残り\(result.entries.count)件を取り込みます。")
                        .font(.callout).foregroundStyle(.orange)
                }
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled) }
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("キャンセル") { parseTask?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
                Button(feed == nil ? (result == nil ? "取得して取り込む" : "残りの記事を取り込む") : "保存", action: submit)
                    .keyboardShortcut(.defaultAction).disabled(busy)
            }
        }
        .padding(24).frame(width: 600)
        .onAppear { title = feed?.title ?? ""; folder = feed?.folder ?? "" }
        .onChange(of: xml) { _, _ in result = nil }
        .onChange(of: source) { _, _ in result = nil }
        .onChange(of: manualXML) { _, _ in result = nil }
        .onDisappear { parseTask?.cancel() }
    }

    private func submit() {
        error = nil
        if let feed {
            do { try store.updateSubscription(feed, title: title, folder: folder); dismiss() }
            catch { self.error = error.localizedDescription }
            return
        }
        if let result { commit(result); return }
        guard let url = ArticleURL.validated(source) else { error = FeedImportError.invalidURL.localizedDescription; return }
        let input = Data(xml.utf8)
        let manual = manualXML
        busy = true
        parseTask = Task {
            do {
                let parsed: ParsedFeed
                if manual {
                    parsed = try await Task.detached(priority: .userInitiated) { try FeedParser.parse(input, sourceURL: url) }.value
                    etag = nil; lastModified = nil
                } else {
                    guard case .modified(let fetched, let tag, let modified) = try await FeedClient().fetch(url: url) else {
                        throw HTTPError.invalidResponse
                    }
                    parsed = fetched; etag = tag; lastModified = modified
                }
                guard !Task.isCancelled else { return }
                busy = false
                if parsed.skippedEntries > 0 { result = parsed } else { commit(parsed) }
            } catch { if !Task.isCancelled { busy = false; self.error = error.localizedDescription } }
        }
    }
    private func commit(_ parsed: ParsedFeed) {
        do {
            let feed = try store.importFeed(parsed)
            if !manualXML { try store.recordFetch(feed, etag: etag, lastModified: lastModified, at: .now) }
            onImported(feed.id); dismiss()
        }
        catch { self.error = error.localizedDescription }
    }
}

private enum FeedExample: String, CaseIterable {
    case rss = "RSS 2.0", rdf = "RSS 1.0", atom = "Atom"
    var url: String {
        switch self { case .rss: "https://reader-demo.example/rss"; case .rdf: "https://reader-demo.example/rdf"; case .atom: "https://reader-demo.example/atom" }
    }
    var xml: String {
        switch self {
        case .rss:
            """
            <rss version="2.0"><channel><title>読書ラボ · RSS 2.0</title>
            <item><guid>demo-1</guid><title>XMLから、記事が届く。</title><link>https://reader-demo.example/posts/1</link>
            <pubDate>Wed, 09 Sep 2026 10:00:00 +0900</pubDate><description><![CDATA[<p>これは合成記事です。XMLを読み込み、購読を整理できるようになりました。</p><p>既読日時は再取り込みでも保持されます。同じURLの記事は別フィードから届いても共有します。</p>]]></description></item>
            </channel></rss>
            """
        case .rdf:
            """
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
            <channel rdf:about="https://reader-demo.example/rdf"><title>読書ラボ · RSS 1.0</title></channel>
            <item rdf:about="https://reader-demo.example/posts/1"><title>XMLから、記事が届く。</title><link>https://reader-demo.example/posts/1</link><dc:date>2026-09-09T10:00:00+09:00</dc:date><description>合成記事です。RSS 2.0サンプルと同じ記事を別の購読元から届け、重複処理を試します。</description></item>
            </rdf:RDF>
            """
        case .atom:
            """
            <feed xmlns="http://www.w3.org/2005/Atom" xml:base="https://reader-demo.example/">
            <title>読書ラボ · Atom</title><entry><id>tag:reader-demo.example,2026:2</id><title>購読を、自分の言葉で整理する。</title>
            <link rel="alternate" href="posts/2"/><updated>2026-09-09T11:00:00+09:00</updated><content type="html">&lt;p&gt;合成記事です。購読元を右クリックして、名前やフォルダを編集できます。&lt;/p&gt;</content></entry>
            </feed>
            """
        }
    }
}
