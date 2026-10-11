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
    @State private var addingSubscription = false
    @State private var editingFeed: Feed?
    @State private var removingFeed: Feed?
    @State private var renamingFolder: String?
    @State private var folderName = ""
    @State private var deletingNote: UUID?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    private let notePasteboard: NSPasteboard
    private let saveMarkdown: @MainActor (String, Data) async throws -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, imageLoader: ReaderImageLoader,
         initialScope: ReaderWorkspaceScope = .all, initialNoteOpen: Bool = true, assistant: (any TextGenerator)? = FoundationModelsGenerator(),
         notePasteboard: NSPasteboard = .general,
         saveMarkdown: @escaping @MainActor (String, Data) async throws -> Bool = ReaderView.presentMarkdownSave) {
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff
        self.notePasteboard = notePasteboard; self.saveMarkdown = saveMarkdown
        self.imageLoader = imageLoader
        _sender = State(initialValue: SummarySender(store: store, assistant: assistant, isEnabled: { OnDeviceAISetting.isEnabled }))
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
            articleList.id(scope).navigationSplitViewColumnWidth(min: 280, ideal: 400, max: 640)
        } detail: {
            originalColumn.frame(minWidth: 360)
                .inspector(isPresented: noteOpenBinding) { notePanel }
                .inspectorColumnWidth(min: NotePanelWidth.range.lowerBound, ideal: startingPanelWidth, max: NotePanelWidth.range.upperBound)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 600)
        .tint(AppPalette.accentColor)
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
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                if originalPage.selectionChanged(to: id) {
                    listFocused = true
                }
            }
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
        .sheet(isPresented: $addingSubscription) {
            SubscriptionSheet(store: store) { scope = .feed($0) }
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
        .sheet(item: $editingFeed) { feed in
            SubscriptionSheet(store: store, feed: feed) { _ in }
        }
        .confirmationDialog("購読を解除しますか？", isPresented: Binding(get: { removingFeed != nil }, set: { if !$0 { removingFeed = nil } })) {
            Button("購読を解除", role: .destructive) {
                guard let feed = removingFeed else { return }
                perform { try store.unsubscribe(feed); if scope == .feed(feed.id) { scope = .all } }
                removingFeed = nil
            }
        } message: { Text("記事・本文はライブラリに残ります。") }
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
            Section("ノート") {
                ForEach(store.notesNewestEditFirst) { note in
                    sidebarRow(note.title, symbol: "note.text", count: store.noteArticleCount(noteID: note.id))
                        .tag(LibraryScope.note(note.id))
                        .contextMenu { Button("削除…", role: .destructive) { deletingNote = note.id } }
                }
                Button { createNote() } label: { Label { Text("新しいノート") } icon: { Image(systemName: "plus").foregroundStyle(.secondary) } }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.vertical, 4)
                    .accessibilityLabel("新しいノートを作る")
            }
            Section("購読元") {
                ForEach(grouped[""] ?? []) { feed in subscriptionRow(feed, folders: folders) }
                ForEach(folders, id: \.self) { folder in
                    DisclosureGroup {
                        ForEach(grouped[folder] ?? []) { feed in subscriptionRow(feed, folders: folders) }
                    } label: {
                        sidebarRow(folder, symbol: "folder", count: store.folderUnreadCount(folder: folder)).tag(LibraryScope.folder(folder))
                            .contextMenu { Button("フォルダ名を変更…") { folderName = folder; renamingFolder = folder } }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Unagi Reader")
        .toolbar(removing: .sidebarToggle)
        .background(SidebarTitlebarControls(refreshing: refresh.refreshing,
            visible: columnVisibility != .doubleColumn && columnVisibility != .detailOnly,
            onAdd: { addingSubscription = true }, onRefresh: { Task { await refresh.refresh() } }))
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ローカルライブラリ", systemImage: "books.vertical").font(.caption.weight(.medium))
                Text("＋からURLで購読。\n30分ごとに記事を更新します。")
                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .sheet(item: $reviewingNote) { sheet in reviewSheet(sheet) }
        .confirmationDialog("このノートを削除しますか？", isPresented: Binding(get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } })) {
            Button("ノートを削除", role: .destructive) {
                guard let id = deletingNote else { return }
                perform { try store.deleteNote(id: id); if scope == .note(id) { scope = .all } }
                deletingNote = nil
            }
        } message: { Text("記事とStarそのものは消えません。このノートに記録した記事のタイトル・リンク・要約と、ノートは消えます。") }
    }

    private func subscriptionRow(_ feed: Feed, folders: [String]) -> some View {
        HStack {
            SubscriptionIconView(feed: feed, loader: imageLoader)
            Text(feed.title).lineLimit(1)
            Spacer()
            Text((store.feedUnreadCounts[feed.id] ?? 0).formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let error = refresh.errors[feed.id] {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary).help(error)
                    .accessibilityLabel("更新失敗: " + error)
            }
        }.padding(.vertical, 4)
            .tag(LibraryScope.feed(feed.id))
            .contextMenu {
                Button("この購読を更新") { Task { await refresh.refresh(feedIDs: [feed.id]) } }
                Button("購読名・フォルダを編集") { editingFeed = feed }
                Menu("フォルダへ移動") {
                    Button("未分類") { perform { try store.moveFeed(id: feed.id, toFolder: "") } }
                    ForEach(folders, id: \.self) { folder in
                        Button(folder) { perform { try store.moveFeed(id: feed.id, toFolder: folder) } }
                    }
                }
                Button("購読を解除…", role: .destructive) { removingFeed = feed }
            }
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int) -> some View {
        HStack {
            // Quiet icons (the system would colour them with its blue accent in the active window) and text a little softer than pure white.
            Label { Text(title).foregroundStyle(.primary.opacity(0.85)) } icon: { Image(systemName: symbol).foregroundStyle(.secondary) }.lineLimit(1)
            Spacer()
            Text(count.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
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
        .navigationTitle(scopeTitle)
        .navigationSubtitle("\(visibleArticleIDs.count)件の記事")
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
                }.background(.bar)
            }
        }
        .onKeyPress("j") { guard shortcutsEnabled else { return .ignored }; move(1); return .handled }
        .onKeyPress("k") { guard shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) { Text("j/k 移動"); Text("s Star"); Text("n 要約を送る"); Text("b/v 原文") }
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 10).background(.bar)
        }
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
            }
        }.clipped()
    }

    @ViewBuilder private var detail: some View {
        if let article = selectedArticle {
            ArticleDetailView(article: article, content: displayedContent?.articleID == article.id ? displayedContent : nil,
                expiry: selectedExpiry, loading: loading.loading, updateAvailable: loading.availableUpdate?.articleID == article.id,
                error: loading.error, initialAnchor: scrollMemory.state.scrollAnchors[article.id], initialOffset: scrollMemory.state.scrollOffsets[article.id] ?? 0,
                onScroll: { anchor, offset in scrollMemory.state.recordScroll(articleID: article.id, anchor: anchor, offset: offset) },
                onInteraction: { loading.recordInteraction(articleID: article.id) },
                onUpdate: { perform { try loading.applyAvailableUpdate() } },
                onReload: { Task { guard selection == article.id else { return }; await loading.load(articleID: article.id, refresh: true) } },
                onDisplayBegin: { guard selection == article.id else { return }; ReaderPerformance.displayBegan(article.id) },
                onDisplayed: { guard ReaderKeyboardCommands.acceptsDisplay(articleID: article.id, selectedID: selection, contentID: displayedContent?.articleID, originalVisible: originalPage.url != nil) else { return }; perform { try store.markDisplayed(articleID: article.id, at: .now) } }, imageLoader: imageLoader, pageForward: pageForward)
        } else {
            VStack(spacing: 18) {
                Image(systemName: "book.pages").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(AppPalette.accentColor.opacity(0.8))
                Text("読むことに、余白を。").font(.system(size: 24, weight: .medium, design: .serif))
                Text("一覧から記事を選んでください。")
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var shortcutsEnabled: Bool { ReaderKeyboardCommands.permits(sheet: addingSubscription || editingFeed != nil || renamingFolder != nil || pickingNote, originalPage: originalPage.url != nil) }
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
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { originalPage.close() }
        scrollMemory.state.returnFromOriginal()
        listFocused = restoreListFocus
    }

    private func perform(_ command: ReaderCommand) {
        guard !addingSubscription, editingFeed == nil, NSApp.keyWindow?.attachedSheet == nil else { return }
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
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { saveError = error.localizedDescription }
    }
}

/// The note a review sheet was opened for, kept for the sheet's life even if the selection moves.
private struct NoteSheet: Identifiable { let id: UUID }
