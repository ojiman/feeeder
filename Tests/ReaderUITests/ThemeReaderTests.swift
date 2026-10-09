import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct ThemeReaderTests {
    private struct NoLauncher: ClaudeLaunching {
        func open(_ url: URL) async throws { throw HandoffError.launchFailed }
    }
    private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let result = view as? T { return result }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }
    private func settle(_ host: NSView, until ready: () -> Bool) async throws {
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if ready() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(ready(), "Synthetic reader did not reach the expected state")
    }
    private struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    private func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, face: ThemeFace = .articles,
                         prepare: (ReaderStore) throws -> Void) throws -> Harness {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let entries = (0..<4).map { index in
            ParsedEntry(sourceID: "synthetic-\(index)", title: "合成記事 \(index)", url: URL(string: "http://127.0.0.1:1/article/\(index)"), summary: "合成要約", body: "合成本文", coverage: .feedProvided, publishedAt: .now.addingTimeInterval(Double(-index)))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "http://127.0.0.1:1/feed")!, entries: entries, skippedEntries: 0), receivedAt: .now)
        try prepare(store)
        let review = AIPackageReview(store: store)
        let reader = ReaderView(store: store, refresh: FeedRefreshController(store: store), aiReview: review,
            handoff: ClaudeHandoffController(directory: directory.appendingPathComponent("Handoff"), review: review, launcher: NoLauncher()),
            imageLoader: ReaderImageLoader(directory: directory.appendingPathComponent("Images")),
            initialScope: try scope(store), initialThemeFace: face)
        let host = NSHostingView(rootView: reader)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-theme-reader")
        window.contentView = host
        return Harness(store: store, host: host, window: window, directory: directory)
    }
    private func finish(_ harness: Harness) {
        harness.window.close(); try? FileManager.default.removeItem(at: harness.directory)
    }

    @Test func unfiledStarsListsOnlyStarredArticlesInNoTheme() async throws {
        let h = try harness(scope: { _ in .unfiledStars }) { store in
            let ids = store.articles.map(\.id)
            for id in ids.prefix(3) { try store.setStar(articleID: id, isStarred: true, at: .now) }
            _ = try store.createTheme(name: "A", adding: ids[0], at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 2 }
    }

    @Test func themeArticlesFaceListsOnlyTheThemesArticles() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for id in store.articles.map(\.id).prefix(3) { try store.addArticle(id, toTheme: theme.id, at: .now) }
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 }
    }

    @Test func questionsFaceShowsTheUnderstandingEditorInsteadOfTheArticleList() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) {
            var found = false
            func visit(_ view: NSView) {
                if let text = view as? NSTextView, text.string == "既存のいまの理解" { found = true }
                view.subviews.forEach(visit)
            }
            visit(h.host)
            return found
        }
        #expect(find(NativeArticleList.Table.self, in: h.host) == nil)
    }

    @Test func emptyThemeAndEmptyInboxShowGuidanceWithoutRows() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            _ = try store.createTheme(name: "空", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 0 }
        let inbox = try harness(scope: { _ in .unfiledStars }) { _ in }
        defer { finish(inbox) }
        try await settle(inbox.host) { find(NativeArticleList.Table.self, in: inbox.host)?.numberOfRows == 0 }
    }
}
