import AppKit
import SwiftUI
import Testing
@testable import UnagiReader

/// The title of the article list must stay inside its column. (The system's navigation title ran along the whole toolbar, so a long feed
/// name left the column and ran over the article pane.)
@MainActor struct ListHeaderTests {
    /// Draws the header on a dark surface in a column `width` points wide and returns the x range (points) that has any ink.
    private func inkRange(title: String, width: CGFloat) throws -> (min: CGFloat, max: CGFloat) {
        let host = NSHostingView(rootView: ListHeader(title: title, count: 367).environment(\.colorScheme, .dark).background(Color.black))
        host.frame = NSRect(x: 0, y: 0, width: width, height: ListHeader.bandHeight)
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
}
