import AppKit
import SwiftUI
import Testing
@testable import UnagiReader

@MainActor struct SidebarSectionHeaderTests {
    /// The x positions (in points) of pixels that are clearly orange (the accent), in a render of the header.
    private func accentColumns(forceVisible: Bool) throws -> [Int] {
        let host = NSHostingView(rootView: SidebarSectionHeader(title: "購読元", help: "購読元を追加", action: {}, forceVisible: forceVisible)
            .frame(width: 215, height: 30).background(Color(white: 0.15)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 215, height: 30), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; window.appearance = NSAppearance(named: .darkAqua)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); pumpRunLoop(0.2)
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        var columns = Set<Int>()
        for x in 0..<rep.pixelsWide { for y in 0..<rep.pixelsHigh {
            guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            if c.redComponent > 0.6 && c.redComponent - c.blueComponent > 0.25 { columns.insert(x * 215 / rep.pixelsWide) }
        } }
        return columns.sorted()
    }

    @Test func thePlusIsHiddenWithoutThePointerAndOrangeAtTheRightEndWithIt() throws {
        #expect(try accentColumns(forceVisible: false).isEmpty)
        let shown = try accentColumns(forceVisible: true)
        let first = try #require(shown.first), last = try #require(shown.last)
        #expect(first > 215 / 2 && last <= 215 - 9)                                             // in the right half, ending before the 9 pt margin that lines it up with the counts
    }
}
