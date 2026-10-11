import Foundation
import Testing
@testable import ReaderCore

/// The add-subscription sheet checks the address while the person types (decision 0036).
@MainActor struct FeedCheckTests {
    // MARK: What is worth fetching

    @Test func onlyACompleteAddressIsChecked() {
        func request(_ source: String) -> FeedCheckRequest? { FeedCheckRequest.make(source: source, xml: "", manual: false) }
        #expect(request("https://example.com/feed.xml") == .url(URL(string: "https://example.com/feed.xml")!))
        #expect(request("  https://example.com/feed.xml \n") != nil)                  // pasted with spaces
        #expect(request("https://example.co.uk/feed") != nil && request("https://192.168.10.5/feed") != nil)
        for partial in ["", "h", "https://", "https://exa", "https://example", "https://example.c", "https://example.",
                        "https://foo.12", "https://192.16", "https://192.168.10", "https://192.168.10.",
                        "example.com/feed", "ftp://example.com/feed", "https://name:secret@example.com/feed"] {
            #expect(request(partial) == nil, "\(partial)")                           // nothing is sent to a host that does not look complete
        }
    }
    @Test func returnAcceptsAnyValidAddressSuchAsALocalName() {
        func request(_ source: String, asked: Bool) -> FeedCheckRequest? { FeedCheckRequest.make(source: source, xml: "", manual: false, asked: asked) }
        for local in ["https://localhost/feed", "https://nas/feed", "https://[::1]/feed"] {
            #expect(request(local, asked: false) == nil, "\(local)")                 // not while typing
            #expect(request(local, asked: true) != nil, "\(local)")                  // but the person pressed Return
        }
        #expect(request("https://name:secret@example.com/feed", asked: true) == nil)
    }
    @Test func manualXMLIsParsedLocallyAndNeedsAnAddressAndText() {
        #expect(FeedCheckRequest.make(source: "https://example.com/rss", xml: "<rss/>", manual: true) != nil)
        #expect(FeedCheckRequest.make(source: "https://example.com/rss", xml: "  ", manual: true) == nil)
        #expect(FeedCheckRequest.make(source: "https://exa", xml: "<rss/>", manual: true) == nil)
    }
    @Test func aHintIsGivenOnlyWhenTheTextCannotBecomeAnAddress() {
        #expect(FeedCheckRequest.hint(source: "") == nil)
        #expect(FeedCheckRequest.hint(source: "https://exa") == nil)
        #expect(FeedCheckRequest.hint(source: "example.com/feed") == "http:// か https:// で始まるURLを入れてください。")
        for typingTheScheme in ["h", "http", "https:", "https:/", "HTTPS://"] { #expect(FeedCheckRequest.hint(source: typingTheScheme) == nil, "\(typingTheScheme)") }
        #expect(FeedCheckRequest.hint(source: "ftp://example.com/feed") == "http:// か https:// で始まるURLを入れてください。")
    }
    @Test func returnOnAnAddressThatCannotBeUsedSaysWhy() {
        #expect(FeedCheckRequest.hint(source: "https://", asked: true) == "URLを最後まで入れてください。")
        #expect(FeedCheckRequest.hint(source: "https://name:secret@example.com/feed", asked: true) == FeedImportError.invalidURL.localizedDescription)
        #expect(FeedCheckRequest.hint(source: "ftp://example.com/feed", asked: true) == "http:// か https:// で始まるURLを入れてください。")
        #expect(FeedCheckRequest.hint(source: "", asked: true) == nil)
    }
    @Test func pastingChecksAtOnceAndTypingWaits() {
        #expect(FeedCheckRequest.delay(from: "https://example.com/fee", to: "https://example.com/feed") == .milliseconds(800))
        #expect(FeedCheckRequest.delay(from: "", to: "https://example.com/feed.xml") == .milliseconds(50))
        #expect(FeedCheckRequest.delay(from: "https://example.com/feed", to: "") == .milliseconds(800))
    }

    // MARK: The checker

    private nonisolated static func checked(_ title: String = "合成") -> CheckedFeed {
        let url = URL(string: "https://example.com/feed.xml")!
        return CheckedFeed(parsed: ParsedFeed(title: title, sourceURL: url, entries: [], skippedEntries: 0), etag: "v1", lastModified: nil, fetched: true)
    }
    private func settle(_ checker: FeedChecker) async {
        for _ in 0..<20 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(60))               // generous: the stubs answer at once, a loaded machine only needs to schedule
    }

    @Test func aReadableFeedBecomesReadyAfterTheDelay() async {
        let waits = Recorder<Duration>()
        let checker = FeedChecker(fetch: { _ in Self.checked("読書ラボ") }, sleep: { waits.add($0) })
        checker.update(source: "https://example.com/feed.xml", delay: .milliseconds(800))
        #expect(checker.state == .idle)                                              // nothing yet: the person may still be typing
        await settle(checker)
        guard case .ready(let feed) = checker.state else { Issue.record("expected ready, got \(checker.state)"); return }
        #expect(feed.parsed.title == "読書ラボ")
        #expect(waits.values == [.milliseconds(800)])
    }
    @Test func aHalfTypedAddressNeverReachesTheNetwork() async {
        let fetched = Recorder<FeedCheckRequest>()
        let checker = FeedChecker(fetch: { fetched.add($0); return Self.checked() }, sleep: { _ in })
        for partial in ["h", "https://exa", "https://example.c"] {
            checker.update(source: partial, delay: .zero); await settle(checker)
        }
        #expect(fetched.values.isEmpty)
    }
    @Test func aFailureIsShownInPlainWordsAndTheButtonStaysOff() async {
        let checker = FeedChecker(fetch: { _ in throw HTTPError.status(404) }, sleep: { _ in })
        checker.update(source: "https://example.com/missing", delay: .zero); await settle(checker)
        #expect(checker.state == .failed("ページが見つかりません（404）。URLを確認してください。"))
    }
    @Test func textWithoutASchemeGetsAHintAfterTheDelayAndEmptyTextIsQuiet() async {
        let checker = FeedChecker(fetch: { _ in Self.checked() }, sleep: { _ in })
        checker.update(source: "example.com/feed", delay: .zero); await settle(checker)
        #expect(checker.state == .failed("http:// か https:// で始まるURLを入れてください。"))
        checker.update(source: "", delay: .zero); await settle(checker)
        #expect(checker.state == .idle)
    }
    @Test func pressingReturnFetchesALocalNameThatTypingWouldNotSend() async {
        let fetched = Recorder<FeedCheckRequest>()
        let checker = FeedChecker(fetch: { fetched.add($0); return Self.checked() }, sleep: { _ in })
        checker.update(source: "https://localhost/feed", delay: .milliseconds(800)); await settle(checker)
        #expect(fetched.values.isEmpty)
        checker.update(source: "https://localhost/feed", delay: .zero, asked: true); await settle(checker)
        #expect(fetched.values == [.url(URL(string: "https://localhost/feed")!)])
    }
    @Test func anEditDuringTheWaitCancelsTheOldCheckBeforeItFetches() async {
        let gate = SlowGate()
        let fetched = Recorder<FeedCheckRequest>()
        let checker = FeedChecker(fetch: { fetched.add($0); return Self.checked() }, sleep: { _ in await gate.wait() })
        checker.update(source: "https://example.com/old", delay: .milliseconds(800)); await settle(checker)
        checker.update(source: "https://example.com/new", delay: .milliseconds(800)); await settle(checker)
        await gate.open(); await settle(checker)                                  // both waits end; only the newest may fetch
        #expect(fetched.values == [.url(URL(string: "https://example.com/new")!)])
    }
    @Test func theStateSaysWhatReturnAndAnAnswerShouldDo() {
        let feed = Self.checked()
        #expect(FeedChecker.State.ready(feed).onReturn == .add(feed))
        #expect(FeedChecker.State.checking.onReturn == .waitForAnswer)
        #expect(FeedChecker.State.idle.onReturn == .checkAgain && FeedChecker.State.failed("x").onReturn == .checkAgain)
        #expect(FeedChecker.State.ready(feed).whileWaitingForReturn == .add(feed))
        #expect(FeedChecker.State.failed("x").whileWaitingForReturn == .giveUp)
        #expect(FeedChecker.State.checking.whileWaitingForReturn == .keepWaiting && FeedChecker.State.idle.whileWaitingForReturn == .keepWaiting)
    }
    @Test func pressingReturnOnAnUnfinishedAddressSaysSo() async {
        let fetched = Recorder<FeedCheckRequest>()
        let checker = FeedChecker(fetch: { fetched.add($0); return Self.checked() }, sleep: { _ in })
        checker.update(source: "https://", delay: .zero, asked: true); await settle(checker)
        #expect(checker.state == .failed("URLを最後まで入れてください。"))
        checker.update(source: "", delay: .zero, asked: true); await settle(checker)
        #expect(checker.state == .idle && fetched.values.isEmpty)
    }
    @Test func cancelStopsTheCheckAndForgetsIt() async {
        let gate = SlowGate()
        let checker = FeedChecker(fetch: { _ in await gate.wait(); return Self.checked() }, sleep: { _ in })
        checker.update(source: "https://example.com/feed.xml", delay: .zero); await settle(checker)
        #expect(checker.state == .checking)
        checker.cancel(); await gate.open(); await settle(checker)
        #expect(checker.state == .idle)
    }
    @Test func anEditDropsTheOldResultAtOnce() async {
        let checker = FeedChecker(fetch: { _ in Self.checked() }, sleep: { _ in })
        checker.update(source: "https://example.com/feed.xml", delay: .zero); await settle(checker)
        guard case .ready = checker.state else { Issue.record("expected ready"); return }
        checker.update(source: "https://example.com/feed.xm", delay: .milliseconds(800))
        #expect(checker.state == .idle)                                              // the add button cannot use a result for another address
    }
    @Test func aSlowAnswerForAnOldAddressIsIgnored() async {
        let gate = SlowGate()
        let checker = FeedChecker(fetch: { request in
            guard case .url(let url) = request else { throw HTTPError.invalidResponse }
            if url.path == "/old" { await gate.wait() }
            return Self.checked(url.path)
        }, sleep: { _ in })
        checker.update(source: "https://example.com/old", delay: .zero); await settle(checker)
        #expect(checker.state == .checking)
        checker.update(source: "https://example.com/new", delay: .zero); await settle(checker)
        await gate.open(); await settle(checker)
        guard case .ready(let feed) = checker.state else { Issue.record("expected ready, got \(checker.state)"); return }
        #expect(feed.parsed.title == "/new")
    }
    @Test func checkingNowSkipsTheDelay() async {
        let waits = Recorder<Duration>()
        let checker = FeedChecker(fetch: { _ in Self.checked() }, sleep: { waits.add($0) })
        checker.update(source: "https://example.com/feed.xml", delay: .zero); await settle(checker)
        #expect(waits.values.isEmpty)
        guard case .ready = checker.state else { Issue.record("expected ready"); return }
    }

    // MARK: Words for each cause

    @Test func eachCauseHasItsOwnPlainSentence() {
        func text(_ error: any Error) -> String { FeedCheckMessage.text(for: error) }
        #expect(text(HTTPError.status(404)) == "ページが見つかりません（404）。URLを確認してください。")
        #expect(text(HTTPError.status(403)) == "このURLは読めません（403）。ログインが必要かもしれません。")
        #expect(text(HTTPError.status(503)) == "サーバーがエラーを返しました（503）。時間をおいて試してください。")
        #expect(text(HTTPError.status(418)) == "サーバーがエラーを返しました（418）。")
        #expect(text(URLError(.notConnectedToInternet)) == "ネットワークに接続できません。")
        #expect(text(URLError(.timedOut)) == "サーバーから応答がありません。")
        #expect(text(URLError(.cannotFindHost)) == "サーバーが見つかりません。URLを確認してください。")
        #expect(text(URLError(.serverCertificateUntrusted)) == "安全な接続ができませんでした。")
        #expect(text(URLError(.cannotConnectToHost)) == "接続できませんでした。")
        #expect(text(URLError(.appTransportSecurityRequiresSecureConnection)) == "http:// には接続できません。https:// のURLを入れてください。")
        #expect(text(HTTPError.tooLarge) == "データが大きすぎます（2MBまで）。")
        #expect(text(FeedImportError.htmlPage) == "フィードではなくWebページです。フィードのURLを入れてください。")
        #expect(text(FeedImportError.invalidXML) == "フィードのXMLに誤りがあり、読めませんでした。配信元の問題かもしれません。")
        #expect(FeedCheckMessage.text(for: FeedImportError.invalidXML, pastedXML: true) == "貼り付けたXMLに誤りがあり、読めませんでした。")
    }

    @Test func theDefaultFetchReadsTheRealResponse() async throws {
        let url = URL(string: "https://\(UUID().uuidString.lowercased()).example/rss")!
        let client = FeedClient(http: HTTPClient(protocolClasses: [StubURLProtocol.self]))
        StubURLProtocol.register(.init(headers: ["ETag": "v9"], data: Data(FeedParserTests.rss.utf8)), at: url)
        let feed = try await FeedChecker.fetch(.url(url), client: client)
        #expect(feed.parsed.title == "合成ニュース" && feed.etag == "v9" && feed.fetched)
        StubURLProtocol.register(.init(data: Data("<!doctype html><html><body>top page</body></html>".utf8)), at: url)
        await #expect(throws: FeedImportError.htmlPage) { try await FeedChecker.fetch(.url(url), client: client) }
        let manual = try await FeedChecker.fetch(.xml(Data(FeedParserTests.rss.utf8), url), client: client)
        #expect(!manual.fetched && manual.etag == nil)
    }
}

/// Collects values from `@Sendable` closures.
final class Recorder<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Value] = []
    func add(_ value: Value) { lock.withLock { items.append(value) } }
    var values: [Value] { lock.withLock { items } }
}

/// Holds one caller until the test opens it.
actor SlowGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false
    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() { isOpen = true; continuation?.resume(); continuation = nil }
}
