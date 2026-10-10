import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct ThemeReaderTests {
    fileprivate struct NoLauncher: ClaudeLaunching {
        func open(_ url: URL) async throws { throw HandoffError.launchFailed }
    }
    fileprivate func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let result = view as? T { return result }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }
    fileprivate func settle(_ host: NSView, until ready: @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if ready() { return }
            pumpRunLoop(0.02)                                              // pump the run loop here instead of suspending
        }
        #expect(ready(), "Synthetic reader did not reach the expected state")
    }
    fileprivate func containsText(_ text: String, in view: NSView) -> Bool {
        if let field = view as? NSTextView, field.string == text { return true }
        return view.subviews.contains { containsText(text, in: $0) }
    }
    fileprivate func buttons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? [] + view.subviews.flatMap { buttons(in: $0) }
    }
    /// The reader's top bar: the last two plain buttons in the tree are previous and next (the menu is a pop-up button; the sidebar
    /// button is earlier, in the middle column). SwiftUI gives these buttons no label or tool tip that AppKit can read.
    fileprivate func topBar(in view: NSView) -> (previous: NSButton, next: NSButton, menu: NSPopUpButton)? {
        let all = buttons(in: view)
        guard let index = all.firstIndex(where: { $0 is NSPopUpButton }), index >= 2, let menu = all[index] as? NSPopUpButton else { return nil }
        return (all[index - 2], all[index - 1], menu)         // previous and next come right before the menu in the tree
    }
    fileprivate struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    fileprivate func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, face: ThemeFace = .articles,
                         summaries: ((ReaderStore) -> ArticleSummaryModel)? = nil,
                         noteActions: ((ReaderStore) -> NoteActionModel)? = nil,
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
            initialScope: try scope(store), initialThemeFace: face, summaries: summaries?(store), noteActions: noteActions?(store))
        let host = NSHostingView(rootView: reader)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-theme-reader")
        window.contentView = host
        return Harness(store: store, host: host, window: window, directory: directory)
    }
    fileprivate func finish(_ harness: Harness) {
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
        pumpRunLoop(0.3)
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.selectedRow == 0 }
        try await settle(h.host) { find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
    }
}

/// The note face of a theme (N3). A suite of its own: see docs/verification/2026-10-10-theme-two-panes.md for why.
@Suite(.serialized) @MainActor struct NoteFaceTests {
    private let t = ThemeReaderTests()

    fileprivate func noteFaceHarness() throws -> ThemeReaderTests.Harness {
        try t.harness(scope: { store in .theme(store.themes[0].id) }, face: .note) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            try store.saveNote(themeID: theme.id, text: "ノートの本文", at: .now)
        }
    }

    @Test func theTopBarMovesBetweenTheThemesArticlesFromTheNoteFace() async throws {
        let h = try noteFaceHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.containsText("ノートの本文", in: h.host) && t.topBar(in: h.host) != nil }
        let next = try #require(t.topBar(in: h.host)).next
        next.performClick(nil)                                   // nothing shown: next opens the first
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let previous = try #require(t.topBar(in: h.host)).previous
        try await t.settle(h.host) { !previous.isEnabled }              // at the first article
        next.performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
        next.performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 2") == true }
        try await t.settle(h.host) { !next.isEnabled }                  // at the last article
        #expect(t.containsText("ノートの本文", in: h.host))                            // the note stayed
    }

    @Test func theArticleChosenOnTheNoteFaceIsTheOneTheArticlesFaceShows() async throws {
        let h = try noteFaceHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.topBar(in: h.host) != nil }
        let next = try #require(t.topBar(in: h.host)).next
        next.performClick(nil); try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        next.performClick(nil); try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
        let control = try #require(t.find(NSSegmentedControl.self, in: h.host))
        control.selectedSegment = 0
        control.performClick(nil)
        try await t.settle(h.host) { t.find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 }
        try await t.settle(h.host) { t.find(NativeArticleList.Table.self, in: h.host)?.selectedRow == 1 }
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
    }

    @Test func aShownArticleThatLeftTheThemeDoesNotBreakTheTopBar() async throws {
        let h = try noteFaceHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.topBar(in: h.host) != nil }
        let next = try #require(t.topBar(in: h.host)).next
        next.performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let themeID = h.store.themes[0].id
        try h.store.removeArticle(h.store.articles[0].id, fromTheme: themeID, at: .now)
        for _ in 0..<10 { h.host.layoutSubtreeIfNeeded(); pumpRunLoop(0.02) }   // let the update land
        #expect(t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true)   // still shown
        #expect(t.topBar(in: h.host) != nil)
        next.performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
    }

    fileprivate func noteTextView(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView, text.isEditable { return text }
        return view.subviews.lazy.compactMap { noteTextView(in: $0) }.first
    }

    @Test func theNotesSelectionComesBackAfterAFaceRoundTrip() async throws {
        let h = try noteFaceHarness()
        defer { t.finish(h) }
        h.window.makeKeyAndOrderFront(nil)
        try await t.settle(h.host) { noteTextView(in: h.host) != nil }
        let text = try #require(noteTextView(in: h.host))
        h.window.makeFirstResponder(text)
        text.setSelectedRange(NSRange(location: 2, length: 3))
        for _ in 0..<10 { h.host.layoutSubtreeIfNeeded(); pumpRunLoop(0.02) }
        let control = try #require(t.find(NSSegmentedControl.self, in: h.host))
        control.selectedSegment = 0; control.performClick(nil)
        try await t.settle(h.host) { noteTextView(in: h.host) == nil && t.find(NativeArticleList.Table.self, in: h.host) != nil }
        let back = try #require(t.find(NSSegmentedControl.self, in: h.host))
        back.selectedSegment = 1; back.performClick(nil)
        try await t.settle(h.host) { noteTextView(in: h.host) != nil }
        let restored = try #require(noteTextView(in: h.host))
        h.window.makeFirstResponder(restored)
        try await t.settle(h.host) { restored.selectedRange() == NSRange(location: 2, length: 3) }
    }
}

@MainActor func pumpRunLoop(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

@MainActor private final class EnabledSwitch { var on = true }

/// A stand-in for the on-device model: answers with a fixed text, or fails.
private struct StubAssistant: ThemeAssistant {
    var answer: String? = "これは要約です。"
    func availability() async -> AssistantAvailability { .available }
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch] { [] }
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]] { [] }
    func generationAvailability() async -> AssistantAvailability { .available }
    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        guard let answer else { throw CocoaError(.fileReadUnknown) }
        return answer
    }
}

/// The AI summary next to the note (N4). A suite of its own; run each test alone (see the N3 verification record).
@Suite(.serialized) @MainActor struct AISummaryTests {
    private let t = ThemeReaderTests()

    private func make(answer: String? = "これは要約です。", enabled: EnabledSwitch = EnabledSwitch()) throws -> (ThemeReaderTests.Harness, ArticleSummaryModel) {
        var model: ArticleSummaryModel?
        let h = try t.harness(scope: { store in .theme(store.themes[0].id) }, face: .note, summaries: { store in
            let made = ArticleSummaryModel(store: store, assistant: StubAssistant(answer: answer), isEnabled: { enabled.on })
            model = made; return made
        }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            try store.saveNote(themeID: theme.id, text: "前の文章", at: .now)
        }
        return (h, try #require(model))
    }
    private func segmented(labelled first: String, in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl, control.segmentCount == 2, control.label(forSegment: 0) == first { return control }
        return view.subviews.lazy.compactMap { segmented(labelled: first, in: $0) }.first
    }
    /// The 「原文を見る」 link is the only AppKit button in the card. The card's other buttons are drawn by SwiftUI itself and
    /// cannot be pressed from a test, so asking for a summary and adopting it are tested below this level (model, insertion).
    private func showOriginalLink(in view: NSView) -> NSButton? {
        let all = t.buttons(in: view)
        guard let menu = all.firstIndex(where: { $0 is NSPopUpButton }) else { return nil }
        return all[(menu + 1)...].first
    }
    private func openFirstArticleAndSummary(_ h: ThemeReaderTests.Harness) async throws {
        try await t.settle(h.host) { t.topBar(in: h.host) != nil && segmented(labelled: "原文", in: h.host) != nil }
        t.topBar(in: h.host)?.next.performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        let switcher = try #require(segmented(labelled: "原文", in: h.host))
        switcher.selectedSegment = 1; switcher.performClick(nil)
    }

    @Test func theSwitchIsHiddenWhenOnDeviceAIIsOff() async throws {
        let defaults = UserDefaults.standard
        let before = defaults.object(forKey: OnDeviceAISetting.key)
        defaults.set(false, forKey: OnDeviceAISetting.key)
        defer { if let before { defaults.set(before, forKey: OnDeviceAISetting.key) } else { defaults.removeObject(forKey: OnDeviceAISetting.key) } }
        let (h, _) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.topBar(in: h.host) != nil }
        #expect(segmented(labelled: "原文", in: h.host) == nil)
    }

    @Test func openingTheSummaryAsksForNothingAndTheLinkGoesBackToTheArticle() async throws {
        let enabled = EnabledSwitch()
        let (h, model) = try make(enabled: enabled)
        defer { t.finish(h) }
        try await openFirstArticleAndSummary(h)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host) == nil && showOriginalLink(in: h.host) != nil }   // the card replaced the article
        #expect(model.state == .idle)                                                  // opening the summary asks for nothing
        let theme = h.store.themes[0]
        #expect(theme.note == "前の文章")                                               // and writes nothing
        // Leave the model in a state that is not `.idle` (the setting is off, so it answers at once without a call).
        enabled.on = false
        model.request(articleID: h.store.articles[0].id, themeID: theme.id)
        #expect(model.state == .unavailable(.disabled))
        try #require(showOriginalLink(in: h.host)).performClick(nil)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
        #expect(segmented(labelled: "原文", in: h.host)?.selectedSegment == 0)
        #expect(model.state == .idle)                                                  // going back to the article cleared it
    }

    @Test func movingToAnotherArticleKeepsTheSwitchAndClearsTheModel() async throws {
        let enabled = EnabledSwitch()
        let (h, model) = try make(enabled: enabled)
        defer { t.finish(h) }
        try await openFirstArticleAndSummary(h)
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host) == nil }
        enabled.on = false
        model.request(articleID: h.store.articles[0].id, themeID: h.store.themes[0].id)
        #expect(model.state == .unavailable(.disabled))                                // not idle before the move
        t.topBar(in: h.host)?.next.performClick(nil)                                    // another article
        try await t.settle(h.host) { t.topBar(in: h.host)?.menu.title == "合成記事 1" }
        #expect(segmented(labelled: "原文", in: h.host)?.selectedSegment == 1)         // the switch stays on 「AI要約」
        #expect(t.find(ArticleTextView.self, in: h.host) == nil && model.state == .idle)
    }

    @Test func theSwitchIsShownWhenOnDeviceAIIsOn() async throws {
        let (h, _) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.topBar(in: h.host) != nil }
        #expect(segmented(labelled: "原文", in: h.host) != nil)
    }
}

/// The two note actions below the note (N5). A suite of its own; run each test alone (see the N4 verification record).
@Suite(.serialized) @MainActor struct NoteActionTests {
    private let t = ThemeReaderTests()
    private static let note = "# 見出し\n元の文章です。分からない。\n\n# 次\n別の節。"

    private func make(answer: String? = "読みやすい文章です。", enabled: EnabledSwitch = EnabledSwitch(), note: String = NoteActionTests.note) throws -> (ThemeReaderTests.Harness, NoteActionModel) {
        var model: NoteActionModel?
        let h = try t.harness(scope: { store in .theme(store.themes[0].id) }, face: .note, noteActions: { _ in
            let made = NoteActionModel(assistant: StubAssistant(answer: answer), isEnabled: { enabled.on })
            model = made; return made
        }) { store in
            let theme = try store.createTheme(name: "A", goal: "金利を学ぶ", at: .now)
            try store.saveNote(themeID: theme.id, text: note, at: .now)
        }
        return (h, try #require(model))
    }
    private func noteView(_ h: ThemeReaderTests.Harness) -> NSTextView? {
        func find(_ v: NSView) -> NSTextView? { if let tv = v as? NSTextView, tv.isEditable, !tv.isFieldEditor { return tv }; return v.subviews.lazy.compactMap(find).first }
        return find(h.host)
    }
    /// The bottom row of AppKit buttons is the action bar; the row above it is the card. Found by position, left to right.
    private func bottomRow(_ h: ThemeReaderTests.Harness, above: CGFloat = 0, upTo: CGFloat = 30) -> [NSButton] {
        t.buttons(in: h.host).filter { !($0 is NSPopUpButton) }
            .map { ($0, $0.convert($0.bounds, to: nil)) }
            .filter { $0.1.minY >= above && $0.1.minY < upTo && $0.1.width > 0 }
            .sorted { $0.1.minX < $1.1.minX }.map(\.0)
    }
    private func placeCursor(_ h: ThemeReaderTests.Harness, in marker: String) throws {
        h.window.makeKeyAndOrderFront(nil)
        try #require(noteView(h)).window?.makeFirstResponder(noteView(h))
        let range = (Self.note as NSString).range(of: marker)
        noteView(h)?.setSelectedRange(NSRange(location: range.location + 1, length: 0))
    }
    private func waitForCard(_ model: NoteActionModel, _ h: ThemeReaderTests.Harness) async {
        for _ in 0..<200 {
            if case .ready = model.state { return }
            h.host.layoutSubtreeIfNeeded()
            await Task.yield()
            pumpRunLoop(0.01)
        }
    }

    @Test func theBarIsShownWhenAIIsOnAndHiddenWhenItIsOff() async throws {
        let (h, _) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { bottomRow(h).count == 2 }
        let defaults = UserDefaults.standard
        let before = defaults.object(forKey: OnDeviceAISetting.key)
        defaults.set(false, forKey: OnDeviceAISetting.key)
        defer { if let before { defaults.set(before, forKey: OnDeviceAISetting.key) } else { defaults.removeObject(forKey: OnDeviceAISetting.key) } }
        let (off, _) = try make()
        defer { t.finish(off) }
        try await t.settle(off.host) { noteView(off) != nil }
        pumpRunLoop(0.2)
        #expect(bottomRow(off).isEmpty)
    }

    @Test func aRewriteReplacesOnlyTheSectionsTextAndUndoBringsItBack() async throws {
        let (h, model) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { bottomRow(h).count == 2 && noteView(h) != nil }
        try placeCursor(h, in: "元の文章")
        try #require(bottomRow(h).first).performClick(nil)                               // わかりやすく
        await waitForCard(model, h)
        guard case .ready(let card) = model.state else { Issue.record("no card: \(model.state)"); return }
        #expect(card.answer == "読みやすい文章です。" && card.target.text == "元の文章です。分からない。")
        try await t.settle(h.host) { bottomRow(h, above: 30, upTo: 400).count == 3 }      // 採用 / 別の案 / 閉じる
        let theme = h.store.themes[0]
        #expect(theme.note == Self.note)                                                  // nothing written yet
        try #require(bottomRow(h, above: 30, upTo: 400).first).performClick(nil)         // 採用
        let adopted = "# 見出し\n読みやすい文章です。\n\n# 次\n別の節。"
        try await t.settle(h.host) { theme.note == adopted && noteView(h)?.string == adopted }
        #expect(model.state == .idle)
        let undo = try #require(noteView(h)?.undoManager)
        undo.undo()
        try await t.settle(h.host) { theme.note == Self.note && noteView(h)?.string == Self.note }   // ⌘Z: the original text, in the store and the view
    }

    @Test func theEssenceIsInsertedAfterTheSectionAsThreeBulletLines() async throws {
        let (h, model) = try make(answer: "1. 一つ目\n2. 二つ目\n3. 三つ目")
        defer { t.finish(h) }
        try await t.settle(h.host) { bottomRow(h).count == 2 && noteView(h) != nil }
        try placeCursor(h, in: "元の文章")
        try #require(bottomRow(h).last).performClick(nil)                                 // 3行の要点
        await waitForCard(model, h)
        try await t.settle(h.host) { bottomRow(h, above: 30, upTo: 400).count == 3 }
        try #require(bottomRow(h, above: 30, upTo: 400).first).performClick(nil)
        let theme = h.store.themes[0]
        let expected = "# 見出し\n元の文章です。分からない。\n\n・一つ目\n・二つ目\n・三つ目\n\n# 次\n別の節。"
        try await t.settle(h.host) { theme.note == expected }
    }

    @Test func movingTheCursorOrTypingDropsTheCard() async throws {
        let (h, model) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { bottomRow(h).count == 2 && noteView(h) != nil }
        try placeCursor(h, in: "元の文章")
        try #require(bottomRow(h).first).performClick(nil)
        await waitForCard(model, h)
        #expect({ if case .ready = model.state { return true } else { return false } }())
        noteView(h)?.setSelectedRange(NSRange(location: (Self.note as NSString).range(of: "別の節").location + 1, length: 0))   // another section
        try await t.settle(h.host) { model.state == .idle }
        try placeCursor(h, in: "元の文章")
        try #require(bottomRow(h).first).performClick(nil)
        await waitForCard(model, h)
        let theme = h.store.themes[0]
        noteView(h)?.insertText("追記", replacementRange: NSRange(location: 0, length: 0))       // one more edit in the note
        try await t.settle(h.host) { theme.note.hasPrefix("追記") && model.state == .idle }
    }

    @Test func aTextOverTheLimitIsRefusedForARewriteWithoutAnyCall() async throws {
        let long = "# 長い\n" + String(repeating: "あ", count: 1_301)
        let (h, model) = try make(note: long)
        defer { t.finish(h) }
        try await t.settle(h.host) { bottomRow(h).count == 2 && noteView(h) != nil }
        h.window.makeKeyAndOrderFront(nil)
        noteView(h)?.window?.makeFirstResponder(noteView(h)); noteView(h)?.setSelectedRange(NSRange(location: 6, length: 0))
        try #require(bottomRow(h).first).performClick(nil)
        try await t.settle(h.host) { model.state == .unavailable(.tooLong) }
    }
}
