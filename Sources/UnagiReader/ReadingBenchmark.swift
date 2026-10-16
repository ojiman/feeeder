import AppKit
import ReaderCore

/// Opt-in replay for issue #164. Only a marked, temporary BenchmarkFixtureTests library may be changed.
@MainActor enum ReadingBenchmark {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("--reading-benchmark") }
    private(set) static var completed = false
    private(set) static var failure: String?

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func validateFixture(at directory: URL, explicit: Bool) throws {
        let target = directory.resolvingSymlinksInPath().standardizedFileURL.path
        let library = URL.applicationSupportDirectory.appending(path: "UnagiReader").resolvingSymlinksInPath().path
        guard explicit, target.caseInsensitiveCompare(library) != .orderedSame,
              !target.lowercased().hasPrefix(library.lowercased() + "/"),
              (try? String(contentsOf: directory.appending(path: ".reading-benchmark"), encoding: .utf8)) == "BenchmarkFixtureTests\n" else {
            throw Failure(message: "The reading benchmark needs an explicit, marked synthetic fixture directory.")
        }
    }

    struct SyntheticHTTP: HTTPFetching {
        func fetch(url: URL, headers: [String: String], maximumBytes: Int) async throws -> HTTPResponse {
            guard url.scheme == "https", url.host == "synthetic.example", url.user == nil, url.password == nil, url.port == nil,
                  url.deletingLastPathComponent().path == "/feeds", let feed = Int(url.lastPathComponent), (0..<100).contains(feed) else {
                throw HTTPError.invalidURL
            }
            let body = (1...80).map { "合成段落 \($0)。更新計測のための本文です。これは現実の記事ではありません。" }.joined(separator: "\n\n")
            let entries = stride(from: feed, to: 10_000, by: 100).map { index in
                "<item><guid>\(index)</guid><title>合成記事 \(index)</title><description>負荷試験のための合成要約です。</description><content:encoded><![CDATA[\(body)]]></content:encoded></item>"
            }.joined()
            let data = Data("<rss version=\"2.0\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"><channel><title>合成購読 \(feed)</title>\(entries)</channel></rss>".utf8)
            guard data.count <= maximumBytes else { throw HTTPError.tooLarge }
            return HTTPResponse(data: data, finalURL: url, statusCode: 200, headers: [:])
        }
    }

    static func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let result = view as? T { return result }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }

    private static func wait(until ready: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(120)
        while !ready() {
            guard ContinuousClock.now < deadline else { throw Failure(message: "The reading benchmark timed out.") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func key(_ text: String, code: UInt16, in window: NSWindow) throws {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code) else {
            throw Failure(message: "Could not create a benchmark key event.")
        }
        NSApp.postEvent(event, atStart: false)
    }

    static func run(store: ReaderStore, refresh: FeedRefreshController) async {
        do {
            guard ReaderPerformance.output != nil, store.feeds.count == 100, store.articles.count == 10_000,
                  store.feeds.allSatisfy({ $0.sourceURL?.hasPrefix("https://synthetic.example/feeds/") == true }) else {
                throw Failure(message: "Expected --performance-output and the 100-feed, 10,000-article synthetic fixture.")
            }
            try await Task.sleep(for: .seconds(1))
            try await wait { !refresh.refreshing }
            guard refresh.errors.isEmpty, let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
                  let content = window.contentView, let table = find(NativeArticleList.Table.self, in: content) else {
                throw Failure(message: "The synthetic reader window or initial refresh was not ready.")
            }
            NSApp.activate(); window.makeKeyAndOrderFront(nil)
            ReaderPerformance.columnWidths["reading"] = MotionBenchmark.columnWidths(in: content)
            ReaderPerformance.beginPhase("reading")
            let initial = ReaderPerformance.selectionCount
            // The first j selects row zero; leave one row before the start so every k changes the selection.
            for (index, letter) in (Array(repeating: "j", count: 51) + Array(repeating: "k", count: 49)).enumerated() {
                window.makeFirstResponder(table)
                try key(letter, code: letter == "j" ? 38 : 40, in: window)
                try await wait { ReaderPerformance.selectionCount == initial + index + 1 }
                try await Task.sleep(for: .milliseconds(300))
            }
            ReaderPerformance.beginPhase(nil)
            try key("n", code: 45, in: window)
            try await wait { find(NoteTextView.self, in: content) != nil }
            try await Task.sleep(for: .seconds(1))
            guard let note = find(NoteTextView.self, in: content) else { throw Failure(message: "The note did not open.") }
            ReaderPerformance.columnWidths["noteOpen"] = MotionBenchmark.columnWidths(in: content)
            window.makeFirstResponder(note)
            let original = note.string
            note.setSelectedRange(NSRange(location: (original as NSString).length, length: 0))
            ReaderPerformance.beginPhase("typing")
            let typed = String(repeating: "Synthetic note. ", count: 4)
            for character in typed {
                note.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
                try await Task.sleep(for: .milliseconds(50))
            }
            guard store.note?.text == original + typed else { throw Failure(message: "Synthetic typing was not saved exactly.") }
            ReaderPerformance.beginPhase(nil)
            ReaderPerformance.beginPhase("refresh")
            let started = Date.now
            await refresh.refresh()
            guard refresh.errors.isEmpty, store.feeds.allSatisfy({ ($0.lastFetchedAt ?? .distantPast) >= started }),
                  store.articles.count == 10_000 else { throw Failure(message: "The synthetic refresh did not finish every feed.") }
            ReaderPerformance.beginPhase(nil)
            completed = true
        } catch {
            ReaderPerformance.beginPhase(nil)
            failure = error.localizedDescription
            NSLog("Unagi Reader reading benchmark failed: %@", error.localizedDescription)
        }
        ReaderPerformance.write()
        NSApp.terminate(nil)
    }
}
