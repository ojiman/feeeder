import AppKit
import SwiftUI
import Testing
@testable import RSSReader

@MainActor struct NativeArticleListTests {
    @Test func backgroundInsertionAndReorderPreserveSelectedArticleAndTopOffset() {
        let original = (0..<40).map { _ in UUID() }
        var selected: UUID? = original[10]
        func parent(_ ids: [UUID]) -> NativeArticleList {
            NativeArticleList(ids: ids, article: { _ in nil }, feedTitle: { _ in "" },
                selection: Binding(get: { selected }, set: { selected = $0 }), initialTop: nil,
                focus: false, shortcutsEnabled: true, onTop: { _ in }, onKey: { _ in })
        }
        let coordinator = NativeArticleList.Coordinator(parent(original))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 280, height: 300))
        let table = NativeArticleList.Table(frame: NSRect(x: 0, y: 0, width: 280, height: 4000))
        table.headerView = nil; table.rowHeight = 96; table.intercellSpacing = .zero
        table.addTableColumn(NSTableColumn(identifier: .init("article")))
        table.dataSource = coordinator; table.delegate = coordinator; scroll.documentView = table
        coordinator.table = table; coordinator.scroll = scroll
        coordinator.update(parent(original))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: table.rect(ofRow: 8).minY + 17))
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(table.rows(in: table.visibleRect).location == 8)
        #expect(abs(scroll.contentView.bounds.minY - table.rect(ofRow: 8).minY - 17) < 1)
        let inserted = [UUID()] + original
        var reordered = inserted
        reordered.swapAt(9, 20)
        for ids in [inserted, reordered] {
            coordinator.update(parent(ids))
            #expect(table.selectedRow == ids.firstIndex(of: original[10]))
            #expect(selected == original[10])
            let top = table.rows(in: table.visibleRect).location
            #expect(ids[top] == original[8])
            #expect(abs(scroll.contentView.bounds.minY - table.rect(ofRow: top).minY - 17) < 1)
        }
    }
}
