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
    var imageLoader: ReaderImageLoader? = nil
    var iconURL: (Article) -> URL? = { _ in nil }
    var scrapped: (UUID) -> Bool = { _ in false }
    var initialTopOffset: Double = 0
    var onTopOffset: ((UUID, Double) -> Void)? = nil

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
        var focusWhenAttached = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if focusWhenAttached { window?.makeFirstResponder(self) }
        }
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
            let firstLoad = ids.isEmpty
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
            if idsChanged && (!selectionChanged || firstLoad), let top = firstLoad ? parent.initialTop : topID ?? parent.initialTop,
               let row = ids.firstIndex(of: top), let scroll {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: table.rect(ofRow: row).minY + (firstLoad ? parent.initialTopOffset : topOffset)))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            priorSelection = parent.selection
            table.focusWhenAttached = parent.focus
            if parent.focus && !priorFocus { table.window?.makeFirstResponder(table) }
            priorFocus = parent.focus
            synchronizing = false
        }
        func numberOfRows(in tableView: NSTableView) -> Int { parent.ids.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.ids.indices.contains(row), let article = parent.article(parent.ids[row]) else { return nil }
            let cell = tableView.makeView(withIdentifier: .init("article"), owner: self) as? Cell ?? Cell()
            cell.configure(article, feed: parent.feedTitle(article), iconURL: parent.iconURL(article), loader: parent.imageLoader, scrapped: parent.scrapped(article.id))
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
            if ids.indices.contains(row) {
                parent.onTop(ids[row])
                parent.onTopOffset?(ids[row], Double((scroll?.contentView.bounds.minY ?? 0) - table.rect(ofRow: row).minY))
            }
        }
    }

    @MainActor final class Cell: NSTableCellView {
        private let source = NSTextField(labelWithString: "")
        private let title = NSTextField(wrappingLabelWithString: "")
        private let summary = NSTextField(wrappingLabelWithString: "")
        let favicon = NSImageView()
        let thumbnail = NSImageView()
        private var representedID: UUID?
        private var iconURL: URL?
        private var thumbnailURL: URL?
        private var imageTasks: [Task<Void, Never>] = []
        deinit { imageTasks.forEach { $0.cancel() } }
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
            let iconStack = NSStackView(views: [favicon, stack, thumbnail])
            iconStack.orientation = .horizontal; iconStack.alignment = .top; iconStack.spacing = 8
            iconStack.distribution = .fill
            iconStack.translatesAutoresizingMaskIntoConstraints = false
            favicon.imageScaling = .scaleProportionallyUpOrDown; thumbnail.imageScaling = .scaleProportionallyUpOrDown
            favicon.setAccessibilityLabel("購読元のアイコン"); thumbnail.setAccessibilityLabel("記事のサムネイル")
            addSubview(iconStack)
            NSLayoutConstraint.activate([iconStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), iconStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12), iconStack.topAnchor.constraint(equalTo: topAnchor, constant: 10), iconStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8), favicon.widthAnchor.constraint(equalToConstant: 18), favicon.heightAnchor.constraint(equalToConstant: 18), thumbnail.widthAnchor.constraint(equalToConstant: 40), thumbnail.heightAnchor.constraint(equalToConstant: 40), source.widthAnchor.constraint(equalTo: stack.widthAnchor), title.widthAnchor.constraint(equalTo: stack.widthAnchor), summary.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        }
        convenience init() { self.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        func configure(_ article: Article, feed: String, iconURL: URL? = nil, loader: ReaderImageLoader? = nil, scrapped: Bool = false) {
            source.stringValue = (article.isRead ? "" : "● ") + (article.starredAt == nil ? "" : "★ ") + (scrapped ? "▣ " : "") + feed + (article.publishedAt == .distantPast ? "" : " · " + article.publishedAt.formatted(.dateTime.month().day()))
            source.textColor = article.isRead ? .secondaryLabelColor : .systemOrange
            title.stringValue = article.title; title.font = .systemFont(ofSize: 14, weight: article.isRead ? .medium : .semibold)
            summary.stringValue = article.summary
            let imageURL = article.imageURL.flatMap { ArticleURL.validated($0) }
            guard representedID != article.id || self.iconURL != iconURL || thumbnailURL != imageURL else { return }
            imageTasks.forEach { $0.cancel() }; imageTasks = []
            representedID = article.id; self.iconURL = iconURL; thumbnailURL = imageURL
            favicon.image = nil; thumbnail.image = nil; thumbnail.isHidden = imageURL == nil
            let id = article.id
            guard let loader else { return }
            for (url, isThumbnail) in [(iconURL, false), (imageURL, true)] {
                guard let url else { continue }
                imageTasks.append(Task { [weak self] in
                    guard let data = try? await loader.image(url: url, at: .now), !Task.isCancelled else { return }
                    self?.completeImage(NSImage(data: data), articleID: id, url: url, thumbnail: isThumbnail)
                })
            }
        }
        func completeImage(_ image: NSImage?, articleID: UUID, url: URL, thumbnail: Bool) {
            guard representedID == articleID, (thumbnail ? thumbnailURL : iconURL) == url else { return }
            (thumbnail ? self.thumbnail : favicon).image = image
        }
    }
}
