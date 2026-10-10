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
    /// The note panel's buttons by position: the inspector is the right-hand strip of the window. Rows run from the top to the
    /// bottom (the chevrons, the summary button, the summary card, ..., the action bar) and each row from left to right. SwiftUI gives
    /// these buttons no title or tool tip that AppKit can read.
    fileprivate func panelButtons(in h: Harness) -> [NSButton] {
        let width = h.window.contentView?.bounds.width ?? 1_240
        let rows = buttons(in: h.host).filter { !($0 is NSPopUpButton) }
            .map { ($0, $0.convert($0.bounds, to: nil)) }
            .filter { $0.1.minX > width - 420 && $0.1.width > 0 }
            .sorted { lhs, rhs in
                let (rowL, rowR) = ((lhs.1.maxY / 12).rounded(), (rhs.1.maxY / 12).rounded())
                return rowL != rowR ? rowL > rowR : lhs.1.minX < rhs.1.minX
            }.map(\.0)
        // The goal strip is a button too and sorts before the two chevrons (the narrow icon buttons); the list starts at the chevrons.
        guard let first = rows.firstIndex(where: { $0.convert($0.bounds, to: nil).width <= 20 }) else { return rows }
        return Array(rows[first...])
    }
    /// The AI setting is on in a store of its own, so these tests do not depend on (or change) the Mac's real setting.
    fileprivate static func aiOnDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "feeeder-test-\(UUID().uuidString)")!
        defaults.set(true, forKey: OnDeviceAISetting.key)
        return defaults
    }
    fileprivate struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    fileprivate func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, noteOpen: Bool = false,
                         summaries: ((ReaderStore) -> ArticleSummaryModel)? = nil,
                         noteActions: ((ReaderStore) -> NoteActionModel)? = nil,
                         defaults: UserDefaults? = nil,
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
            initialScope: try scope(store), initialNoteOpen: noteOpen, summaries: summaries?(store), noteActions: noteActions?(store), defaults: defaults ?? Self.aiOnDefaults())
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

    @Test func theNoteIsAbsentWhileClosedAndBesideTheListAndTheReaderWhenOpen() async throws {
        let closed = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.addArticle(store.articles[0].id, toTheme: theme.id, at: .now)
            try store.saveNote(themeID: theme.id, text: "既存のノート", at: .now)
        }
        defer { finish(closed) }
        try await settle(closed.host) { find(NativeArticleList.Table.self, in: closed.host)?.numberOfRows == 1 }
        pumpRunLoop(0.2)
        #expect(!containsText("既存のノート", in: closed.host))                            // no note panel until it is opened
        let open = try harness(scope: { store in .theme(store.themes[0].id) }, noteOpen: true) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.addArticle(store.articles[0].id, toTheme: theme.id, at: .now)
            try store.saveNote(themeID: theme.id, text: "既存のノート", at: .now)
        }
        defer { finish(open) }
        try await settle(open.host) { containsText("既存のノート", in: open.host) }
        #expect(find(NativeArticleList.Table.self, in: open.host)?.numberOfRows == 1)     // the list stays in the middle column
        let table = try #require(find(NativeArticleList.Table.self, in: open.host))
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await settle(open.host) { find(ArticleTextView.self, in: open.host)?.string.contains("合成記事 0") == true }   // the reader shows it beside the note
        #expect(containsText("既存のノート", in: open.host))
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
}

/// The note panel beside the article (L1). A suite of its own: see the N4 verification record for why. Run each test alone.
@Suite(.serialized) @MainActor struct NotePanelTests {
    private let t = ThemeReaderTests()

    fileprivate func openHarness() throws -> ThemeReaderTests.Harness {
        try t.harness(scope: { store in .theme(store.themes[0].id) }, noteOpen: true) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            try store.saveNote(themeID: theme.id, text: "ノートの本文", at: .now)
        }
    }
    private func shown(_ h: ThemeReaderTests.Harness, _ title: String) -> Bool {
        t.find(ArticleTextView.self, in: h.host)?.string.contains(title) == true
    }

    @Test func theChevronsMoveBetweenTheThemesArticlesAndStopAtTheEnds() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.containsText("ノートの本文", in: h.host) && t.panelButtons(in: h).count >= 2 }
        let buttons = t.panelButtons(in: h)
        let (previous, next) = (buttons[0], buttons[1])
        #expect(next.isEnabled)                                                           // nothing shown: next (and previous) open the first
        next.performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 0") }
        try await t.settle(h.host) { !previous.isEnabled }                               // at the first article
        next.performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 1") }
        next.performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 2") }
        try await t.settle(h.host) { !next.isEnabled }                                   // at the last article
        previous.performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 1") }
        #expect(t.containsText("ノートの本文", in: h.host))                               // the note stayed
    }

    @Test func theListAndTheChevronsAgreeOnTheShownArticle() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 && t.panelButtons(in: h).count >= 2 }
        let table = try #require(t.find(NativeArticleList.Table.self, in: h.host))
        table.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)       // chosen in the list, not in the panel
        try await t.settle(h.host) { shown(h, "合成記事 2") }
        t.panelButtons(in: h)[0].performClick(nil)                                       // previous
        try await t.settle(h.host) { shown(h, "合成記事 1") }
        try await t.settle(h.host) { table.selectedRow == 1 }                            // the list follows
    }

    @Test func aShownArticleThatLeftTheThemeDoesNotBreakThePanel() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count >= 2 }
        t.panelButtons(in: h)[1].performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 0") }
        try h.store.removeArticle(h.store.articles[0].id, fromTheme: h.store.themes[0].id, at: .now)
        pumpRunLoop(0.3)
        #expect(shown(h, "合成記事 0") && t.containsText("ノートの本文", in: h.host))          // still shown, the note is untouched
        t.panelButtons(in: h)[1].performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 1") }
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

/// The AI summary inside the note panel (N4, moved by L1). A suite of its own; run each test alone (see the N4 verification record).
@Suite(.serialized) @MainActor struct AISummaryTests {
    private let t = ThemeReaderTests()

    /// A private settings store, so a test never changes the shared setting that other suites read.
    private static func privateDefaults(aiEnabled: Bool) -> (UserDefaults, String) {
        let name = "feeeder-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(aiEnabled, forKey: OnDeviceAISetting.key)
        return (defaults, name)
    }
    private func make(answer: String? = "これは要約です。", enabled: EnabledSwitch = EnabledSwitch(), defaults: UserDefaults? = nil) throws -> (ThemeReaderTests.Harness, ArticleSummaryModel) {
        var model: ArticleSummaryModel?
        let h = try t.harness(scope: { store in .theme(store.themes[0].id) }, noteOpen: true, summaries: { store in
            let made = ArticleSummaryModel(store: store, assistant: StubAssistant(answer: answer), isEnabled: { enabled.on })
            model = made; return made
        }, defaults: defaults) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            try store.saveNote(themeID: theme.id, text: "前の文章", at: .now)
        }
        return (h, try #require(model))
    }
    private func noteView(_ h: ThemeReaderTests.Harness) -> NSTextView? {
        func find(_ v: NSView) -> NSTextView? { if let tv = v as? NSTextView, tv.isEditable, !tv.isFieldEditor { return tv }; return v.subviews.lazy.compactMap(find).first }
        return find(h.host)
    }
    private func waitFor(_ model: ArticleSummaryModel, _ h: ThemeReaderTests.Harness, _ done: (ArticleSummaryModel.State) -> Bool) async {
        for _ in 0..<200 {
            if done(model.state) { return }
            h.host.layoutSubtreeIfNeeded()
            await Task.yield()
            pumpRunLoop(0.01)
        }
    }
    private func showFirstArticle(_ h: ThemeReaderTests.Harness) async throws {
        try await t.settle(h.host) { t.panelButtons(in: h).count >= 3 && noteView(h) != nil }
        t.panelButtons(in: h)[1].performClick(nil)                                       // next: opens the first article
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 0") == true }
    }

    @Test func theSummaryButtonIsShownWhenAIIsOnAndAbsentWhenItIsOff() async throws {
        let (h, _) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count == 3 }                  // two chevrons and 「記事から要約する」
        let (defaults, name) = Self.privateDefaults(aiEnabled: false)
        defer { defaults.removePersistentDomain(forName: name) }
        let (off, _) = try make(defaults: defaults)
        defer { t.finish(off) }
        try await t.settle(off.host) { noteView(off) != nil }
        pumpRunLoop(0.2)
        #expect(t.panelButtons(in: off).count == 2)                                      // only the chevrons
    }

    @Test func theButtonNeedsAnArticleAndAsksForNothingUntilPressed() async throws {
        let (h, model) = try make()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count == 3 }
        #expect(!t.panelButtons(in: h)[2].isEnabled)                                     // no article shown
        try await showFirstArticle(h)
        try await t.settle(h.host) { t.panelButtons(in: h)[2].isEnabled }
        pumpRunLoop(0.2)
        #expect(model.state == .idle && h.store.themes[0].note == "前の文章")             // nothing was made or written
    }

    @Test func aSummaryIsMadeOnRequestAndAdoptedIntoTheNoteAndUndoBringsItBack() async throws {
        let (h, model) = try make()
        defer { t.finish(h) }
        try await showFirstArticle(h)
        try await t.settle(h.host) { t.panelButtons(in: h)[2].isEnabled }
        t.panelButtons(in: h)[2].performClick(nil)
        await waitFor(model, h) { if case .ready = $0 { return true } else { return false } }
        try await t.settle(h.host) { t.panelButtons(in: h).count == 6 }                  // chevrons, summary, 採用 / 作り直す / 閉じる
        let theme = h.store.themes[0]
        #expect(theme.note == "前の文章")
        t.panelButtons(in: h)[3].performClick(nil)                                       // 採用
        let adopted = "前の文章\n\nこれは要約です。\n出典: 合成記事 0 <http://127.0.0.1:1/article/0>\n"
        try await t.settle(h.host) { theme.note == adopted && noteView(h)?.string == adopted }
        try await t.settle(h.host) { !t.panelButtons(in: h)[3].isEnabled }                // 「採用しました」
        let undo = try #require(noteView(h)?.undoManager)
        undo.undo()
        try await t.settle(h.host) { theme.note == "前の文章" && noteView(h)?.string == "前の文章" }
    }

    @Test func aFailureOffersToTryAgainAndMovingToAnotherArticleClearsTheCard() async throws {
        let (h, model) = try make(answer: nil)
        defer { t.finish(h) }
        try await showFirstArticle(h)
        try await t.settle(h.host) { t.panelButtons(in: h)[2].isEnabled }
        t.panelButtons(in: h)[2].performClick(nil)
        await waitFor(model, h) { $0 == .failed }
        #expect(model.state == .failed)
        try await t.settle(h.host) { t.panelButtons(in: h).count == 4 }                  // 「もう一度」 appears
        t.panelButtons(in: h)[1].performClick(nil)                                       // another article
        try await t.settle(h.host) { t.find(ArticleTextView.self, in: h.host)?.string.contains("合成記事 1") == true }
        try await t.settle(h.host) { model.state == .idle && t.panelButtons(in: h).count == 3 }
    }
}

/// The two note actions below the note (N5). A suite of its own; run each test alone (see the N4 verification record).
@Suite(.serialized) @MainActor struct NoteActionTests {
    private let t = ThemeReaderTests()
    private static let note = "# 見出し\n元の文章です。分からない。\n\n# 次\n別の節。"

    private static func privateDefaults(aiEnabled: Bool) -> (UserDefaults, String) {
        let name = "feeeder-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(aiEnabled, forKey: OnDeviceAISetting.key)
        return (defaults, name)
    }
    private func make(answer: String? = "読みやすい文章です。", enabled: EnabledSwitch = EnabledSwitch(), note: String = NoteActionTests.note, defaults: UserDefaults? = nil) throws -> (ThemeReaderTests.Harness, NoteActionModel) {
        var model: NoteActionModel?
        let h = try t.harness(scope: { store in .theme(store.themes[0].id) }, noteOpen: true, noteActions: { _ in
            let made = NoteActionModel(assistant: StubAssistant(answer: answer), isEnabled: { enabled.on })
            model = made; return made
        }, defaults: defaults) { store in
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
        let (defaults, name) = Self.privateDefaults(aiEnabled: false)
        defer { defaults.removePersistentDomain(forName: name) }
        let (off, _) = try make(defaults: defaults)
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

/// The note panel's button that asks Claude to review the note (N6). A suite of its own; run each test alone.
@Suite(.serialized) @MainActor struct HandoffEntryTests {
    private let t = ThemeReaderTests()

    private func make(goal: String, note: String, articles: Int) throws -> ThemeReaderTests.Harness {
        try t.harness(scope: { store in .theme(store.themes[0].id) }, noteOpen: true) { store in
            let theme = try store.createTheme(name: "A", goal: goal, at: .now)
            for index in 0..<articles { try store.addArticle(store.articles[index].id, toTheme: theme.id, at: .now) }
            if !note.isEmpty { try store.saveNote(themeID: theme.id, text: note, at: .now) }
        }
    }
    /// The wide button in the panel's header row, left of the two narrow chevrons.
    private func reviewButton(_ h: ThemeReaderTests.Harness) -> NSButton? {
        let width = h.window.contentView?.bounds.width ?? 1_240
        let candidates = t.buttons(in: h.host).filter { !($0 is NSPopUpButton) }.map { ($0, $0.convert($0.bounds, to: nil)) }
            .filter { $0.1.minX > width - 420 && $0.1.width > 0 }
        guard let chevron = candidates.first(where: { $0.1.width <= 20 }) else { return nil }
        return candidates.first { $0.1.width > 40 && abs($0.1.maxY - chevron.1.maxY) < 12 }?.0
    }
    private func packageText(_ h: ThemeReaderTests.Harness) -> String? {
        guard let sheet = h.window.attachedSheet?.contentView else { return nil }
        func find(_ v: NSView) -> String? { if let tv = v as? NSTextView, tv.string.contains("Feeeder reading review") { return tv.string }; return v.subviews.lazy.compactMap(find).first }
        return find(sheet)
    }

    @Test func theNotePanelsButtonOpensTheReviewWithTheGoalAndTheNote() async throws {
        let h = try make(goal: "目標を書いた", note: "# 見出し\n本文のノート", articles: 1)
        defer { t.finish(h) }
        h.window.makeKeyAndOrderFront(nil)
        try await t.settle(h.host) { reviewButton(h) != nil }
        reviewButton(h)?.performClick(nil)
        try await t.settle(h.host) { packageText(h) != nil }
        let text = try #require(packageText(h))
        #expect(text.contains("Goal (written by the user):\n目標を書いた") && text.contains("Note (written by the user):\n# 見出し\n本文のノート"))
        #expect(text.contains("ノートに書かれていることを「ない」と言わないでください"))                // the review request
        h.window.endSheet(try #require(h.window.attachedSheet))
    }

    @Test func theButtonIsAbsentWhenThereIsNothingToHandOver() async throws {
        let h = try make(goal: "", note: "", articles: 0)
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count >= 2 }                    // the chevrons are there
        pumpRunLoop(0.3)
        #expect(reviewButton(h) == nil)
    }
}
