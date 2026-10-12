import AppKit
import SwiftUI
import Testing
import ReaderCore
@testable import UnagiReader

/// The title of the article list must stay inside its column. (The system's navigation title ran along the whole toolbar, so a long feed
/// name left the column and ran over the article pane.)
@MainActor struct ListHeaderTests {
    /// Draws the header on a dark surface in a column `width` points wide and returns the x range (points) that has any ink.
    private func inkRange(title: String, width: CGFloat) throws -> (min: CGFloat, max: CGFloat) {
        let host = NSHostingView(rootView: ListHeader(title: title, count: 367).environment(\.colorScheme, .dark).background(Color.black))
        host.frame = NSRect(x: 0, y: 0, width: width, height: ListHeader.bandHeight + ListHeader.height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.appearance = NSAppearance(named: .darkAqua)
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / width
        var first: Int?, last: Int?
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), colour.brightnessComponent > 0.3 else { continue }
                if first == nil { first = x }
                last = x
                break
            }
        }
        return (CGFloat(try #require(first)) / scale, CGFloat(try #require(last) + 1) / scale)
    }

    @Test func aLongNameStaysInsideTheColumnMargins() throws {
        let long = "はてなブックマーク - 人気エントリー - テクノロジー - ここにさらに長い名前が続きます"
        for width in [280.0, 400.0] {                                              // 280 is the narrowest the column can be
            let ink = try inkRange(title: long, width: width)
            #expect(ink.max <= width - ListHeader.sideMargin + 1)                  // it is cut with an ellipsis before the right margin
            #expect(ink.min >= ListHeader.sideMargin - 1)
        }
    }

    @Test func aShortNameStartsAtTheSameEdgeAsTheRows() throws {
        let ink = try inkRange(title: "Star", width: 400)
        #expect(abs(ink.min - ListHeader.sideMargin) <= 2)                         // the left margin is the rows' margin
        #expect(ink.max < 120)                                                     // and a short name does not stretch
    }

    /// The title above the list takes its margin from `NativeArticleList.Metrics.contentMargin`. This measures the rows of the real table
    /// (the app's own setup, with the system's inset style) so the number cannot drift away from what the rows really do.
    @Test func theRowsOfTheRealTableUseTheSharedContentMargin() throws {
        let article = Article(feedID: UUID(), title: "合成記事", summary: "要約", publisher: "合成", publishedAt: .now)
        var selection: UUID?
        let parent = NativeArticleList(ids: [article.id], article: { _ in article }, feedTitle: { _ in "合成購読" },
            selection: Binding(get: { selection }, set: { selection = $0 }), initialTop: nil, focus: false, shortcutsEnabled: true,
            onTop: { _ in }, onKey: { _ in })
        let coordinator = NativeArticleList.Coordinator(parent)
        let table = NativeArticleList.Table()
        NativeArticleList.configure(table)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scroll.documentView = table
        table.dataSource = coordinator; table.delegate = coordinator; coordinator.table = table; coordinator.scroll = scroll
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        coordinator.update(parent)
        table.sizeLastColumnToFit()
        table.layoutSubtreeIfNeeded()
        let cell = try #require(table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NativeArticleList.Cell)
        cell.layoutSubtreeIfNeeded()
        func labels(in view: NSView) -> [NSTextField] { (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(labels) }
        let title = try #require(labels(in: cell).first { $0.stringValue == "合成記事" })
        let time = try #require(labels(in: cell).first { $0.toolTip?.hasPrefix("公開日時：") == true })
        func textRect(_ label: NSTextField) -> NSRect {                                          // the label's alignment rect: where its text really starts and ends
            table.convert(label.alignmentRect(forFrame: label.frame), from: label.superview)
        }
        let titleRect = textRect(title), timeRect = textRect(time)
        #expect(abs(titleRect.minX - NativeArticleList.Metrics.contentMargin) < 0.5)               // the left edge of the text
        #expect(abs((table.bounds.width - timeRect.maxX) - NativeArticleList.Metrics.contentMargin) < 0.5)   // the right edge
    }

    /// The title block sits below the toolbar band, and the first line of the title is level with the ✕ of the right column
    /// (decision 0048). `ListHeader.crossCentre` was measured in the running app, on the ✕ of the original page and of the note screen.
    @Test func theTitleSitsBelowTheBandLevelWithTheCross() throws {
        let width: CGFloat = 400
        let host = NSHostingView(rootView: ListHeader(title: "すべての記事", count: 12).environment(\.colorScheme, .dark).background(Color.black))
        host.frame = NSRect(x: 0, y: 0, width: width, height: ListHeader.bandHeight + ListHeader.height)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.appearance = NSAppearance(named: .darkAqua)
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / host.bounds.height
        var rows: [Int] = []
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)?.brightnessComponent ?? 0) > 0.3 { rows.append(y); break }
        }
        let first = try #require(rows.first)
        #expect(CGFloat(first) / scale >= ListHeader.bandHeight)                                   // nothing in the band
        var lastOfFirstLine = first
        for y in rows.dropFirst() { if y - lastOfFirstLine <= 1 { lastOfFirstLine = y } else { break } }
        let centre = (CGFloat(first) + CGFloat(lastOfFirstLine)) / 2 / scale - ListHeader.bandHeight
        #expect(abs(centre - ListHeader.crossCentre) <= 4)                                         // the first line is level with the ✕
    }
}
