import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ReaderCore

private typealias LibraryScope = ReaderWorkspaceScope

struct ReaderView: View {
    @Bindable var store: ReaderStore
    @Bindable var refresh: FeedRefreshController
    @Bindable var aiReview: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    let imageLoader: ReaderImageLoader
    @State private var scope: LibraryScope? = .all
    @State private var workspace = ReaderWorkspaceState()
    @State private var selection: UUID?
    @State private var pageForward = true
    @State private var scrollMemory = ReaderScrollMemory()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var noteLayout = NoteLayout()
    /// The window's width, for the rule that folds the sidebar only in a narrow window (`NoteLayout.foldBelow`).
    @State private var windowWidth: Double = 0
    /// The panel's width when the app started (the ideal width of the inspector), and the width it has now while the person drags.
    @State private var startingPanelWidth = NotePanelWidth.load()
    @State private var panelWidth: Double?
    /// The first width the layout gave this panel: only a change from it can be the person's drag.
    @State private var firstPanelWidth: Double?
    @State private var saveError: String?
    @State private var noteActionMessage: String?
    @State private var sender: SummarySender
    @State private var sendingArticleID: UUID?
    @State private var pickingNote = false
    @State private var reviewingNote: NoteSheet?
    @State private var pickerRestoresListFocus = true
    @State private var loading: ArticleLoadingController
    private var displayedContent: ArticleContent? { loading.displayed }
    /// Set while the "add subscription" sheet is open: the folder the new subscription goes to.
    @State private var addingTo: SubscriptionTarget?
    @State private var removingFeed: Feed?
    @State private var renamingFolder: String?
    /// The note or subscription whose name is being edited in its sidebar row (decision 0043).
    @State private var renaming: SidebarRenaming?
    @State private var folderExpansion = FolderExpansion()
    /// The subscription whose 「フォルダへ移動…」 chooser is open.
    @State private var movingFeedID: UUID?
    @State private var folderName = ""
    @State private var deletingNote: UUID?
    /// After a note was deleted: the offer 「取り消す」 (decision 0042).
    @State private var deletedNote = DeletedNoteOffer()
    /// How far the original page has slid out to the right while it closes (decision 0044), the width of its column, and whether it is closing.
    @State private var originalSlide: CGFloat = 0
    @State private var originalColumnWidth: CGFloat = 600
    @State private var originalClosing = false
    @State private var opml: OPMLImportFlow
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    private let notePasteboard: NSPasteboard
    private let saveMarkdown: @MainActor (String, Data) async throws -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, imageLoader: ReaderImageLoader,
         initialScope: ReaderWorkspaceScope = .all, initialNoteOpen: Bool = true, assistant: (any TextGenerator)? = FoundationModelsGenerator(),
         notePasteboard: NSPasteboard = .general,
         saveMarkdown: @escaping @MainActor (String, Data) async throws -> Bool = ReaderView.presentMarkdownSave,
         chooseOPML: @escaping @MainActor () async -> URL? = OPMLFilePanel.chooseFile) {
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff
        self.notePasteboard = notePasteboard; self.saveMarkdown = saveMarkdown
        _opml = State(initialValue: OPMLImportFlow(store: store, refresh: refresh, chooseFile: chooseOPML))
        self.imageLoader = imageLoader
        _sender = State(initialValue: SummarySender(store: store, assistant: assistant, isEnabled: { OnDeviceAISetting.isEnabled }, pageText: { await ArticleFetcher().fetch(url: $0) }))
        _loading = State(initialValue: ArticleLoadingController(store: store))
        _scope = State(initialValue: initialScope)
        var initialWorkspace = ReaderWorkspaceState()
        initialWorkspace.scope = initialScope
        if case .note(let id) = initialScope, !initialNoteOpen { initialWorkspace.setNote(open: false, of: id) }
        _workspace = State(initialValue: initialWorkspace)
    }

    private var selectedExpiry: Date? {
        guard let article = selectedArticle, article.contentDeletedAt == nil else { return nil }
        return RetentionPolicy(days: store.retentionDays).expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt)
    }
    private func reviewSheet(_ sheet: NoteSheet) -> some View {
        AIReviewView(store: store, review: aiReview, handoff: handoff, noteID: sheet.id)
    }

    private static func presentMarkdownSave(_ fileName: String, _ data: Data) async throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard let window = NSApp.keyWindow else { throw CocoaError(.fileWriteUnknown) }
        return try await withCheckedThrowingContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: false)
                    return
                }
                do {
                    try data.write(to: url, options: .atomic)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func copyNote(_ id: UUID) -> Bool {
        guard let note = store.note(id: id), !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let item = NSPasteboardItem()
        guard item.setString(note.text, forType: .string) else {
            saveError = "ノートをクリップボードへコピーできませんでした。"
            return false
        }
        notePasteboard.clearContents()
        guard notePasteboard.writeObjects([item]) else {
            saveError = "ノートをクリップボードへコピーできませんでした。"
            return false
        }
        noteActionMessage = "ノートをコピーしました"
        return true
    }

    func exportNote(_ id: UUID) async -> Bool {
        guard let note = store.note(id: id), !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            if try await saveMarkdown(NoteMarkdown.fileName(forTitle: note.title), NoteMarkdown.data(for: note.text)) {
                noteActionMessage = "Markdownを書き出しました"
                return true
            }
            return false
        } catch { saveError = error.localizedDescription; return false }
    }
    private var selectedArticle: Article? { selection.flatMap { store.article(id: $0) } }
    private var visibleArticleIDs: [UUID] {
        switch scope ?? .all {
        case .note(let id): store.noteArticleIDs(noteID: id, keeping: selection)
        case .folder(let name): store.folderArticleIDs(folder: name, keeping: selection)
        case .all: store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: selection)
        case .starred: store.starredArticleIDs(keeping: selection)
        case .unread: store.visibleArticleIDs(feedID: nil, unreadOnly: true, keeping: selection)
        case .feed(let id): store.visibleArticleIDs(feedID: id, unreadOnly: false, keeping: selection)
        }
    }

    private var scopeTitle: String {
        switch scope ?? .all {
        case .note(let id): store.note(id: id)?.title ?? "ノート"
        case .folder(let name): name
        case .all: "すべての記事"
        case .unread: "未読"
        case .starred: "Star"
        case .feed(let id): store.feed(id: id)?.title ?? "記事"
        }
    }

    var body: some View {
        // The library window's own chain is long (the CI compiler gives up on a longer one); the OPML import is added from outside it.
        windowContent
            .modifier(OPMLImportPresentation(flow: opml))
            .modifier(DeletedNoteUndoBar(offer: deletedNote, onRestore: restoreDeletedNote))
            .modifier(RenameOnReturn(begin: beginRenamingSelection))
    }

    private var windowContent: some View {
        reader
        .onGeometryChange(for: Double.self, of: { Double($0.size.width) }) { width in
            windowWidth = width
            guard noteOpen else { return }
            noteLayout.windowWidthChanged(to: width); applyColumns()
        }
        .onAppear { if noteOpen { noteLayout.noteOpened(windowWidth: windowWidth); applyColumns() } }
        .onChange(of: noteOpen) { _, open in
            if open { noteLayout.noteOpened(windowWidth: windowWidth) } else { noteLayout.noteClosed(); firstPanelWidth = nil; panelWidth = nil }
            applyColumns()
        }
        .onChange(of: columnVisibility) { _, visibility in
            // The window may change the columns by itself; keep the layout in step (only while the note is open).
            guard noteOpen else { return }
            // Only the two states the layout sets itself; `.automatic` and `.detailOnly` are left alone.
            if visibility == .all { noteLayout.follow(.all) } else if visibility == .doubleColumn { noteLayout.follow(.doubleColumn) }
        }
        .onChange(of: scope) { old, new in
            if let old {
                scrollMemory.state.select(selection)
                workspace.rememberReader(scrollMemory.state, in: old)
            }
            workspace.scope = new ?? .all
            enterScope()
        }
    }

    private var reader: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar.navigationSplitViewColumnWidth(min: 185, ideal: 215, max: 280)
        } content: {
            articleList.id(scope).background(AppPalette.surfaceColor).navigationSplitViewColumnWidth(min: 280, ideal: 400, max: 640)
        } detail: {
            originalColumn.frame(minWidth: 360)
                .inspector(isPresented: noteOpenBinding) { notePanel }
                .inspectorColumnWidth(min: NotePanelWidth.range.lowerBound, ideal: startingPanelWidth, max: NotePanelWidth.range.upperBound)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 600)
        .tint(AppPalette.accentColor)
        .containerBackground(AppPalette.surfaceColor, for: .window)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)       // no bar of its own gray with a line under it: the toolbar sits on the surface
        .toolbar {
            // Always present, disabled when no article is open. If these buttons came and went with the selection,
            // the toolbar would change height each time and the whole window would shift (and the title would move).
            ToolbarItemGroup(placement: .primaryAction) {
                let article = selectedArticle
                Button { togglePanel() } label: { Image(systemName: "note.text") }
                    .keyboardShortcut("i", modifiers: [.option, .command])
                    .help("ノートを開く／閉じる (⌥⌘I)").accessibilityLabel(noteOpen ? "ノートを閉じる" : "ノートを開く")
                    .disabled(noteScopeID == nil)
                Button { perform(.toggleStar) } label: { Image(systemName: article?.starredAt == nil ? "star" : "star.fill") }
                    .help("Starを切り替える (s)").accessibilityLabel(article?.starredAt == nil ? "Starを付ける" : "Starを外す")
                    .disabled(article == nil)
                Button { perform(.sendToNote) } label: {
                    Image(systemName: article.map { store.isInAnyNote(articleID: $0.id) } == true ? "square.stack.fill" : "square.stack")
                }
                .help("ノートに要約を送る (n)").accessibilityLabel("ノートに要約を送る")
                .disabled(article == nil || sender.isWorking)
                .popover(isPresented: $pickingNote, arrowEdge: .bottom) {
                    SendToNoteView(store: store, onSend: { noteID in
                        if let id = sendingArticleID { sender.start(articleID: id, noteID: noteID) }
                        pickingNote = false
                    }, onClose: { pickingNote = false })
                }
                Button(action: openExternal) { Image(systemName: "globe") }
                    .help("元ページをブラウザで開く (b)").accessibilityLabel("元ページをブラウザで開く")
                    .disabled(article?.originalURL.flatMap { ArticleURL.validated($0) } == nil)
            }
        }
        .task(id: selectedExpiry) {
            guard let expiry = selectedExpiry else { return }
            do {
                if expiry > .now { try await Task.sleep(for: .seconds(expiry.timeIntervalSinceNow)) }
                try Task.checkCancellation()
                perform { try store.purgeExpired(at: .now) }
            } catch { /* Selection changes cancel the old article's deadline. */ }
        }
        .task { try? await imageLoader.prepare(at: .now) }
        .onChange(of: store.contentRevision) { _, _ in
            loading.refreshCachedContent()
        }
        .onChange(of: pickingNote) { _, open in
            if !open, originalPage.url == nil { listFocused = pickerRestoresListFocus }
        }
        .onChange(of: selection) { _, id in
            // The page slides out to the right (the way it came in, reversed) and shows the next article's reader text.
            if originalPage.closesWhenSelecting(id) { dismissOriginal { listFocused = true } }
            scrollMemory.state.select(id)
        }
        .task(id: selection) {
            if let id = selection { await loading.load(articleID: id) }
            else { loading.clear() }
        }
        .onKeyPress("j") { guard noteOpen, shortcutsEnabled else { return .ignored }; move(1); return .handled }   // from the reader or the panel; the list has its own
        .onKeyPress("k") { guard noteOpen, shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .onKeyPress("m") {
            guard shortcutsEnabled, let article = selectedArticle else { return .ignored }
            perform { try store.setRead(article, !article.isRead) }; return .handled
        }
        .onKeyPress("b") { guard shortcutsEnabled else { return .ignored }; openExternal(); return .handled }
        .onKeyPress("s") { guard shortcutsEnabled else { return .ignored }; perform(.toggleStar); return .handled }
        .onKeyPress("n") { guard shortcutsEnabled else { return .ignored }; perform(.sendToNote); return .handled }
        .onKeyPress("v") { guard shortcutsEnabled else { return .ignored }; openOriginal(); return .handled }
        .sheet(item: $addingTo) { target in
            SubscriptionSheet(store: store, folder: target.folder) { scope = .feed($0) }
        }
        .overlay(alignment: .bottomTrailing) {
            SendStatusBar(sender: sender, onOpen: { id in
                guard store.note(id: id) != nil else { saveError = NoteError.missingNote.localizedDescription; return }
                workspace.setNote(open: true, of: id)
                scope = .note(id)
            })
        }
        .overlay(alignment: .bottomLeading) {
            if let noteActionMessage {
                Text(noteActionMessage).font(.callout).padding(10).background(.regularMaterial, in: .rect(cornerRadius: 8)).padding(12)
            }
        }
        .task(id: noteActionMessage) {
            guard noteActionMessage != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            noteActionMessage = nil
        }
        .alert("保存できませんでした", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("閉じる") { saveError = nil }
        } message: { Text(saveError ?? "") }
        .alert("フォルダ名を変更", isPresented: Binding(get: { renamingFolder != nil }, set: { if !$0 { renamingFolder = nil } })) {
            TextField("フォルダ名", text: $folderName.singleLine())
            Button("保存") {
                guard let old = renamingFolder else { return }
                let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                perform {
                    try store.renameFolder(from: old, to: name)
                    folderExpansion.rename(from: old, to: name)
                    if scope == .folder(old) {
                        let next: LibraryScope = name.isEmpty ? .all : .folder(name)
                        workspace.rememberReader(scrollMemory.state, in: next); scope = next
                    }
                }
                renamingFolder = nil
            }
            Button("キャンセル", role: .cancel) { renamingFolder = nil }
        } message: { Text("既存の名前を指定すると統合します。空欄は未分類に移します。") }
    }

    private var sidebar: some View {
        let grouped = Dictionary(grouping: store.feeds, by: \.folder)
        let folders = grouped.keys.filter { !$0.isEmpty }.sorted()
        return List(selection: $scope) {
            Section("Feeds") {
                sidebarRow("すべての記事", symbol: "tray", count: store.articles.count).tag(LibraryScope.all)
                sidebarRow("未読", symbol: "circle.dotted", count: store.unreadCount).tag(LibraryScope.unread)
                sidebarRow("Star", symbol: "star", count: store.starCount).tag(LibraryScope.starred)
            }
            Section {
                ForEach(store.notesNewestEditFirst) { note in
                    sidebarRow(note.title, symbol: "note.text", count: store.noteArticleCount(noteID: note.id),
                               inlineEdit: inlineEdit(for: .note(note.id), initial: NameEdit.initialText(forNoteTitle: note.title)))
                        .tag(LibraryScope.note(note.id))
                        .contextMenu {
                            Button("名前を変更") { renaming = .note(note.id) }
                            Button("削除…", role: .destructive) { deletingNote = note.id }
                        }
                }
                Button { createNote() } label: { Label { Text("新しいノート") } icon: { Image(systemName: "plus").foregroundStyle(.secondary) } }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.vertical, 4)
                    .accessibilityLabel("新しいノートを作る")
            } header: {
                SidebarSectionHeader(title: "ノート", help: "新しいノートを作る") { createNote() }
            }
            Section {
                ForEach(grouped[""] ?? []) { feed in subscriptionRow(feed, folders: folders) }
                ForEach(folders, id: \.self) { folder in
                    DisclosureGroup(isExpanded: Binding(get: { folderExpansion.isExpanded(folder) }, set: { folderExpansion.set(folder, expanded: $0) })) {
                        ForEach(grouped[folder] ?? []) { feed in subscriptionRow(feed, folders: folders) }
                    } label: {
                        sidebarRow(folder, symbol: "folder", count: store.folderUnreadCount(folder: folder), addHelp: "「\(folder)」に購読を追加", onAdd: { addingTo = SubscriptionTarget(folder: folder) }, onDropFeeds: { dropFeeds($0, into: folder) }).tag(LibraryScope.folder(folder))
                            .contextMenu { Button("名前を変更…") { folderName = folder; renamingFolder = folder } }
                    }
                }
            } header: {
                SidebarSectionHeader(title: "購読元", help: "購読元を追加", action: { addingTo = SubscriptionTarget(folder: "") }, onDropFeeds: { dropFeeds($0, into: "") })
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Unagi Reader")
        .toolbar(removing: .sidebarToggle)
        .background(SidebarTitlebarControls(refreshing: refresh.refreshing,
            visible: columnVisibility != .doubleColumn && columnVisibility != .detailOnly,
            onAdd: { addingTo = SubscriptionTarget(folder: "") }, onRefresh: { Task { await refresh.refresh() } }))
        .sheet(item: $reviewingNote) { sheet in reviewSheet(sheet) }
        .confirmationDialog("このノートを削除しますか？", isPresented: Binding(get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } })) {
            Button("ノートを削除", role: .destructive) {
                guard let id = deletingNote else { return }
                perform { deletedNote.offer(try store.deleteNote(id: id)); if scope == .note(id) { scope = .all } }
                deletingNote = nil
            }
        } message: { Text("記事とStarそのものは消えません。このノートに記録した記事のタイトル・リンク・要約と、ノートは消えます。") }
    }

    private func subscriptionRow(_ feed: Feed, folders: [String]) -> some View {
        HStack {
            SubscriptionIconView(feed: feed, loader: imageLoader)
            if let edit = inlineEdit(for: .feed(feed.id), initial: feed.title) { InlineNameField(initial: edit.initial, onFinish: edit.finish) }
            else { Text(feed.title).lineLimit(1) }
            Spacer()
            Text((store.feedUnreadCounts[feed.id] ?? 0).formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let error = refresh.errors[feed.id] {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary).help(error)
                    .accessibilityLabel("更新失敗: " + error)
            }
        }.padding(.vertical, 4)
            .draggable(FeedDrag(id: feed.id))
            .tag(LibraryScope.feed(feed.id))
            .popover(isPresented: Binding(get: { movingFeedID == feed.id }, set: { if !$0 { movingFeedID = nil } }), arrowEdge: .trailing) {
                MoveToFolderView(folders: folders, current: feed.folder, onMove: { folder in movingFeedID = nil; moveFeeds([feed.id], to: folder) }, onClose: { movingFeedID = nil })
            }
            .contextMenu {
                Button("この購読を更新") { Task { await refresh.refresh(feedIDs: [feed.id]) } }
                Button("名前を変更") { renaming = .feed(feed.id) }
                Button("フォルダへ移動…") { movingFeedID = feed.id }
                Button("購読を解除…", role: .destructive) { removingFeed = feed }
            }
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int, addHelp: String? = nil, onAdd: @escaping () -> Void = {}, onDropFeeds: (([UUID]) -> Bool)? = nil,
                            inlineEdit: (initial: String, finish: (String?) -> Void)? = nil) -> some View {
        SidebarRow(title: title, symbol: symbol, count: count, addHelp: addHelp, onAdd: onAdd, onDropFeeds: onDropFeeds, inlineEdit: inlineEdit)
    }

    /// What a row needs while its name is edited in place (nil for every other row).
    private func inlineEdit(for target: SidebarRenaming, initial: String) -> (initial: String, finish: (String?) -> Void)? {
        renaming == target ? (initial, { finishRename(target, typed: $0) }) : nil
    }

    /// Return on the selected note or subscription: edit its name in its row (the folder rows rename with a question, see 0043).
    private func beginRenamingSelection() -> Bool {
        // Only while the sidebar (an outline view) has the keyboard: Return in the article list or the note must not rename.
        guard renaming == nil, NSApp.keyWindow?.firstResponder is NSOutlineView else { return false }
        switch scope {
        case .note(let id): renaming = .note(id)
        case .feed(let id): renaming = .feed(id)
        default: return false
        }
        return true
    }

    /// The name was typed (nil: Esc). An empty or unchanged name saves nothing; a failure is shown, never dropped.
    private func finishRename(_ target: SidebarRenaming, typed: String?) {
        renaming = nil
        switch target {
        case .note(let id):
            guard let note = store.note(id: id), let name = NameEdit.result(old: NameEdit.initialText(forNoteTitle: note.title), typed: typed) else { return }
            perform { try store.renameNote(id: id, to: name, at: .now) }
        case .feed(let id):
            guard let feed = store.feed(id: id), let name = NameEdit.result(old: feed.title, typed: typed) else { return }
            perform { try store.updateSubscription(feed, title: name, folder: feed.folder) }
        }
    }

    /// Subscriptions dropped on a folder row (or on the sources header, which is "unfiled"). True if any of them moved.
    private func dropFeeds(_ ids: [UUID], into folder: String) -> Bool { moveFeeds(ids, to: folder) }

    /// Moves subscriptions into a folder (empty: unfiled). The rows glide to their new place and the folder opens to show them
    /// (no motion with Reduce Motion). True if any of them moved.
    @discardableResult private func moveFeeds(_ ids: [UUID], to folder: String) -> Bool {
        var moved = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            perform { moved = try store.moveFeeds(ids: ids, toFolder: folder) }
            if moved { folderExpansion.reveal(folder) }
        }
        return moved
    }

    private var articleList: some View {
        // Swift 6.3 crashes compiling an actor-isolated method reference as the setter.
        NativeArticleList(ids: visibleArticleIDs, article: { store.article(id: $0) }, feedTitle: { store.feed(id: $0.feedID)?.title ?? $0.publisher },
            selection: Binding(get: { selection }, set: { selectArticle($0) }), initialTop: scrollMemory.state.listScrollAnchor, focus: listFocused && originalPage.url == nil,
            shortcutsEnabled: shortcutsEnabled, onTop: { scrollMemory.state.listScrollAnchor = $0 },
            onKey: { key in
                switch key {
                case "j": move(1)
                case "k": move(-1)
                case "m": if let article = selectedArticle { perform { try store.setRead(article, !article.isRead) } }
                case "b": openExternal()
                case "v": openOriginal()
                case "s": perform(.toggleStar)
                case "n": perform(.sendToNote)
                default: break
                }
            }, imageLoader: imageLoader, iconURL: { article in
                let feed = store.feed(id: article.feedID)
                return ImageMetadata.favicon(iconURL: feed?.iconURL, siteURL: feed?.siteURL, sourceURL: feed?.sourceURL)
            }, inNote: { store.isInAnyNote(articleID: $0) }, initialTopOffset: scrollMemory.state.listScrollOffset,
            onTopOffset: { id, offset in scrollMemory.state.listScrollAnchor = id; scrollMemory.state.listScrollOffset = offset },
            onRemoveFromNote: noteScopeID.map { noteID in { articleID in perform { try store.removeArticle(articleID, fromNote: noteID, at: .now) } } })
        .focused($listFocused)
        .navigationTitle("")                                           // the list draws its own title (ListHeader); the system one ran out of the column
        .overlay {
            if visibleArticleIDs.isEmpty {
                switch scope ?? .all {
                case .note: ContentUnavailableView("記事が入っていません", systemImage: "square.stack",
                    description: Text("記事を選んで n キーで要約を送ると、ここに並びます。"))
                default: ContentUnavailableView("記事はありません", systemImage: "tray",
                    description: Text("購読を追加するか、ほかの一覧を選んでください。"))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            // While the note is open the sidebar is folded; this button brings it back (and folds it again).
            if noteOpen {
                HStack(spacing: 0) {
                    Button { toggleSidebar() } label: { Image(systemName: "sidebar.left") }
                        .buttonStyle(.borderless).padding(.leading, 12).padding(.vertical, 6)
                        .help(noteLayout.sidebarFolded ? "サイドバーを表示" : "サイドバーを隠す")
                        .accessibilityLabel(noteLayout.sidebarFolded ? "サイドバーを表示" : "サイドバーを隠す")
                    Spacer(minLength: 0)
                }.background(AppPalette.surfaceColor)
            }
        }
        // After the inset above, so the title is drawn over the bar that holds the sidebar button while a note is open (the other order
        // hides it).
        .overlay(alignment: .top) { ListHeader(title: scopeTitle, count: visibleArticleIDs.count).ignoresSafeArea(.container, edges: .top) }
        .onKeyPress("j") { guard shortcutsEnabled else { return .ignored }; move(1); return .handled }
        .onKeyPress("k") { guard shortcutsEnabled else { return .ignored }; move(-1); return .handled }
    }

    /// The note beside the reader (the inspector). It is there only inside a note.
    @ViewBuilder private var notePanel: some View {
        if let id = noteScopeID {
            NotePanel(store: store, noteID: id,
                      canPrevious: NoteArticleSwitcher.canMove(-1, from: selection, in: visibleArticleIDs),
                      canNext: NoteArticleSwitcher.canMove(1, from: selection, in: visibleArticleIDs),
                      onPrevious: { guard panelMayMove else { return }; perform(.previous) },
                      onNext: { guard panelMayMove else { return }; perform(.next) },
                      onClaude: { reviewingNote = NoteSheet(id: id) },
                      onCopy: { _ = copyNote(id) }, onExport: { Task { _ = await exportNote(id) } })
            .onGeometryChange(for: Double.self, of: { Double($0.size.width) }) { width in
                if firstPanelWidth == nil { firstPanelWidth = width }
                panelWidth = width
            }
            .task(id: panelWidth) {
                // Keep the width after the person lets go: wait for the drag to settle, then save it once.
                guard let width = panelWidth else { return }
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, NotePanelWidth.shouldSave(new: width, saved: UserDefaults.standard.object(forKey: NotePanelWidth.key) as? Double, firstSeen: firstPanelWidth) else { return }
                NotePanelWidth.save(width)
            }
            .id(id)
        } else { EmptyView() }
    }

    /// Not while Japanese text is being composed, and not while the note picker is open (it belongs to the article that is shown).
    private var panelMayMove: Bool {
        !pickingNote && !ReaderKeyboardCommands.hasMarkedText(NSApp.keyWindow?.firstResponder)
    }

    private var originalColumn: some View {
        ZStack(alignment: .trailing) {
            detail.allowsHitTesting(originalPage.url == nil).accessibilityHidden(originalPage.url != nil)
            if let url = originalPage.url, let expectedID = originalPage.articleID {
                OriginalPageView(url: url, onClose: closeOriginal, onCommand: { command in
                    guard selection == expectedID, originalPage.articleID == expectedID else { return }
                    perform(command)
                })
                    .id([expectedID.uuidString, url.absoluteString]).transition(.move(edge: .trailing))
                    .offset(x: originalSlide)
            }
        }.clipped()
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { originalColumnWidth = $0 }
    }

    @ViewBuilder private var detail: some View {
        if let article = selectedArticle {
            ArticleDetailView(article: article, content: displayedContent?.articleID == article.id ? displayedContent : nil,
                expiry: selectedExpiry, canFetchPage: store.isContentAvailable(article, at: .now), loading: loading.loading, updateAvailable: loading.availableUpdate?.articleID == article.id,
                error: loading.error, initialAnchor: scrollMemory.state.scrollAnchors[article.id], initialOffset: scrollMemory.state.scrollOffsets[article.id] ?? 0,
                onScroll: { anchor, offset in scrollMemory.state.recordScroll(articleID: article.id, anchor: anchor, offset: offset) },
                onInteraction: { loading.recordInteraction(articleID: article.id) },
                onUpdate: { perform { try loading.applyAvailableUpdate() } },
                onReload: { Task { guard selection == article.id else { return }; await loading.load(articleID: article.id, refresh: true) } },
                onDisplayBegin: { guard selection == article.id else { return }; ReaderPerformance.displayBegan(article.id) },
                onDisplayed: { guard ReaderKeyboardCommands.acceptsDisplay(articleID: article.id, selectedID: selection, contentID: displayedContent?.articleID, originalVisible: originalPage.url != nil) else { return }; perform { try store.markDisplayed(articleID: article.id, at: .now) } }, imageLoader: imageLoader, pageForward: pageForward, pageMotion: originalPage.url == nil)
        } else {
            VStack(spacing: 18) {
                Image(systemName: "book.pages").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(AppPalette.accentColor.opacity(0.8))
                Text("読むことに、余白を。").font(.system(size: 24, weight: .medium, design: .serif))
                Text("一覧から記事を選んでください。")
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppPalette.surfaceColor)
        }
    }

    private var shortcutsEnabled: Bool { ReaderKeyboardCommands.permits(sheet: addingTo != nil || renaming != nil || renamingFolder != nil || movingFeedID != nil || pickingNote, originalPage: originalPage.url != nil) }
    private func openExternal() {
        guard let string = selectedArticle?.originalURL, let url = ArticleURL.validated(string) else { return }
        if !NSWorkspace.shared.open(url) { saveError = "ブラウザを開けませんでした。" }
    }
    private func openOriginal() {
        guard originalPage.url == nil, let article = selectedArticle, let url = article.originalURL else { return }
        restoreListFocus = ReaderKeyboardCommands.listHasFocus(declared: listFocused, responder: NSApp.keyWindow?.firstResponder)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { _ = originalPage.open(articleID: article.id, url: url) }
    }
    private func closeOriginal() {
        dismissOriginal {
            scrollMemory.state.returnFromOriginal()
            listFocused = restoreListFocus
        }
    }
    /// Slides the original page out to the right, then closes it. A page that goes away without a motion would not be the reverse of
    /// how it came in. With Reduce Motion it just closes. A second request while it slides out is ignored (it closes anyway).
    private func dismissOriginal(then done: @escaping () -> Void) {
        guard originalPage.url != nil, !originalClosing else { return }
        guard !reduceMotion else { originalPage.close(); done(); return }
        originalClosing = true
        withAnimation(.easeOut(duration: 0.22)) {
            originalSlide = originalColumnWidth
        } completion: {
            originalPage.close()
            originalSlide = 0
            originalClosing = false
            done()
        }
    }

    private func perform(_ command: ReaderCommand) {
        guard addingTo == nil, renaming == nil, NSApp.keyWindow?.attachedSheet == nil else { return }
        switch command {
        case .next: move(1)
        case .previous: move(-1)
        case .toggleStar:
            guard let article = selectedArticle else { return }
            perform { try store.setStar(articleID: article.id, isStarred: article.starredAt == nil, at: .now) }
        case .closeOriginal: closeOriginal()
        case .sendToNote:
            guard let article = selectedArticle, !pickingNote, !sender.isWorking else { return }
            sendingArticleID = article.id
            pickerRestoresListFocus = ReaderKeyboardCommands.listHasFocus(declared: listFocused, responder: NSApp.keyWindow?.firstResponder)
            pickingNote = true
        }
    }

    private var noteScopeID: UUID? {
        if case .note(let id) = scope { return id }
        return nil
    }
    private var noteOpen: Bool { noteScopeID.map { workspace.isNoteOpen(of: $0) } ?? false }
    private var noteOpenBinding: Binding<Bool> {
        Binding(get: { noteOpen }, set: { open in if let id = noteScopeID { workspace.setNote(open: open, of: id) } })
    }
    /// A new note is empty and opens at once; its title is 「新規ノート」 until the first line is written.
    private func createNote() {
        perform { scope = .note(try store.createNote(at: .now).id) }
    }
    private func togglePanel() {
        guard let id = noteScopeID else { return }
        workspace.setNote(open: !workspace.isNoteOpen(of: id), of: id)
    }
    private func toggleSidebar() {
        noteLayout.toggleSidebar()
        applyColumns()
    }
    private func applyColumns() {
        let target: NavigationSplitViewVisibility = noteLayout.columns == .all ? .all : .doubleColumn
        guard columnVisibility != target else { return }
        withAnimation(reduceMotion ? nil : .default) { columnVisibility = target }
    }
    private func enterScope() {
        let restored = workspace.reader(in: workspace.scope)
        scrollMemory.state = restored; selectArticle(restored.selectedArticleID)
        listFocused = true
    }

    private func move(_ offset: Int) {
        let next = ReaderNavigation.move(selection, by: offset, in: visibleArticleIDs)
        if let next, next != selection { ReaderPerformance.selectionStarted(next) }
        selectArticle(next)
    }
    private func selectArticle(_ id: UUID?) {
        pageForward = ReaderNavigation.isForward(from: selection, to: id, in: visibleArticleIDs)
        selection = id
    }
    /// 「取り消す」 after a deletion: the note comes back as it was, and is opened.
    private func restoreDeletedNote() {
        perform {
            guard let id = try deletedNote.restore(in: store) else { return }
            workspace.setNote(open: true, of: id)
            scope = .note(id)
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { saveError = error.localizedDescription }
    }
}

/// The note a review sheet was opened for, kept for the sheet's life even if the selection moves.
private struct NoteSheet: Identifiable { let id: UUID }
