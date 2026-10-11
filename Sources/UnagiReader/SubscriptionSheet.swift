import SwiftUI
import AppKit
import ReaderCore

/// Where a new subscription goes: the folder of the row whose + was pressed (empty means unfiled).
struct SubscriptionTarget: Identifiable {
    let folder: String
    var id: String { folder }
}

struct SubscriptionSheet: View {
    let store: ReaderStore
    var feed: Feed?
    /// The folder a new subscription is added to. There is no folder field: the place where + was pressed decides it.
    var folder = ""
    let onImported: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var xml = ""
    @State private var manualXML = false
    /// The XML input is for trouble-shooting: it is offered only when the sheet was opened with the Option key held.
    @State private var xmlOffered = SubscriptionSheet.offersXMLInput(modifiers: NSEvent.modifierFlags)
    @State private var title = ""
    @State private var error: String?
    /// The address is checked while the person types; Add needs a feed that was read (decision 0036).
    @State private var checker = FeedChecker()
    /// Return was pressed before the check ended: add as soon as it succeeds.
    @State private var addWhenReady = false
    /// Set once the feed is saved, so a second Return (field and default button) cannot add it twice.
    @State private var added = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(feed == nil ? SubscriptionSheet.heading(folder: folder) : "購読名を編集").font(.title3.bold())
            if let feed {
                TextField("購読名", text: $title.singleLine())
                if let url = feed.sourceURL { Text(url).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            } else {
                TextField("https://example.com/feed.xml", text: $source.singleLine(address: true))
                    .accessibilityLabel("フィードのURL").onSubmit(submit)
                if xmlOffered { Toggle("XMLを直接入力", isOn: $manualXML).font(.caption) }
                if manualXML {
                    TextEditor(text: $xml).font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 240).border(.quaternary)
                        .accessibilityLabel("フィードXML")
                    HStack {
                        Menu("合成サンプルを入力") {
                            ForEach(FeedExample.allCases, id: \.self) { example in
                                Button(example.rawValue) { source = example.url; xml = example.xml }
                            }
                        }
                        Spacer()
                        Text("RSS 1.0 / RSS 2.0 / Atom · 2MBまで").font(.caption).foregroundStyle(.secondary)
                    }
                }
                status
            }
            if let error { Text(error).foregroundStyle(.red).font(.callout).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(feed == nil ? "追加" : "保存", action: submit)
                    .keyboardShortcut(.defaultAction).disabled(feed == nil && addableFeed == nil)
            }
        }
        .padding(20).frame(width: 440)
        .onAppear { title = feed?.title ?? "" }
        .onChange(of: source) { old, new in recheck(delay: FeedCheckRequest.delay(from: old, to: new)) }
        .onChange(of: xml) { _, _ in recheck(delay: .milliseconds(300)) }
        .onChange(of: manualXML) { _, _ in recheck(delay: .zero) }
        .onChange(of: checker.state) { _, state in
            guard addWhenReady else { return }
            switch state.whileWaitingForReturn {
            case .add(let checked): addWhenReady = false; commit(checked)
            case .giveUp: addWhenReady = false
            case .keepWaiting: break
            }
        }
        .onDisappear { checker.cancel() }
    }

    /// One line under the field that always keeps its place, so the sheet does not jump while it checks.
    private var status: some View {
        Group {
            switch checker.state {
            case .idle: Color.clear
            case .checking:
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("確認中…") }.foregroundStyle(.secondary)
            case .ready(let checked):
                VStack(alignment: .leading, spacing: 2) {
                    if isSubscribed(checked) {
                        Label { Text("すでに購読しています：\(checked.parsed.title)").lineLimit(1) } icon: { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                    } else {
                        Label { Text(checked.parsed.title).lineLimit(1) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    }
                    if checked.parsed.skippedEntries > 0 {
                        Text("識別子も記事URLもない\(checked.parsed.skippedEntries)件は取り込めません。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            case .failed(let message): Text(message).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .font(.callout).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The feed that Add would save: one that was read and is not subscribed yet (adding it again would only move it).
    private var addableFeed: CheckedFeed? {
        if case .ready(let checked) = checker.state, !isSubscribed(checked) { checked } else { nil }
    }

    private func isSubscribed(_ checked: CheckedFeed) -> Bool { store.isSubscribed(to: checked.parsed.sourceURL) }

    static func heading(folder: String) -> String { folder.isEmpty ? "購読を追加" : "「\(folder)」に購読を追加" }

    /// Whether the XML input is offered: only with the Option key (a trouble-shooting tool, not part of everyday adding).
    static func offersXMLInput(modifiers: NSEvent.ModifierFlags) -> Bool { modifiers.contains(.option) }

    private func recheck(delay: Duration, asked: Bool = false) {
        error = nil; addWhenReady = false
        checker.update(source: source, xml: xml, manual: manualXML, delay: delay, asked: asked)
    }

    private func submit() {
        error = nil
        if let feed {
            do { try store.updateSubscription(feed, title: title, folder: feed.folder); dismiss() }
            catch { self.error = error.localizedDescription }
            return
        }
        switch checker.state.onReturn {
        case .add(let checked): commit(checked)
        case .waitForAnswer: addWhenReady = true                  // Return before the answer: add when it comes
        case .checkAgain:
            recheck(delay: .zero, asked: true)
            addWhenReady = true
        }
    }

    private func commit(_ checked: CheckedFeed) {
        // Already subscribed: the status line says so, and there is nothing to add.
        guard !added, !isSubscribed(checked) else { return }
        do {
            let feed = try store.importFeed(checked.parsed, folder: folder)
            if checked.fetched { try store.recordFetch(feed, etag: checked.etag, lastModified: checked.lastModified, at: .now) }
            added = true
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
