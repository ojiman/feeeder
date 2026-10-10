import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct NoteReaderTests {
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
    /// bottom and each row from left to right. SwiftUI gives
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
        // The review button is wider and sorts before the two chevrons (the narrow icon buttons); the list starts at the chevrons.
        guard let first = rows.firstIndex(where: { $0.convert($0.bounds, to: nil).width <= 20 }) else { return rows }
        return Array(rows[first...])
    }
    fileprivate struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    fileprivate func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, noteOpen: Bool = false,   // false: start with the panel closed
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
            initialScope: try scope(store), initialNoteOpen: noteOpen)
        let host = NSHostingView(rootView: reader)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-note-reader")
        window.contentView = host
        return Harness(store: store, host: host, window: window, directory: directory)
    }
    fileprivate func finish(_ harness: Harness) {
        harness.window.close(); try? FileManager.default.removeItem(at: harness.directory)
    }

    @Test func theNoteIsAbsentWhileClosedAndBesideTheListAndTheReaderWhenOpen() async throws {
        let closed = try harness(scope: { store in .note(store.notes[0].id) }) { store in
            let note = try store.createNote(text: "# A\n", at: .now)
            try store.addArticle(store.articles[0].id, toNote: note.id, at: .now)
            try store.saveNote(noteID: note.id, text: "既存のノート", at: .now)
        }
        defer { finish(closed) }
        try await settle(closed.host) { find(NativeArticleList.Table.self, in: closed.host)?.numberOfRows == 1 }
        pumpRunLoop(0.2)
        #expect(!containsText("既存のノート", in: closed.host))                            // no note panel until it is opened
        let open = try harness(scope: { store in .note(store.notes[0].id) }, noteOpen: true) { store in
            let note = try store.createNote(text: "# A\n", at: .now)
            try store.addArticle(store.articles[0].id, toNote: note.id, at: .now)
            try store.saveNote(noteID: note.id, text: "既存のノート", at: .now)
        }
        defer { finish(open) }
        try await settle(open.host) { containsText("既存のノート", in: open.host) }
        let table = try #require(find(NativeArticleList.Table.self, in: open.host))
        #expect(table.numberOfRows == 1)                                                  // the list stays in the middle column
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await settle(open.host) { find(ArticleTextView.self, in: open.host)?.string.contains("合成記事 0") == true }   // the reader shows it beside the note
        #expect(containsText("既存のノート", in: open.host))
    }

    @Test func aNoteListsOnlyItsOwnArticlesWithTheNoteClosed() async throws {
        let h = try harness(scope: { store in .note(store.notes[0].id) }) { store in
            let note = try store.createNote(text: "# A\n", at: .now)
            for id in store.articles.map(\.id).prefix(3) { try store.addArticle(id, toNote: note.id, at: .now) }
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 }   // 4 articles exist, 3 are in the note
    }

    @Test func anEmptyNoteListsNoRows() async throws {
        let h = try harness(scope: { store in .note(store.notes[0].id) }) { store in
            _ = try store.createNote(text: "# 空\n", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 0 }
    }
}

/// The note panel beside the article (L1). A suite of its own: see the N4 verification record for why. Run each test alone.
@Suite(.serialized) @MainActor struct NotePanelTests {
    private let t = NoteReaderTests()

    fileprivate func openHarness() throws -> NoteReaderTests.Harness {
        try t.harness(scope: { store in .note(store.notes[0].id) }, noteOpen: true) { store in
            let note = try store.createNote(text: "# A\n", at: .now)
            for index in 0..<3 { try store.addArticle(store.articles[index].id, toNote: note.id, at: .now) }
            try store.saveNote(noteID: note.id, text: "ノートの本文", at: .now)
        }
    }
    private func shown(_ h: NoteReaderTests.Harness, _ title: String) -> Bool {
        t.find(ArticleTextView.self, in: h.host)?.string.contains(title) == true
    }

    @Test func theChevronsMoveBetweenTheNotesArticlesAndStopAtTheEnds() async throws {
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

    /// After S1a the panel is a header and the editor: no summary button, no summary card, no action bar (AI on or off).
    @Test func theNotePanelHasNoSummaryButtonAndNoActionBar() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.containsText("ノートの本文", in: h.host) && t.panelButtons(in: h).count >= 2 }
        pumpRunLoop(0.3)
        #expect(t.panelButtons(in: h).count == 2)                                         // the two chevrons only
        #expect(!t.containsText("記事から要約する", in: h.host) && !t.containsText("わかりやすく", in: h.host))
    }

    /// A panel that opens at once must not take the keyboard: the editor gets focus only when the person clicks it, so `j`, `k`, `s`
    /// and the other keys still work in the list.
    @Test func openingThePanelDoesNotTakeKeyboardFocus() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        h.window.makeKeyAndOrderFront(nil)
        try await t.settle(h.host) { t.containsText("ノートの本文", in: h.host) && t.panelButtons(in: h).count >= 2 }
        pumpRunLoop(0.3)
        let responder = h.window.firstResponder
        #expect(!(responder is NSTextView), "the first responder is \(String(describing: responder))")
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

    @Test func aShownArticleThatLeftTheNoteDoesNotBreakThePanel() async throws {
        let h = try openHarness()
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count >= 2 }
        t.panelButtons(in: h)[1].performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 0") }
        try h.store.removeArticle(h.store.articles[0].id, fromNote: h.store.notes[0].id, at: .now)
        pumpRunLoop(0.3)
        #expect(shown(h, "合成記事 0") && t.containsText("ノートの本文", in: h.host))          // still shown, the note is untouched
        t.panelButtons(in: h)[1].performClick(nil)
        try await t.settle(h.host) { shown(h, "合成記事 1") }
    }
}

@MainActor func pumpRunLoop(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

@Suite(.serialized) @MainActor struct HandoffEntryTests {
    private let t = NoteReaderTests()

    private func make(note: String, articles: Int) throws -> NoteReaderTests.Harness {
        try t.harness(scope: { store in .note(store.notes[0].id) }, noteOpen: true) { store in
            let created = try store.createNote(text: note, at: .now)
            for index in 0..<articles { try store.addArticle(store.articles[index].id, toNote: created.id, at: .now) }
        }
    }
    /// The wide button in the panel's header row, left of the two narrow chevrons.
    private func reviewButton(_ h: NoteReaderTests.Harness) -> NSButton? {
        let width = h.window.contentView?.bounds.width ?? 1_240
        let candidates = t.buttons(in: h.host).filter { !($0 is NSPopUpButton) }.map { ($0, $0.convert($0.bounds, to: nil)) }
            .filter { $0.1.minX > width - 420 && $0.1.width > 0 }
        guard let chevron = candidates.first(where: { $0.1.width <= 20 }) else { return nil }
        return candidates.first { $0.1.width > 40 && abs($0.1.maxY - chevron.1.maxY) < 12 }?.0
    }
    private func packageText(_ h: NoteReaderTests.Harness) -> String? {
        guard let sheet = h.window.attachedSheet?.contentView else { return nil }
        func find(_ v: NSView) -> String? { if let tv = v as? NSTextView, tv.string.contains("Feeeder reading review") { return tv.string }; return v.subviews.lazy.compactMap(find).first }
        return find(sheet)
    }

    @Test func theNotePanelsButtonOpensTheReviewWithTheNote() async throws {
        let h = try make(note: "# 見出し\n本文のノート", articles: 1)
        defer { t.finish(h) }
        h.window.makeKeyAndOrderFront(nil)
        try await t.settle(h.host) { reviewButton(h) != nil }
        reviewButton(h)?.performClick(nil)
        try await t.settle(h.host) { packageText(h) != nil }
        let text = try #require(packageText(h))
        #expect(!text.contains("Goal") && text.contains("Note (written by the user):\n# 見出し\n本文のノート"))
        #expect(text.contains("ノートに書かれていることを「ない」と言わないでください"))                // the review request
        h.window.endSheet(try #require(h.window.attachedSheet))
    }

    @Test func theButtonIsAbsentWhenThereIsNothingToHandOver() async throws {
        let h = try make(note: "", articles: 0)
        defer { t.finish(h) }
        try await t.settle(h.host) { t.panelButtons(in: h).count >= 2 }                    // the chevrons are there
        pumpRunLoop(0.3)
        let width = h.window.contentView?.bounds.width ?? 1_240
        let narrow = t.buttons(in: h.host).filter { !($0 is NSPopUpButton) }.map { $0.convert($0.bounds, to: nil) }.filter { $0.minX > width - 420 && $0.width > 0 && $0.width <= 20 }
        #expect(!narrow.isEmpty)                                                          // the lookup works: the chevrons are found
        #expect(reviewButton(h) == nil)
    }
}
