import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import UnagiReader

/// The sidebar's rows scrolled up under the window buttons, and the scroll bar ran up to the top of the window (seen while dogfooding,
/// 2026-10-17). Decision 0057: the sidebar's band, as high as the window buttons' band, belongs to the window buttons and the two
/// buttons; the rows and their scroll bar start below it.
extension SplitViewFoldTests {
    @Suite(.serialized) @MainActor struct SidebarBandTests {
        private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
            if let result = view as? T { return result }
            return view.subviews.lazy.compactMap { find(type, in: $0) }.first
        }

        @Test func theSidebarsScrollViewStartsBelowTheBand() async throws {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
            let entries = [ParsedEntry(sourceID: "synthetic-0", title: "合成記事 0", url: URL(string: "http://127.0.0.1:1/article/0"), summary: "合成要約", body: "合成本文", coverage: .feedProvided, publishedAt: .now)]
            _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "http://127.0.0.1:1/feed")!, entries: entries, skippedEntries: 0), receivedAt: .now)
            let reader = ReaderView(store: store, refresh: FeedRefreshController(store: store),
                imageLoader: ReaderImageLoader(directory: directory.appendingPathComponent("Images")))
            let host = NSHostingView(rootView: reader)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-sidebar-band")
            window.contentView = host
            window.orderFront(nil)
            defer { window.close() }
            var outline: NSOutlineView?
            for _ in 0..<250 {
                host.layoutSubtreeIfNeeded()
                outline = find(NSOutlineView.self, in: host)
                if outline?.enclosingScrollView != nil, find(NativeArticleList.Table.self, in: host)?.numberOfRows == 1 { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            let scroll = try #require(outline?.enclosingScrollView)
            // Window coordinates run upward from the bottom: the distance from the top of the window is the height minus the top edge.
            let top = 800 - scroll.convert(scroll.bounds, to: nil).maxY
            #expect(top >= ListHeader.bandHeight - 0.5, "the sidebar's scroll view starts \(top) pt from the window's top")
        }
    }
}
