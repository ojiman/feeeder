import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import UnagiReader

/// The add and refresh buttons at the top of the sidebar are a titlebar accessory whose width is worked out from where the sidebar is.
/// After the sidebar slid out and in again, the width could stay 0: the buttons were gone next to a sidebar that was there (seen while
/// dogfooding, 2026-10-13). The sidebar may be moved by `v` (the original page) and by `n` (the note), and a person can press them
/// again before the move has ended.
extension SplitViewFoldTests {
    @Suite(.serialized) @MainActor struct SidebarButtonsTests {
        private struct Harness {
            let host: NSHostingView<ReaderView>
            let window: NSWindow
            let directory: URL
        }
        private func harness() throws -> Harness {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
            let entries = (0..<3).map { index in
                ParsedEntry(sourceID: "synthetic-\(index)", title: "合成記事 \(index)", url: URL(string: "http://127.0.0.1:1/article/\(index)"), summary: "合成要約", body: "合成本文", coverage: .feedProvided, publishedAt: .now.addingTimeInterval(Double(-index)))
            }
            _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "http://127.0.0.1:1/feed")!, entries: entries, skippedEntries: 0), receivedAt: .now)
            let reader = ReaderView(store: store, refresh: FeedRefreshController(store: store),
                imageLoader: ReaderImageLoader(directory: directory.appendingPathComponent("Images")))
            let host = NSHostingView(rootView: reader)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-sidebar-buttons")
            window.contentView = host
            window.orderFront(nil)
            return Harness(host: host, window: window, directory: directory)
        }
        private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
            if let result = view as? T { return result }
            return view.subviews.lazy.compactMap { find(type, in: $0) }.first
        }
        private func outerSplit(in view: NSView) -> NSSplitViewController? {
            if let split = view as? NSSplitView, let controller = split.delegate as? NSSplitViewController, controller.splitViewItems.count == 3 { return controller }
            return view.subviews.lazy.compactMap { outerSplit(in: $0) }.first
        }
        private func pump(_ h: Harness, _ milliseconds: Int) async throws {
            var left = milliseconds
            while left > 0 { h.host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(10)); left -= 10 }
        }
        private func accessory(_ h: Harness) -> NSTitlebarAccessoryViewController? {
            h.window.titlebarAccessoryViewControllers.first { $0.view is NSHostingView<SidebarTitlebarControls.Buttons> }
        }
        /// At rest, the buttons are there, shown and wide enough exactly when the sidebar is. Nil when that holds, else what was seen.
        private func problem(_ h: Harness) -> String? {
            let collapsed = outerSplit(in: h.host)?.splitViewItems.first?.isCollapsed ?? false
            let buttons = accessory(h)
            let fine = collapsed ? buttons == nil : (buttons != nil && buttons?.view.isHidden == false && (buttons?.view.frame.width ?? 0) > 80)
            return fine ? nil : "[sidebar folded \(collapsed), buttons \(buttons != nil), hidden \(buttons?.view.isHidden ?? false), width \(Int(buttons?.view.frame.width ?? -1))]"
        }
        /// Waits until the buttons are as they should be, for at most 6 s (a slow machine takes longer to finish the move). Only a state
        /// that never gets right is a failure. Nil when it did; else what was seen last.
        private func eventuallyFine(_ h: Harness) async throws -> String? {
            for _ in 0..<300 {
                if problem(h) == nil { return nil }
                try await pump(h, 20)
            }
            return problem(h)
        }
        private func start() async throws -> (Harness, NativeArticleList.Table, NativeArticleList.Coordinator) {
            let h = try harness()
            try await pump(h, 800)
            let table = try #require(find(NativeArticleList.Table.self, in: h.host))
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            try await pump(h, 600)
            return (h, table, try #require(table.delegate as? NativeArticleList.Coordinator))
        }

        /// The cause, without the luck of timing: when the buttons were placed while the sidebar was still on its way, their width was 0 and
        /// nothing placed them again. The split view tells when its panes have a new size, and that must place them again.
        @Test func theButtonsAreWorkedOutAgainWhenTheSplitViewResizes() async throws {
            let (h, _, _) = try await start()
            defer { h.window.close(); try? FileManager.default.removeItem(at: h.directory) }
            let buttons = try #require(accessory(h))
            #expect(problem(h) == nil)
            buttons.view.setFrameSize(NSSize(width: 0, height: buttons.view.frame.height))      // as it was left in the bug
            let split = try #require(outerSplit(in: h.host)).splitView
            NotificationCenter.default.post(name: NSSplitView.didResizeSubviewsNotification, object: split)
            try await pump(h, 100)
            #expect(problem(h) == nil, "the buttons were not placed again \(problem(h) ?? "")")
        }

        @Test func theButtonsKeepTheirWidthWhenTheNoteIsOpenedAndClosedQuickly() async throws {
            let (h, _, coordinator) = try await start()
            defer { h.window.close(); try? FileManager.default.removeItem(at: h.directory) }
            for (openFor, closeFor) in [(80, 200), (80, 250), (80, 310), (100, 250)] {
                do {
                    coordinator.parent.onKey("n")
                    try await pump(h, openFor + 20)
                    coordinator.parent.onKey("n")                                          // before the move has ended
                    try await pump(h, closeFor + 300)
                    let seen = try await eventuallyFine(h)
                    #expect(seen == nil, "note open \(openFor) ms, closed after \(closeFor) ms: \(seen ?? "")")
                }
            }
        }

        @Test func theButtonsKeepTheirWidthWhenThePageIsOpenedAndClosedQuickly() async throws {
            let (h, table, coordinator) = try await start()
            defer { h.window.close(); try? FileManager.default.removeItem(at: h.directory) }
            var row = 1
            for openFor in [0, 80, 150, 320] {
                coordinator.parent.onKey("v")
                try await pump(h, openFor + 20)
                row = (row + 1) % 3
                table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)     // closes the page
                try await pump(h, 300)
                let seen = try await eventuallyFine(h)
                #expect(seen == nil, "page open \(openFor) ms: \(seen ?? "")")
            }
        }
    }
}
