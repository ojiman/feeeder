import AppKit
import SwiftUI
import Testing
import ReaderCore
@testable import RSSReader

@Suite(.serialized) @MainActor struct SettingsKeyPathProbe {
    func native(_ root: NSView) -> ArticleTextView? {
        if let v = root as? ArticleTextView { return v }
        return root.subviews.lazy.compactMap(native).first
    }
    func settle(_ host: NSView) async throws {
        for _ in 0..<20 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    }
    @Test func preferenceReachesDetailWithoutReinstall() async throws {
        let suite = try #require(ProcessInfo.processInfo.environment["FEEEDER_SETTINGS_PROBE_SUITE"])
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(16, forKey: "readingSize")
        let article = Article(feedID: UUID(), title: "合成", summary: "", publisher: "SYNTHETIC", publishedAt: .now)
        let paragraphs = (0..<30).map { "合成段落\($0)。" + String(repeating: "日本語とEnglish🙂を読みます。", count: 30) }
        let content = ArticleContent(articleID: article.id, text: paragraphs.joined(separator: "\n\n"), summary: "", coverage: .extracted, originalURL: nil)
        let imageLoader = ReaderImageLoader(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "settings-key-images-\(UUID())"))
        let memory = ReaderScrollMemory()
        var begins = 0, displayed = 0, reloads = 0
        func detail() -> ArticleDetailView {
            ArticleDetailView(article: article, content: content, expiry: .now.addingTimeInterval(86400), loading: false, updateAvailable: false, error: nil,
                              initialAnchor: "paragraph-7", initialOffset: 300, onScroll: { anchor, offset in memory.state.recordScroll(articleID: article.id, anchor: anchor, offset: offset) }, onInteraction: {}, onUpdate: {}, onReload: { reloads += 1 }, onDisplayBegin: { begins += 1 }, onDisplayed: { displayed += 1 }, imageLoader: imageLoader)
        }
        let host = NSHostingView(rootView: detail())
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false; w.contentView = host; defer { w.close() }
        try await settle(host)
        let view = try #require(native(host))
        func draw() async throws {
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.visibleRect))
            view.cacheDisplay(in: view.visibleRect, to: bitmap); try await settle(host)
        }
        try await draw()
        let initial = view.string
        let selected = NSRange(location: (initial as NSString).range(of: paragraphs[7]).location, length: 12)
        view.setSelectedRange(selected)
        view.recordScroll()
        defaults.set(20, forKey: "readingSize")
        host.rootView = detail()
        try await settle(host); try await draw()
        let body = (view.string as NSString).range(of: paragraphs[7]).location
        let font = try #require(view.textStorage?.attribute(.font, at: body, effectiveRange: nil) as? NSFont)
        #expect(font.pointSize == 20)
        #expect(native(host) === view && view.string == initial && view.selectedRange() == selected)
        #expect(begins == 1 && displayed == 1 && reloads == 0)
        let savedAnchor = try #require(memory.state.scrollAnchors[article.id])
        let savedOffset = try #require(memory.state.scrollOffsets[article.id])
        let actualPosition = view.readingPosition()
        #expect(savedAnchor == actualPosition.anchor && abs(savedOffset - actualPosition.offset) < 0.5)
        let visibleCharacter = topCharacter(view)
        view.restore(anchor: savedAnchor, offset: savedOffset)
        try await settle(host); try await draw()
        #expect(topCharacter(view) == visibleCharacter)
        print("KEYPROBE detail path: font \(font.pointSize), same view/text/selection; stored position matches and restores top character; display callbacks once, reload0")
    }
    @Test func readerViewDoesNotRereadOrReloadOnSizeChange() async throws {
        let suite = try #require(ProcessInfo.processInfo.environment["FEEEDER_SETTINGS_PROBE_SUITE"])
        let defaults = try #require(UserDefaults(suiteName: suite)); defaults.set(16, forKey: "readingSize")
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "settings-reader-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try ReaderStore(url: directory.appending(path: "Reader.store"), seedDemo: true)
        let refresh = FeedRefreshController(store: store), review = AIPackageReview(store: store)
        let handoff = ClaudeHandoffController(directory: directory.appending(path: "Handoffs"), review: review, launcher: NoLaunch())
        let imageLoader = ReaderImageLoader(directory: directory.appending(path: "Images"))
        let host = NSHostingView(rootView: ReaderView(store: store, refresh: refresh, aiReview: review, handoff: handoff, imageLoader: imageLoader))
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 810), styleMask: [.titled], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false; w.contentView = host; defer { w.close() }
        try await settle(host)
        func table(_ root: NSView) -> NativeArticleList.Table? {
            if let t = root as? NativeArticleList.Table { return t }
            return root.subviews.lazy.compactMap(table).first
        }
        let list = try #require(table(host)); list.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await settle(host)
        let view = try #require(native(host))
        func draw() async throws {
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.visibleRect))
            view.cacheDisplay(in: view.visibleRect, to: bitmap); try await settle(host)
        }
        try await draw()
        let article = try #require(store.articles.first(where: { $0.firstReadAt != nil }))
        let firstRead = article.firstReadAt, revision = store.contentRevision
        try store.setRead(article, false)
        try await settle(host)
        var calls = ["load": 0, "fetch": 0, "markDisplayed": 0]
        let observers = calls.keys.map { name in
            NotificationCenter.default.addObserver(forName: Notification.Name("SettingsProbe.\(name)"), object: nil, queue: .main) { _ in MainActor.assumeIsolated { calls[name, default: 0] += 1 } }
        }
        defer { observers.forEach { NotificationCenter.default.removeObserver($0) } }
        defaults.set(20, forKey: "readingSize")
        try await settle(host); try await draw()
        #expect(native(host) === view)
        #expect(!article.isRead && article.firstReadAt == firstRead && store.contentRevision == revision)
        #expect(calls.values.allSatisfy { $0 == 0 })
        let body = (view.string as NSString).range(of: "合成段落0。").location
        #expect((view.textStorage?.attribute(.font, at: body, effectiveRange: nil) as? NSFont)?.pointSize == 20)
        print("KEYPROBE ReaderView preference path: unread stays unread, firstRead unchanged, contentRevision unchanged; load/fetch/markDisplayed calls0")
    }
    struct NoLaunch: ClaudeLaunching { func open(_ url: URL) async throws { Issue.record("Unexpected external handoff") } }
    func topCharacter(_ view: ArticleTextView) -> Int {
        let manager = view.layoutManager!, container = view.textContainer!
        let y = max(0, view.visibleRect.minY - view.textContainerOrigin.y)
        let glyph = manager.glyphIndex(for: NSPoint(x: 0, y: y), in: container)
        return manager.characterIndexForGlyph(at: glyph)
    }
    @Test func commandFormsAndResponderBoundaries() {
        func event(_ chars: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: 0)!
        }
        #expect(SettingsKeyProbe.command(event("+", [.command, .shift])) == 1)
        #expect(SettingsKeyProbe.command(event("=", .command)) == 1)
        #expect(SettingsKeyProbe.command(event("-", .command)) == -1)
        #expect(SettingsKeyProbe.command(event("0", .command)) == 0)
        #expect(SettingsKeyProbe.command(event("+", [.command, .option])) == nil)
        #expect(SettingsKeyProbe.command(event("0", [.command, .control])) == nil)
        #expect(SettingsKeyProbe.next(20, command: 1) == 20 && SettingsKeyProbe.next(14, command: -1) == 14)
        #expect(SettingsKeyProbe.next(20, command: 0) == 16)
        let input = NSTextView(); input.isEditable = true
        #expect(SettingsKeyProbe.permitted(input))
        #expect(SettingsKeyProbe.permitted(NSTextField()))
        let marked = MarkedResponder(); marked.isEditable = false
        #expect(!SettingsKeyProbe.permitted(marked))
        print("KEYPROBE command forms, modifier rejection, size limits, editable responder allowance, and marked-text guard checked; physical layouts not simulated")
    }

    final class MarkedResponder: NSTextView { override func hasMarkedText() -> Bool { true } }

}
