import SwiftUI
import ReaderCore

private enum LibraryScope: Hashable {
    case all, unread, starred, notes, feed(UUID)
}

struct ReaderView: View {
    @Bindable var store: ReaderStore
    @Bindable var refresh: FeedRefreshController
    @Bindable var aiReview: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    @Binding var appearance: String
    @State private var priorReaderScope: LibraryScope? = .all
    @State private var scope: LibraryScope? = .all
    @State private var selection: UUID?
    @State private var scrollMemory = ReaderScrollMemory()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var priorColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var saveError: String?
    @State private var scrapMessage: String?
    @State private var loading: ArticleLoadingController
    private var displayedContent: ArticleContent? { loading.displayed }
    @State private var addingSubscription = false
    @State private var reviewingArticle = false
    @State private var editingFeed: Feed?
    @State private var removingFeed: Feed?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, appearance: Binding<String>) {
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff; _appearance = appearance
        _loading = State(initialValue: ArticleLoadingController(store: store))
    }

    private var selectedExpiry: Date? {
        guard let article = selectedArticle, article.contentDeletedAt == nil else { return nil }
        return RetentionPolicy(days: store.retentionDays).expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt)
    }
    private var selectedArticle: Article? { selection.flatMap { store.article(id: $0) } }
    private var visibleArticleIDs: [UUID] {
        switch scope ?? .all {
        case .notes: []
        case .all: store.visibleArticleIDs(feedID: nil, unreadOnly: false, keeping: selection)
        case .starred: store.starredArticleIDs(keeping: selection)
        case .unread: store.visibleArticleIDs(feedID: nil, unreadOnly: true, keeping: selection)
        case .feed(let id): store.visibleArticleIDs(feedID: id, unreadOnly: false, keeping: selection)
        }
    }

    private var scopeTitle: String {
        switch scope ?? .all {
        case .notes: "振り返り"
        case .all: "すべての記事"
        case .unread: "未読"
        case .starred: "Star"
        case .feed(let id): store.feed(id: id)?.title ?? "記事"
        }
    }

    var body: some View {
        Group {
            if scope == .notes {
                WeeklyNotesView(store: store, aiReview: aiReview, handoff: handoff) { scope = priorReaderScope; listFocused = true }
            } else { reader }
        }
        .onChange(of: scope) { old, new in
            if new == .notes { priorReaderScope = old; return }
            if old != .notes { selection = nil }
            listFocused = true
        }
    }

    private var reader: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar.navigationSplitViewColumnWidth(min: 185, ideal: 215, max: 280)
        } content: {
            articleList.navigationSplitViewColumnWidth(min: 280, ideal: 345, max: 470)
        } detail: {
            ZStack(alignment: .trailing) {
                detail.allowsHitTesting(originalPage.url == nil).accessibilityHidden(originalPage.url != nil)
                if let url = originalPage.url, let expectedID = originalPage.articleID {
                    OriginalPageView(url: url, onClose: closeOriginal, onCommand: { command in
                        guard selection == expectedID, originalPage.articleID == expectedID else { return }
                        perform(command)
                    })
                        .id(url).transition(.move(edge: .trailing))
                }
            }.clipped().frame(minWidth: 360)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 930, minHeight: 600)
        .tint(.orange)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { addingSubscription = true } label: { Image(systemName: "plus") }
                    .help("URLから購読を追加").accessibilityLabel("購読を追加")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await refresh.refresh() } } label: {
                    if refresh.refreshing { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }.disabled(refresh.refreshing).help("購読を更新").accessibilityLabel("購読を更新")
                if let article = selectedArticle {
                    Button { perform(.scrap) } label: { Image(systemName: "square.and.arrow.down") }
                        .help("当日のノートへスクラップ (n)").accessibilityLabel("当日のノートへ保存")
                    Button { perform(.toggleStar) } label: { Image(systemName: article.starredAt == nil ? "star" : "star.fill") }
                        .help("Starを切り替える (s)").accessibilityLabel(article.starredAt == nil ? "Starを付ける" : "Starを外す")
                    Button { perform { try store.setRead(article, !article.isRead) } } label: {
                        Image(systemName: article.isRead ? "envelope.open" : "envelope.badge")
                    }
                    .help("既読・未読を切り替える (m)")
                    .accessibilityLabel(article.isRead ? "未読にする" : "既読にする")
                    Button(action: openExternal) { Image(systemName: "arrow.up.right.square") }
                        .help("元ページをブラウザで開く (b)").accessibilityLabel("ブラウザで開く")
                        .disabled(article.originalURL.flatMap { ArticleURL.validated($0) } == nil)
                    Button(action: openOriginal) { Image(systemName: "globe") }
                        .help("元ページをアプリ内で開く (v)").accessibilityLabel("アプリ内で開く")
                        .disabled(article.originalURL.flatMap { ArticleURL.validated($0) } == nil)
                    Divider()
                    Button("AI入力を確認", systemImage: "doc.text.magnifyingglass") { reviewingArticle = true }
                }
                Menu {
                    Picker("外観", selection: $appearance) {
                        Text("システムに合わせる").tag("system")
                        Text("ライト").tag("light")
                        Text("ダーク").tag("dark")
                    }
                } label: { Image(systemName: "circle.lefthalf.filled") }
                .help("外観を切り替える")
                .accessibilityLabel("外観")
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
        .onChange(of: store.contentRevision) { _, _ in
            loading.refreshCachedContent()
        }
        .onChange(of: selection) { _, id in
            if originalPage.url != nil {
                originalPage.followSelection(articleID: id, url: id.flatMap { store.article(id: $0)?.originalURL })
                if originalPage.url == nil { columnVisibility = priorColumnVisibility }
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
        .onKeyPress("n") { guard shortcutsEnabled else { return .ignored }; perform(.scrap); return .handled }
        .onKeyPress("v") { guard shortcutsEnabled else { return .ignored }; openOriginal(); return .handled }
        .sheet(isPresented: $addingSubscription) {
            SubscriptionSheet(store: store) { scope = .feed($0) }
        }
        .overlay(alignment: .bottomTrailing) {
            if let scrapMessage { Text(scrapMessage).font(.callout).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding().allowsHitTesting(false) }
        }
        .task(id: scrapMessage) {
            guard scrapMessage != nil else { return }
            do { try await Task.sleep(for: .seconds(2)); scrapMessage = nil } catch {}
        }
        .sheet(isPresented: $reviewingArticle, onDismiss: { listFocused = true }) {
            if let selection { AIReviewView(store: store, review: aiReview, handoff: handoff, articleIDs: [selection]) }
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
    }

    private var sidebar: some View {
        List(selection: $scope) {
            Section("ライブラリ") {
                sidebarRow("すべての記事", symbol: "tray", count: store.articles.count).tag(LibraryScope.all)
                sidebarRow("未読", symbol: "circle.dotted", count: store.unreadCount).tag(LibraryScope.unread)
                sidebarRow("Star", symbol: "star", count: store.starCount).tag(LibraryScope.starred)
                sidebarRow("振り返り", symbol: "square.and.pencil", count: store.notes.count).tag(LibraryScope.notes)
            }
            Section("購読元") {
                ForEach(store.feeds.filter { $0.folder.isEmpty }) { feed in subscriptionRow(feed) }
                ForEach(Array(Set(store.feeds.map(\.folder).filter { !$0.isEmpty })).sorted(), id: \.self) { folder in
                    DisclosureGroup(folder) {
                        ForEach(store.feeds.filter { $0.folder == folder }) { feed in subscriptionRow(feed) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Feeeder")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ローカルライブラリ", systemImage: "books.vertical").font(.caption.weight(.medium))
                Text("＋からURLで購読。\n30分ごとに記事を更新します。")
                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func subscriptionRow(_ feed: Feed) -> some View {
        HStack {
            sidebarRow(feed.title, symbol: feed.symbol,
                       count: store.feedUnreadCounts[feed.id] ?? 0)
            if let error = refresh.errors[feed.id] {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary).help(error)
                    .accessibilityLabel("更新失敗: " + error)
            }
        }
            .tag(LibraryScope.feed(feed.id))
            .contextMenu {
                Button("この購読を更新") { Task { await refresh.refresh(feedIDs: [feed.id]) } }
                Button("購読名・フォルダを編集") { editingFeed = feed }
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
        NativeArticleList(ids: visibleArticleIDs, article: { store.article(id: $0) }, feedTitle: { store.feed(id: $0.feedID)?.title ?? $0.publisher },
            selection: $selection, initialTop: scrollMemory.state.listScrollAnchor, focus: listFocused && originalPage.url == nil,
            shortcutsEnabled: shortcutsEnabled, onTop: { scrollMemory.state.listScrollAnchor = $0 },
            onKey: { key in
                switch key {
                case "j": move(1)
                case "k": move(-1)
                case "m": if let article = selectedArticle { perform { try store.setRead(article, !article.isRead) } }
                case "b": openExternal()
                case "v": openOriginal()
                case "s": perform(.toggleStar)
                case "n": perform(.scrap)
                default: break
                }
            })
        .focused($listFocused)
        .navigationTitle(scopeTitle)
        .navigationSubtitle("\(visibleArticleIDs.count)件の記事")
        .overlay {
            if visibleArticleIDs.isEmpty {
                ContentUnavailableView("記事はありません", systemImage: "tray",
                    description: Text("購読を追加するか、ほかの一覧を選んでください。"))
            }
        }
        .onKeyPress("j") { guard shortcutsEnabled else { return .ignored }; move(1); return .handled }
        .onKeyPress("k") { guard shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) { Text("j/k 移動"); Text("s Star"); Text("n 保存"); Text("b/v 原文") }
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 10).background(.bar)
        }
    }

    @ViewBuilder private var detail: some View {
        if let article = selectedArticle {
            ArticleDetailView(article: article, content: displayedContent?.articleID == article.id ? displayedContent : nil,
                expiry: selectedExpiry, loading: loading.loading, updateAvailable: loading.availableUpdate?.articleID == article.id,
                error: loading.error, initialAnchor: scrollMemory.state.scrollAnchors[article.id], initialOffset: scrollMemory.state.scrollOffsets[article.id] ?? 0,
                onScroll: { anchor, offset in scrollMemory.state.recordScroll(articleID: article.id, anchor: anchor, offset: offset) },
                onInteraction: { loading.recordInteraction(articleID: article.id) },
                onUpdate: { perform { try loading.applyAvailableUpdate() } },
                onDisplayBegin: { guard selection == article.id else { return }; ReaderPerformance.displayBegan(article.id) },
                onDisplayed: { guard ReaderKeyboardCommands.acceptsDisplay(articleID: article.id, selectedID: selection, contentID: displayedContent?.articleID, originalVisible: originalPage.url != nil) else { return }; perform { try store.markDisplayed(articleID: article.id, at: .now) } })
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

    private var shortcutsEnabled: Bool { ReaderKeyboardCommands.permits(sheet: addingSubscription || reviewingArticle || editingFeed != nil, originalPage: originalPage.url != nil) }
    private func openExternal() {
        guard let string = selectedArticle?.originalURL, let url = ArticleURL.validated(string) else { return }
        if !NSWorkspace.shared.open(url) { saveError = "ブラウザを開けませんでした。" }
    }
    private func openOriginal() {
        guard let article = selectedArticle, let url = article.originalURL else { return }
        restoreListFocus = ReaderKeyboardCommands.listHasFocus(declared: listFocused, responder: NSApp.keyWindow?.firstResponder)
        priorColumnVisibility = columnVisibility
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { columnVisibility = .doubleColumn; _ = originalPage.open(articleID: article.id, url: url) }
    }
    private func closeOriginal() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { originalPage.close(); columnVisibility = priorColumnVisibility }
        scrollMemory.state.returnFromOriginal()
        listFocused = restoreListFocus
    }

    private func perform(_ command: ReaderCommand) {
        guard !addingSubscription, !reviewingArticle, editingFeed == nil, NSApp.keyWindow?.attachedSheet == nil else { return }
        switch command {
        case .next: move(1)
        case .previous: move(-1)
        case .toggleStar:
            guard let article = selectedArticle else { return }
            perform { try store.setStar(articleID: article.id, isStarred: article.starredAt == nil, at: .now) }
        case .closeOriginal: closeOriginal()
        case .scrap:
            guard let selection else { return }
            perform {
                _ = try store.scrap(articleID: selection, at: .now, timeZone: .current)
                scrapMessage = "当日のノートに保存しました"
            }
        }
    }

    private func move(_ offset: Int) {
        let next = ReaderNavigation.move(selection, by: offset, in: visibleArticleIDs)
        if let next, next != selection { ReaderPerformance.selectionStarted(next) }
        selection = next
    }
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { saveError = error.localizedDescription }
    }
}
