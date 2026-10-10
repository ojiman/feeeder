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
    @AppStorage(OnDeviceAISetting.key) private var aiEnabled = true
    @State private var scope: LibraryScope? = .all
    @State private var workspace = ReaderWorkspaceState()
    @State private var selection: UUID?
    @State private var pageForward = true
    @State private var scrollMemory = ReaderScrollMemory()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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
    @State private var creatingTheme = false
    @State private var newThemeName = ""
    @State private var renamingTheme: UUID?
    @State private var themeName = ""
    @State private var deletingTheme: UUID?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, imageLoader: ReaderImageLoader,
         initialScope: ReaderWorkspaceScope = .all, initialThemeFace: ThemeFace = .articles,
         initialQuestionSelection: ThemeQuestionSelection = .understanding, suggestions: ThemeSuggestionModel? = nil) {
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff
        self.imageLoader = imageLoader; self.suggestions = suggestions
        _loading = State(initialValue: ArticleLoadingController(store: store))
        _scope = State(initialValue: initialScope)
        var initialWorkspace = ReaderWorkspaceState()
        initialWorkspace.scope = initialScope
        if case .theme(let id) = initialScope { initialWorkspace.selectQuestion(initialQuestionSelection, in: id) }
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
        .onChange(of: scope) { old, new in
            if let old, workspace.isReading(old) {
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
            workspaceList.navigationSplitViewColumnWidth(min: 280, ideal: 400, max: 640)
        } detail: {
            if case .theme(let id) = scope, workspace.face(of: id) == .questions {
                questionsDetail(id)
            } else { ZStack(alignment: .trailing) {
                detail.allowsHitTesting(originalPage.url == nil).accessibilityHidden(originalPage.url != nil)
                if let url = originalPage.url, let expectedID = originalPage.articleID {
                    OriginalPageView(url: url, onClose: closeOriginal, onCommand: { command in
                        guard selection == expectedID, originalPage.articleID == expectedID else { return }
                        perform(command)
                    })
                        .id([expectedID.uuidString, url.absoluteString]).transition(.move(edge: .bottom))
                }
            }.clipped().frame(minWidth: 360) }
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
            ToolbarItemGroup(placement: .primaryAction) {
                if workspace.isReading(scope ?? .all), let article = selectedArticle {
                    Button { perform(.toggleStar) } label: { Image(systemName: article.starredAt == nil ? "star" : "star.fill") }
                        .help("Starを切り替える (s)").accessibilityLabel(article.starredAt == nil ? "Starを付ける" : "Starを外す")
                    Button { perform(.themePicker) } label: {
                        Image(systemName: store.isInAnyTheme(articleID: article.id) ? "square.stack.fill" : "square.stack")
                    }
                    .help("テーマに入れる (t)").accessibilityLabel("テーマに入れる")
                    .popover(isPresented: $pickingTheme, arrowEdge: .bottom) {
                        ThemePickerView(store: store, articleID: article.id, onMessage: { themeMessage = $0 }, suggestions: suggestions)
                    }
                    Button(action: openExternal) { Image(systemName: "globe") }
                        .help("元ページをブラウザで開く (b)").accessibilityLabel("元ページをブラウザで開く")
                        .disabled(article.originalURL.flatMap { ArticleURL.validated($0) } == nil)
                }
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
                            Button("名前を変更…") { themeName = theme.name; renamingTheme = theme.id }
                            Button("削除…", role: .destructive) { deletingTheme = theme.id }
                        }
                }
                Button { newThemeName = ""; creatingTheme = true } label: { Label("新しいテーマ", systemImage: "plus") }
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
        .alert("新しいテーマ", isPresented: $creatingTheme) {
            TextField("テーマの名前", text: $newThemeName.singleLine())
            Button("作成") {
                let name = newThemeName
                perform { let theme = try store.createTheme(name: name, at: .now); scope = .theme(theme.id) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("関心のあるテーマの名前を入力します。記事は t キーで入れられます。") }
        .alert("テーマ名を変更", isPresented: Binding(get: { renamingTheme != nil }, set: { if !$0 { renamingTheme = nil } })) {
            TextField("テーマの名前", text: $themeName.singleLine())
            Button("保存") {
                guard let id = renamingTheme else { return }
                let name = themeName
                perform { try store.renameTheme(id: id, to: name, at: .now) }
                renamingTheme = nil
            }
            Button("キャンセル", role: .cancel) { renamingTheme = nil }
        }
        .confirmationDialog("このテーマを削除しますか？", isPresented: Binding(get: { deletingTheme != nil }, set: { if !$0 { deletingTheme = nil } })) {
            Button("テーマを削除", role: .destructive) {
                guard let id = deletingTheme else { return }
                perform { try store.deleteTheme(id: id); if scope == .theme(id) { scope = .all } }
                deletingTheme = nil
            }
        } message: { Text("記事とStarそのものは消えません。このテーマに記録した記事のタイトル・リンク・要約と、問い・答え・いまの理解は消えます。") }
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
            if case .theme(let id) = scope { ThemeFacePicker(face: faceBinding(id)) }
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
        if case .theme(let id) = scope, workspace.face(of: id) == .questions {
            ThemeQuestionsPane(store: store, themeID: id, face: faceBinding(id), selection: questionSelectionBinding(id)).id(id)
        }
        else { articleList.id(scope) }
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

    private var shortcutsEnabled: Bool { workspace.isReading(scope ?? .all) && ReaderKeyboardCommands.permits(sheet: addingSubscription || editingFeed != nil || renamingFolder != nil || creatingTheme || renamingTheme != nil || pickingTheme, originalPage: originalPage.url != nil) }
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

    /// A selection that points at a question that no longer exists shows the "いまの理解" instead.
    private func effectiveQuestionSelection(_ themeID: UUID) -> ThemeQuestionSelection {
        workspace.questionSelection(of: themeID).resolved(existing: Set(store.questions(themeID: themeID).map(\.id)))
    }
    private func questionSelectionBinding(_ themeID: UUID) -> Binding<ThemeQuestionSelection> {
        Binding(get: { effectiveQuestionSelection(themeID) }, set: { workspace.selectQuestion($0, in: themeID) })
    }
    @ViewBuilder private func questionsDetail(_ themeID: UUID) -> some View {
        switch effectiveQuestionSelection(themeID) {
        case .understanding: UnderstandingEditor(store: store, themeID: themeID).id(themeID)
        case .question(let id): QuestionEditor(store: store, themeID: themeID, questionID: id, onOpenArticle: { openArticle($0, in: themeID) }, suggestions: suggestions).id(id)
        }
    }
    /// "読む": back to the articles face with that article selected.
    private func openArticle(_ articleID: UUID, in themeID: UUID) {
        setFace(.articles, of: themeID)
        selectArticle(articleID)
        listFocused = true
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
        if workspace.isReading(workspace.scope) {
            let restored = workspace.reader(in: workspace.scope)
            scrollMemory.state = restored; selectArticle(restored.selectedArticleID); listFocused = true
        } else {
            if originalPage.url != nil { closeOriginal() }
            columnVisibility = .all; listFocused = false
        }
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
