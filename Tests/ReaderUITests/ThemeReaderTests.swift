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
    private func settle(_ host: NSView, until ready: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if ready() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(ready(), "Synthetic reader did not reach the expected state")
    }
    private func containsText(_ text: String, in view: NSView) -> Bool {
        if let field = view as? NSTextView, field.string == text { return true }
        return view.subviews.contains { containsText(text, in: $0) }
    }
    private func buttons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? [] + view.subviews.flatMap { buttons(in: $0) }
    }
    /// The reader's top bar: the last two plain buttons in the tree are previous and next (the menu is a pop-up button; the sidebar
    /// button is earlier, in the middle column). SwiftUI gives these buttons no label or tool tip that AppKit can read.
    private func topBar(in view: NSView) -> (previous: NSButton, next: NSButton, menu: NSPopUpButton)? {
        let all = buttons(in: view)
        let plain = all.filter { !($0 is NSPopUpButton) }
        guard plain.count >= 2, let menu = all.compactMap({ $0 as? NSPopUpButton }).first else { return nil }
        return (plain[plain.count - 2], plain[plain.count - 1], menu)
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

    @Test func noteFaceShowsTheNoteInsteadOfTheArticleList() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .note) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveNote(themeID: theme.id, text: "既存のノート", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { containsText("既存のノート", in: h.host) }
        #expect(find(NativeArticleList.Table.self, in: h.host) == nil)
    }

    @Test func emptyThemeAndEmptyInboxListNoRows() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            _ = try store.createTheme(name: "空", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 0 }
        let inbox = try harness(scope: { _ in .unfiledStars }) { _ in }
        defer { finish(inbox) }
        try await settle(inbox.host) { find(NativeArticleList.Table.self, in: inbox.host)?.numberOfRows == 0 }
    }

    @Test func faceSwitchSitsBelowTheToolbarAndChangesBothColumns() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.addArticle(store.articles[0].id, toTheme: theme.id, at: .now)
            try store.saveNote(themeID: theme.id, text: "既存のノート", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 1 }
        let table = try #require(find(NativeArticleList.Table.self, in: h.host))
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let control = try #require(find(NSSegmentedControl.self, in: h.host))
        #expect(control.segmentCount == 2)
        let frame = control.convert(control.bounds, to: nil)
        #expect(frame.maxY <= h.window.contentLayoutRect.maxY + 0.5, "the switch must not sit under the titlebar or toolbar")
        control.selectedSegment = 1
        control.performClick(nil)
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host) == nil }
        try await settle(h.host) { containsText("既存のノート", in: h.host) }
        // The reader on the right keeps showing the article that was selected (decision 5 of the N2 plan).
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let back = try #require(find(NSSegmentedControl.self, in: h.host))
        back.selectedSegment = 0
        back.performClick(nil)
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 1 }
        // The theme's own reader (selection) comes back, not another scope's. Wait past the first remount
        // so a transient state cannot satisfy the check.
        try await Task.sleep(for: .milliseconds(300))
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.selectedRow == 0 }
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
    }

    private func noteFaceHarness() throws -> Harness {
        try harness(scope: { store in .theme(store.themes[0].id) }, face: .note) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            try store.saveNote(themeID: theme.id, text: "ノートの本文", at: .now)
        }
    }

    @Test func theTopBarMovesBetweenTheThemesArticlesFromTheNoteFace() async throws {
        let h = try noteFaceHarness()
        defer { finish(h) }
        try await settle(h.host) { containsText("ノートの本文", in: h.host) && topBar(in: h.host) != nil }
        let next = try #require(topBar(in: h.host)).next
        next.performClick(nil)                                   // nothing shown: next opens the first
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let previous = try #require(topBar(in: h.host)).previous
        try await settle(h.host) { !previous.isEnabled }              // at the first article
        next.performClick(nil)
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
        next.performClick(nil)
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 2") == true }
        try await settle(h.host) { !next.isEnabled }                  // at the last article
        #expect(containsText("ノートの本文", in: h.host))                            // the note stayed
    }

    @Test func theArticleChosenOnTheNoteFaceIsTheOneTheArticlesFaceShows() async throws {
        let h = try noteFaceHarness()
        defer { finish(h) }
        try await settle(h.host) { topBar(in: h.host) != nil }
        let next = try #require(topBar(in: h.host)).next
        next.performClick(nil); try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        next.performClick(nil); try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
        let control = try #require(find(NSSegmentedControl.self, in: h.host))
        control.selectedSegment = 0
        control.performClick(nil)
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.selectedRow == 1 }
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
    }

    @Test func aShownArticleThatLeftTheThemeDoesNotBreakTheTopBar() async throws {
        let h = try noteFaceHarness()
        defer { finish(h) }
        try await settle(h.host) { topBar(in: h.host) != nil }
        let next = try #require(topBar(in: h.host)).next
        next.performClick(nil)
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let themeID = h.store.themes[0].id
        try h.store.removeArticle(h.store.articles[0].id, fromTheme: themeID, at: .now)
        for _ in 0..<10 { h.host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }   // let the update land
        #expect(find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true)   // still shown
        #expect(topBar(in: h.host) != nil)
        next.performClick(nil)
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
    }

    private func noteTextView(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView, text.isEditable { return text }
        return view.subviews.lazy.compactMap { noteTextView(in: $0) }.first
    }

    @Test func theNotesSelectionComesBackAfterAFaceRoundTrip() async throws {
        let h = try noteFaceHarness()
        defer { finish(h) }
        h.window.makeKeyAndOrderFront(nil)
        try await settle(h.host) { noteTextView(in: h.host) != nil }
        let text = try #require(noteTextView(in: h.host))
        h.window.makeFirstResponder(text)
        text.setSelectedRange(NSRange(location: 2, length: 3))
        for _ in 0..<10 { h.host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
        let control = try #require(find(NSSegmentedControl.self, in: h.host))
        control.selectedSegment = 0; control.performClick(nil)
        try await settle(h.host) { noteTextView(in: h.host) == nil && find(NativeArticleList.Table.self, in: h.host) != nil }
        let back = try #require(find(NSSegmentedControl.self, in: h.host))
        back.selectedSegment = 1; back.performClick(nil)
        try await settle(h.host) { noteTextView(in: h.host) != nil }
        let restored = try #require(noteTextView(in: h.host))
        h.window.makeFirstResponder(restored)
        try await settle(h.host) { restored.selectedRange() == NSRange(location: 2, length: 3) }
    }
}
