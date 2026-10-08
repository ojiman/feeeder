import AppKit
import SwiftUI
import WebKit
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct ReaderLayoutTests {
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
    @Test func originalPageKeepsColumnsAndSidebarControlsMounted() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let entries = (0..<3).map { index in
            ParsedEntry(sourceID: "synthetic-\(index)", title: "合成記事 \(index)", url: URL(string: "http://127.0.0.1:1/article/\(index)"), summary: "合成要約", body: "合成本文", coverage: .feedProvided, publishedAt: .now.addingTimeInterval(Double(-index)))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "http://127.0.0.1:1/feed")!, entries: entries, skippedEntries: 0), receivedAt: .now)
        let review = AIPackageReview(store: store)
        let reader = ReaderView(store: store, refresh: FeedRefreshController(store: store), aiReview: review,
            handoff: ClaudeHandoffController(directory: directory.appendingPathComponent("Handoff"), review: review, launcher: NoLauncher()),
            imageLoader: ReaderImageLoader(directory: directory.appendingPathComponent("Images")))
        let host = NSHostingView(rootView: reader)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-reader-layout")
        window.contentView = host
        defer { window.close() }
        try await settle(host) { find(NativeArticleList.Table.self, in: host)?.numberOfRows == 3 && window.titlebarAccessoryViewControllers.contains { $0.view is NSHostingView<SidebarTitlebarControls.Buttons> } }
        let table = try #require(find(NativeArticleList.Table.self, in: host))
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try await settle(host) { find(ArticleTextView.self, in: host)?.string.contains("合成記事 0") == true }
        let accessory = try #require(window.titlebarAccessoryViewControllers.first { $0.view is NSHostingView<SidebarTitlebarControls.Buttons> })
        let frame = table.convert(table.bounds, to: nil)
        for row in [1, 2, 0] {
            let coordinator = try #require(table.delegate as? NativeArticleList.Coordinator)
            coordinator.parent.onKey("v")
            try await settle(host) { find(OriginalReaderWebView.self, in: host) != nil || find(OriginalFailureHostingView<AnyView>.self, in: host) != nil }
            #expect(window.titlebarAccessoryViewControllers.contains { $0 === accessory })
            #expect(!accessory.view.isHidden)
            #expect(abs(table.convert(table.bounds, to: nil).minX - frame.minX) < 1)
            #expect(abs(table.bounds.width - frame.width) < 1)
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            try await settle(host) { find(OriginalReaderWebView.self, in: host) == nil && find(OriginalFailureHostingView<AnyView>.self, in: host) == nil }
            #expect(window.titlebarAccessoryViewControllers.contains { $0 === accessory })
            #expect(!accessory.view.isHidden)
            #expect(abs(table.convert(table.bounds, to: nil).minX - frame.minX) < 1)
            #expect(abs(table.bounds.width - frame.width) < 1)
        }
    }
}
