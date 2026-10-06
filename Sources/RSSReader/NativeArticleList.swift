import AppKit
import SwiftUI
import ReaderCore

// Stable native rows avoid rebuilding SwiftUI's 10,000-row ID/preference graph on selection.
struct NativeArticleList: NSViewRepresentable {
    let ids: [UUID]
    let article: (UUID) -> Article?
    let feedTitle: (Article) -> String
    @Binding var selection: UUID?
    let initialTop: UUID?
    let focus: Bool
    let shortcutsEnabled: Bool
    let onTop: (UUID) -> Void
    let onKey: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let table = Table()
        table.headerView = nil
        table.addTableColumn(NSTableColumn(identifier: .init("article")))
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.rowHeight = 96
        table.intercellSpacing = .init(width: 0, height: 0)
        table.style = .inset
        table.allowsMultipleSelection = false
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.setAccessibilityLabel("記事一覧")
        table.keyHandler = { [weak coordinator = context.coordinator] key in
            guard let coordinator, coordinator.parent.shortcutsEnabled else { return false }
            coordinator.parent.onKey(key); return true
        }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        context.coordinator.table = table
        context.coordinator.scroll = scroll
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak coordinator = context.coordinator] _ in
            MainActor.assumeIsolated { coordinator?.recordTop() }
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) { context.coordinator.update(self) }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) }
        coordinator.table?.delegate = nil; coordinator.table?.dataSource = nil
    }

    @MainActor final class Table: NSTableView {
        var keyHandler: ((String) -> Bool)?
        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
               let key = event.charactersIgnoringModifiers, ["j", "k", "m", "b", "v", "s", "n"].contains(key),
               keyHandler?(key) == true { return }
            super.keyDown(with: event)
        }
    }

    @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeArticleList
        weak var table: Table?
        weak var scroll: NSScrollView?
        var observer: NSObjectProtocol?
        var ids: [UUID] = []
        var priorSelection: UUID?
        var priorFocus = false
        var synchronizing = false
        init(_ parent: NativeArticleList) { self.parent = parent }
        func update(_ parent: NativeArticleList) {
            guard let table else { return }
            synchronizing = true
            let selectionChanged = priorSelection != parent.selection
            let topRow = table.rows(in: table.visibleRect).location
            let topID = ids.indices.contains(topRow) ? ids[topRow] : nil
            let topOffset = topID == nil ? 0 : (scroll?.contentView.bounds.minY ?? 0) - table.rect(ofRow: topRow).minY
            self.parent = parent
            let nextIDs = parent.ids
            let idsChanged = ids != nextIDs
            if idsChanged {
                ids = nextIDs; table.reloadData()
            } else {
                let range = table.rows(in: table.visibleRect)
                if range.location != NSNotFound { table.reloadData(forRowIndexes: IndexSet(integersIn: range.location..<min(ids.count, range.location + range.length)), columnIndexes: IndexSet(integer: 0)) }
            }
            if idsChanged || selectionChanged || table.selectedRow < 0 {
                if let id = parent.selection, let row = ids.firstIndex(of: id) {
                    table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    if selectionChanged { table.scrollRowToVisible(row) }
                } else { table.deselectAll(nil) }
            }
            if idsChanged && !selectionChanged, let top = topID ?? parent.initialTop,
               let row = ids.firstIndex(of: top), let scroll {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: table.rect(ofRow: row).minY + topOffset))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            priorSelection = parent.selection
            if parent.focus && !priorFocus { table.window?.makeFirstResponder(table) }
            priorFocus = parent.focus
            synchronizing = false
        }
        func numberOfRows(in tableView: NSTableView) -> Int { parent.ids.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.ids.indices.contains(row), let article = parent.article(parent.ids[row]) else { return nil }
            let cell = tableView.makeView(withIdentifier: .init("article"), owner: self) as? Cell ?? Cell()
            cell.configure(article, feed: parent.feedTitle(article))
            return cell
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !synchronizing, let table, parent.ids.indices.contains(table.selectedRow) else { return }
            let id = parent.ids[table.selectedRow]
            if id != parent.selection { ReaderPerformance.selectionStarted(id); parent.selection = id }
        }
        func recordTop() {
            guard !synchronizing, let table else { return }
            let row = table.rows(in: table.visibleRect).location
            if ids.indices.contains(row) { parent.onTop(ids[row]) }
        }
    }

    @MainActor final class Cell: NSTableCellView {
        private let source = NSTextField(labelWithString: "")
        private let title = NSTextField(wrappingLabelWithString: "")
        private let summary = NSTextField(wrappingLabelWithString: "")
        override init(frame: NSRect) {
            super.init(frame: frame)
            identifier = .init("article")
            source.font = .systemFont(ofSize: 11); source.textColor = .secondaryLabelColor
            source.lineBreakMode = .byTruncatingTail
            title.maximumNumberOfLines = 2; title.lineBreakMode = .byTruncatingTail
            summary.font = .systemFont(ofSize: 12); summary.textColor = .secondaryLabelColor
            summary.maximumNumberOfLines = 2; summary.lineBreakMode = .byTruncatingTail
            let stack = NSStackView(views: [source, title, summary])
            stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 5
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), stack.topAnchor.constraint(equalTo: topAnchor, constant: 10), stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8), source.widthAnchor.constraint(equalTo: stack.widthAnchor), title.widthAnchor.constraint(equalTo: stack.widthAnchor), summary.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        }
        convenience init() { self.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func configure(_ article: Article, feed: String) {
            source.stringValue = (article.isRead ? "" : "● ") + feed + (article.publishedAt == .distantPast ? "" : " · " + article.publishedAt.formatted(.dateTime.month().day()))
            source.textColor = article.isRead ? .secondaryLabelColor : .systemOrange
            title.stringValue = article.title; title.font = .systemFont(ofSize: 14, weight: article.isRead ? .medium : .semibold)
            summary.stringValue = article.summary
        }
    }
}
