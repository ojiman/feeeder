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
    private struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    private func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, face: ThemeFace = .articles,
                         questionSelection: (ReaderStore) -> ThemeQuestionSelection = { _ in .understanding },
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
            initialScope: try scope(store), initialThemeFace: face, initialQuestionSelection: questionSelection(store))
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
        try await settle(h.host) { containsText("既存のいまの理解", in: h.host) }
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
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
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
        try await settle(h.host) { containsText("既存のいまの理解", in: h.host) }
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

    @Test func questionFaceShowsTheSelectedQuestionsAnswer() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions,
                            questionSelection: { store in .question(store.themeQuestions[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
            let question = try store.addQuestion(themeID: theme.id, lens: .assumption, at: .now)
            try store.saveAnswer(questionID: question.id, answer: "保存済みの自分の答え", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { containsText("保存済みの自分の答え", in: h.host) }
        #expect(!containsText("既存のいまの理解", in: h.host))
    }

    @Test func aMissingQuestionSelectionFallsBackToTheUnderstanding() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions,
                            questionSelection: { _ in .question(UUID()) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { containsText("既存のいまの理解", in: h.host) }
    }
}

/// Hosts the editor behind a switch so a test can remove it the way a face switch or a lens choice does.
@MainActor private final class EditorSwitch: ObservableObject { @Published var shown = true }
private struct EditorSwitchHost: View {
    let store: ReaderStore
    let themeID: UUID
    let questionID: UUID
    @ObservedObject var toggle: EditorSwitch
    var body: some View {
        if toggle.shown { QuestionEditor(store: store, themeID: themeID, questionID: questionID, onOpenArticle: { _ in }) }
        else { Text("removed") }
    }
}

@Suite(.serialized) @MainActor struct QuestionEditorTests {
    private func textFields(in view: NSView) -> [NSTextField] {
        (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap { textFields(in: $0) }
    }
    @Test func aQuestionTextEditIsSavedWhenTheEditorIsRemovedWhileStillFocused() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let theme = try store.createTheme(name: "A", at: .now)
        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "元の問い", at: .now)
        let toggle = EditorSwitch()
        let host = NSHostingView(rootView: EditorSwitchHost(store: store, themeID: theme.id, questionID: question.id, toggle: toggle))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        var field: NSTextField?
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            field = textFields(in: host).first { $0.stringValue == "元の問い" }
            if field != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let textField = try #require(field)
        #expect(window.makeFirstResponder(textField))
        let editor = try #require(window.fieldEditor(false, for: textField) as? NSTextView)
        editor.insertText("編集した問い", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await Task.sleep(for: .milliseconds(100))
        toggle.shown = false
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if store.themeQuestions.first?.text == "編集した問い" { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(store.themeQuestions.first?.text == "編集した問い")
    }
}
