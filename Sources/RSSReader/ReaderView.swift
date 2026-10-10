import SwiftUI
import ReaderCore

private typealias LibraryScope = ReaderWorkspaceScope

struct ReaderView: View {
    @Bindable var store: ReaderStore
    @Bindable var refresh: FeedRefreshController
    @Bindable var aiReview: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    let imageLoader: ReaderImageLoader
    let suggestions: ThemeSuggestionModel?
    let summaries: ArticleSummaryModel?
    @AppStorage(OnDeviceAISetting.key) private var aiEnabled = true
    @State private var scope: LibraryScope? = .all
    @State private var workspace = ReaderWorkspaceState()
    @State private var selection: UUID?
    @State private var pageForward = true
    @State private var scrollMemory = ReaderScrollMemory()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var noteLayout = NoteLayout()
    @State private var paneMode = ReaderPaneMode.original
    /// The summary that was adopted into the note, so its button reads 「採用しました」 until a new summary is made.
    @State private var adoptedSummary: ArticleSummaryModel.Summary?
    /// Where the cursor was in each theme's note. In memory only: it is restored after a face round trip, not after a restart.
    @State private var noteSelections: [UUID: TextSelection] = [:]
    @State private var saveError: String?
    @State private var themeMessage: String?
    @State private var pickingTheme = false
    @State private var reviewingTheme: ThemeSheet?
    @State private var pickerRestoresListFocus = true
    @State private var loading: ArticleLoadingController
    private var displayedContent: ArticleContent? { loading.displayed }
    @State private var addingSubscription = false
    @State private var editingFeed: Feed?
    @State private var removingFeed: Feed?
    @State private var renamingFolder: String?
    @State private var folderName = ""
    @State private var themeEditor: ThemeEditorTarget?
    @State private var deletingTheme: UUID?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, imageLoader: ReaderImageLoader,
         initialScope: ReaderWorkspaceScope = .all, initialThemeFace: ThemeFace = .articles,
         suggestions: ThemeSuggestionModel? = nil, summaries: ArticleSummaryModel? = nil) {
        self.summaries = summaries
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff
        self.imageLoader = imageLoader; self.suggestions = suggestions
        _loading = State(initialValue: ArticleLoadingController(store: store))
        _scope = State(initialValue: initialScope)
        var initialWorkspace = ReaderWorkspaceState()
        initialWorkspace.scope = initialScope
        if case .theme(let id) = initialScope, initialThemeFace != .articles {
            initialWorkspace.switchFace(of: id, to: initialThemeFace, rememberingReader: ReaderSelectionState())
        }
        _workspace = State(initialValue: initialWorkspace)

    }

    private var selectedExpiry: Date? {
        guard let article = selectedArticle, article.contentDeletedAt == nil else { return nil }
        return RetentionPolicy(days: store.retentionDays).expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt)
    }
    /// Every theme article as two choices: the retained article text first (so it is the default), then the saved RSS summary.
    private func claudeSelections(themeID: UUID) -> [AIInputSelection] {
        store.themeArticles.filter { $0.themeID == themeID }
            .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.key < $1.key }
            .flatMap { link -> [AIInputSelection] in
                (store.article(id: link.articleID) == nil ? [] : [.article(link.articleID)]) + [.themeArticle(link.key)]
            }
    }
    private var selectedArticle: Article? { selection.flatMap { store.article(id: $0) } }
    private var visibleArticleIDs: [UUID] {
        switch scope ?? .all {
        case .unfiledStars: store.unfiledStarredArticleIDs(keeping: selection)
        case .theme(let id): store.themeArticleIDs(themeID: id, keeping: selection)
        case .folder(let name): store.folderArticleIDs(folder: name, keeping: selection)
        case .all: store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: selection)
        case .starred: store.starredArticleIDs(keeping: selection)
        case .unread: store.visibleArticleIDs(feedID: nil, unreadOnly: true, keeping: selection)
        case .feed(let id): store.visibleArticleIDs(feedID: id, unreadOnly: false, keeping: selection)
        }
    }

    private var scopeTitle: String {
        switch scope ?? .all {
        case .unfiledStars: "未整理のStar"
        case .theme(let id): store.theme(id: id)?.name ?? "テーマ"
        case .folder(let name): name
        case .all: "すべての記事"
        case .unread: "未読"
        case .starred: "Star"
        case .feed(let id): store.feed(id: id)?.title ?? "記事"
        }
    }

    var body: some View {
        reader
        .onAppear { if onNoteFace { noteLayout.enterNoteFace(); applyColumns() } }
        .onChange(of: selection) { _, _ in summaries?.reset(); adoptedSummary = nil }
        .onChange(of: showsSummary) { _, shown in
            if shown { if originalPage.url != nil { closeOriginal() } } else { summaries?.reset(); adoptedSummary = nil }
        }
        .onChange(of: onNoteFace) { _, on in
            if on { noteLayout.enterNoteFace() } else { noteLayout.leaveNoteFace() }
            applyColumns()
        }
        .onChange(of: columnVisibility) { _, visibility in
            // The window may change the columns by itself; keep the layout in step (only while on the note face).
            guard onNoteFace else { return }
            noteLayout.follow(visibility == .all ? .all : .doubleColumn)
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
            workspaceList.navigationSplitViewColumnWidth(min: onNoteFace ? 320 : 280, ideal: onNoteFace ? 460 : 400, max: onNoteFace ? 800 : 640)
        } detail: {
            VStack(spacing: 0) {
                if case .theme(let id) = scope, onNoteFace { readerTopBar(id) }
                readerColumn
            }
            .frame(minWidth: 360)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 930, minHeight: 600)
        .tint(.orange)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if case .theme(let id) = scope {
                    Button { reviewingTheme = ThemeSheet(id: id) } label: { Image(systemName: "paperplane") }
                        .help("Claudeで開く…").accessibilityLabel("Claudeで開く")
                        .disabled(claudeSelections(themeID: id).isEmpty)
                }
            }
            // Always present, disabled when no article is open. If these buttons came and went with the selection,
            // the toolbar would change height each time and the whole window would shift (and the title would move).
            ToolbarItemGroup(placement: .primaryAction) {
                let article = selectedArticle
                Button { perform(.toggleStar) } label: { Image(systemName: article?.starredAt == nil ? "star" : "star.fill") }
                    .help("Starを切り替える (s)").accessibilityLabel(article?.starredAt == nil ? "Starを付ける" : "Starを外す")
                    .disabled(article == nil)
                Button { perform(.themePicker) } label: {
                    Image(systemName: article.map { store.isInAnyTheme(articleID: $0.id) } == true ? "square.stack.fill" : "square.stack")
                }
                .help("テーマに入れる (t)").accessibilityLabel("テーマに入れる")
                .disabled(article == nil)
                .popover(isPresented: $pickingTheme, arrowEdge: .bottom) {
                    if let article { ThemePickerView(store: store, articleID: article.id, onMessage: { themeMessage = $0 }, suggestions: suggestions) }
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
        .task(id: ClusterTrigger(active: scope == .unfiledStars && aiEnabled, count: store.unfiledStarCount)) {
            guard let suggestions else { return }
            guard scope == .unfiledStars, aiEnabled else { suggestions.invalidateClusters(); return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await suggestions.loadClusters()
        }
        .onChange(of: aiEnabled) { _, on in if !on { suggestions?.invalidate() } }
        .onChange(of: store.contentRevision) { _, _ in
            loading.refreshCachedContent()
        }
        .onChange(of: pickingTheme) { _, open in
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
        .onKeyPress("j") { guard onNoteFace, shortcutsEnabled else { return .ignored }; move(1); return .handled }   // the articles face has its own on the list
        .onKeyPress("k") { guard onNoteFace, shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .onKeyPress("m") {
            guard shortcutsEnabled, let article = selectedArticle else { return .ignored }
            perform { try store.setRead(article, !article.isRead) }; return .handled
        }
        .onKeyPress("b") { guard shortcutsEnabled else { return .ignored }; openExternal(); return .handled }
        .onKeyPress("s") { guard shortcutsEnabled else { return .ignored }; perform(.toggleStar); return .handled }
        .onKeyPress("t") { guard shortcutsEnabled else { return .ignored }; perform(.themePicker); return .handled }
        .onKeyPress("v") { guard shortcutsEnabled else { return .ignored }; openOriginal(); return .handled }
        .sheet(isPresented: $addingSubscription) {
            SubscriptionSheet(store: store) { scope = .feed($0) }
        }
        .overlay(alignment: .bottomTrailing) {
            if let themeMessage { Text(themeMessage).font(.callout).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding().allowsHitTesting(false) }
        }
        .task(id: themeMessage) {
            guard themeMessage != nil else { return }
            do { try await Task.sleep(for: .seconds(2)); themeMessage = nil } catch {}
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
            Section("テーマ") {
                sidebarRow("未整理のStar", symbol: "tray.full", count: store.unfiledStarCount).tag(LibraryScope.unfiledStars)
                ForEach(store.themes) { theme in
                    sidebarRow(theme.name, symbol: "square.stack", count: store.themeArticleCount(themeID: theme.id))
                        .tag(LibraryScope.theme(theme.id))
                        .contextMenu {
                            Button("名前とゴールを編集…") { themeEditor = ThemeEditorTarget(themeID: theme.id) }
                            Button("削除…", role: .destructive) { deletingTheme = theme.id }
                        }
                }
                Button { themeEditor = ThemeEditorTarget(themeID: nil) } label: { Label("新しいテーマ", systemImage: "plus") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.vertical, 4)
                    .accessibilityLabel("新しいテーマを作る")
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
        .navigationTitle("Feeeder")
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
        .sheet(item: $reviewingTheme) { sheet in
            AIReviewView(store: store, review: aiReview, handoff: handoff, selections: claudeSelections(themeID: sheet.id), themeID: sheet.id)
        }
        .sheet(item: $themeEditor) { target in
            ThemeEditorSheet(store: store, themeID: target.themeID) { scope = .theme($0) }
        }
        .confirmationDialog("このテーマを削除しますか？", isPresented: Binding(get: { deletingTheme != nil }, set: { if !$0 { deletingTheme = nil } })) {
            Button("テーマを削除", role: .destructive) {
                guard let id = deletingTheme else { return }
                perform { try store.deleteTheme(id: id); if scope == .theme(id) { scope = .all } }
                deletingTheme = nil
            }
        } message: { Text("記事とStarそのものは消えません。このテーマに記録した記事のタイトル・リンク・要約と、学習ゴールとノートは消えます。") }
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
            Label(title, systemImage: symbol)
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
                case "t": perform(.themePicker)
                default: break
                }
            }, imageLoader: imageLoader, iconURL: { article in
                let feed = store.feed(id: article.feedID)
                return ImageMetadata.favicon(iconURL: feed?.iconURL, siteURL: feed?.siteURL, sourceURL: feed?.sourceURL)
            }, themed: { store.isInAnyTheme(articleID: $0) }, initialTopOffset: scrollMemory.state.listScrollOffset,
            onTopOffset: { id, offset in scrollMemory.state.listScrollAnchor = id; scrollMemory.state.listScrollOffset = offset })
        .focused($listFocused)
        .navigationTitle(scopeTitle)
        .navigationSubtitle("\(visibleArticleIDs.count)件の記事")
        .overlay {
            if visibleArticleIDs.isEmpty {
                switch scope ?? .all {
                case .theme: ContentUnavailableView("記事が入っていません", systemImage: "square.stack",
                    description: Text("記事を選んで t キーを押すと、このテーマに入れられます。"))
                case .unfiledStars: ContentUnavailableView("未整理のStarはありません", systemImage: "tray.full",
                    description: Text("Starを付けた記事のうち、テーマに入っていないものがここに並びます。"))
                default: ContentUnavailableView("記事はありません", systemImage: "tray",
                    description: Text("購読を追加するか、ほかの一覧を選んでください。"))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if case .theme(let id) = scope {
                VStack(spacing: 0) {
                    ThemeFacePicker(face: faceBinding(id))
                    ThemeGoalStrip(goal: store.theme(id: id)?.goal ?? "", onEdit: { themeEditor = ThemeEditorTarget(themeID: id) })
                }
            }
            else if scope == .unfiledStars, aiEnabled, let suggestions, !suggestions.clusters.groups.isEmpty {
                ClusterSuggestionBar(store: store, model: suggestions, onCreated: { themeMessage = $0 })
            }
        }
        .onKeyPress("j") { guard shortcutsEnabled else { return .ignored }; move(1); return .handled }
        .onKeyPress("k") { guard shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) { Text("j/k 移動"); Text("s Star"); Text("t テーマ"); Text("b/v 原文") }
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 10).background(.bar)
        }
    }

    @ViewBuilder private var workspaceList: some View {
        if case .theme(let id) = scope, workspace.face(of: id) == .note {
            ThemeNotePane(store: store, themeID: id, face: faceBinding(id), selection: noteSelectionBinding(id), sidebarFolded: noteLayout.sidebarFolded, onToggleSidebar: toggleSidebar, onEditGoal: { themeEditor = ThemeEditorTarget(themeID: id) }).id(id)
        }
        else { articleList.id(scope) }
    }

    /// The reader, with the original page sliding over it.
    @ViewBuilder private var readerColumn: some View {
        if showsSummary, let summaries, case .theme(let themeID) = scope {
            summaryPane(summaries, themeID: themeID)
        } else { originalColumn }
    }

    /// The summary card replaces the article only on the note face, with AI on, when the person chose 「AI要約」.
    private var showsSummary: Bool { onNoteFace && aiEnabled && paneMode == .summary }

    @ViewBuilder private func summaryPane(_ summaries: ArticleSummaryModel, themeID: UUID) -> some View {
        if let article = selectedArticle {
            let ready: ArticleSummaryModel.Summary? = { if case .ready(let value) = summaries.state, value.articleID == article.id { return value }; return nil }()
            ArticleSummaryCard(state: summaries.state, articleTitle: article.title, adopted: ready != nil && ready == adoptedSummary,
                               onRequest: { adoptedSummary = nil; summaries.request(articleID: article.id, themeID: themeID) },
                               onCancel: { summaries.cancel() },
                               onAdopt: { adopt($0, article: article, themeID: themeID) },
                               onShowOriginal: { paneMode = .original })
        } else {
            VStack(spacing: 10) {
                Label("AIによる要約", systemImage: "sparkles").font(.headline)
                Text("上のバーで記事を選ぶと、ここで要約を頼めます。").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func adopt(_ summary: ArticleSummaryModel.Summary, article: Article, themeID: UUID) {
        guard let theme = store.theme(id: themeID) else { saveError = "テーマが見つかりません。"; return }
        let note = theme.note
        let result = NoteInsertion.adopted(summary: summary.text, title: article.title, url: article.originalURL.flatMap { ArticleURL.validated($0)?.absoluteString },
                                           into: note, selectionEndUTF16: noteSelectionEnd(themeID, in: note))
        do {
            try store.saveNote(themeID: themeID, text: result.note, at: .now)
            adoptedSummary = summary
            let index = result.note.index(result.note.startIndex, offsetBy: min(result.cursorOffset, result.note.count))
            noteSelections[themeID] = TextSelection(insertionPoint: index)
        } catch { saveError = error.localizedDescription }
    }

    /// The end of the person's selection in the note (or the cursor), as a UTF-16 offset; the end of the note when there is none.
    private func noteSelectionEnd(_ themeID: UUID, in note: String) -> Int? {
        guard let selection = noteSelections[themeID] else { return nil }
        switch selection.indices {
        case .selection(let range): return min(range.upperBound.utf16Offset(in: note), note.utf16.count)
        case .multiSelection(let set): return set.ranges.last.map { min($0.upperBound.utf16Offset(in: note), note.utf16.count) }
        @unknown default: return nil
        }
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

    /// Not while Japanese text is being composed, and not while the theme picker is open (it belongs to the article that is shown).
    private var topBarMayMove: Bool {
        !pickingTheme && !ReaderKeyboardCommands.hasMarkedText(NSApp.keyWindow?.firstResponder)
    }

    private func readerTopBar(_ themeID: UUID) -> some View {
        ReaderTopBar(entries: store.themeArticleEntries(themeID: themeID, selection: selection),
                     canPrevious: ThemeArticleSwitcher.canMove(-1, from: selection, in: visibleArticleIDs),
                     canNext: ThemeArticleSwitcher.canMove(1, from: selection, in: visibleArticleIDs),
                     onPrevious: { guard topBarMayMove else { return }; perform(.previous) },
                     onNext: { guard topBarMayMove else { return }; perform(.next) },
                     onChoose: { id in if id != selection { ReaderPerformance.selectionStarted(id) }; selectArticle(id) },
                     showsSummarySwitch: aiEnabled && summaries != nil, mode: $paneMode)
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
                Image(systemName: "book.pages").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(.orange.opacity(0.8))
                Text("読むことに、余白を。").font(.system(size: 24, weight: .medium, design: .serif))
                Text("一覧から記事を選んでください。")
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var shortcutsEnabled: Bool { ReaderKeyboardCommands.permits(sheet: addingSubscription || editingFeed != nil || renamingFolder != nil || themeEditor != nil || pickingTheme, originalPage: originalPage.url != nil) }
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
        case .themePicker:
            guard selectedArticle != nil, !pickingTheme else { return }
            pickerRestoresListFocus = ReaderKeyboardCommands.listHasFocus(declared: listFocused, responder: NSApp.keyWindow?.firstResponder)
            pickingTheme = true
        }
    }

    private var onNoteFace: Bool {
        if case .theme(let id) = scope { return workspace.face(of: id) == .note }
        return false
    }
    private func noteSelectionBinding(_ themeID: UUID) -> Binding<TextSelection?> {
        Binding(get: { noteSelections[themeID] }, set: { value in noteSelections[themeID] = value })
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
    private func faceBinding(_ themeID: UUID) -> Binding<ThemeFace> {
        Binding(get: { workspace.face(of: themeID) }, set: { setFace($0, of: themeID) })
    }
    private func setFace(_ face: ThemeFace, of themeID: UUID) {
        guard workspace.face(of: themeID) != face else { return }
        scrollMemory.state.select(selection)
        workspace.switchFace(of: themeID, to: face, rememberingReader: scrollMemory.state)
        enterScope()
    }
    private func enterScope() {
        let restored = workspace.reader(in: workspace.scope)
        scrollMemory.state = restored; selectArticle(restored.selectedArticleID)
        // The note face has no article list: the focus stays where the person puts it (the note, the reader).
        if case .theme(let id) = workspace.scope, workspace.face(of: id) == .note { listFocused = false } else { listFocused = true }
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

private struct ClusterTrigger: Hashable { let active: Bool; let count: Int }

/// The theme a review sheet was opened for, kept for the sheet's life even if the selection moves.
private struct ThemeSheet: Identifiable { let id: UUID }

private struct ThemeEditorTarget: Identifiable { let id = UUID(); let themeID: UUID? }
