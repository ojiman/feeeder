import SwiftUI
import ReaderCore

private enum LibraryScope: Hashable {
    case all, unread, notes, feed(UUID)
}

struct ReaderView: View {
    @Bindable var store: ReaderStore
    @Bindable var refresh: FeedRefreshController
    @Binding var appearance: String
    @State private var priorReaderScope: LibraryScope? = .all
    @State private var scope: LibraryScope? = .all
    @State private var selection: UUID?
    @State private var saveError: String?
    @State private var loading: ArticleLoadingController
    private var displayedContent: ArticleContent? { loading.displayed }
    @State private var addingSubscription = false
    @State private var editingFeed: Feed?
    @State private var removingFeed: Feed?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    init(store: ReaderStore, refresh: FeedRefreshController, appearance: Binding<String>) {
        self.store = store; self.refresh = refresh; _appearance = appearance
        _loading = State(initialValue: ArticleLoadingController(store: store))
    }

    private var selectedExpiry: Date? {
        guard let article = selectedArticle, article.contentDeletedAt == nil else { return nil }
        return RetentionPolicy(days: store.retentionDays).expiresAt(receivedAt: article.firstReceivedAt, firstReadAt: article.firstReadAt)
    }
    private var selectedArticle: Article? { store.articles.first { $0.id == selection } }
    private var visibleArticles: [Article] {
        store.articles.filter { article in
            switch scope ?? .all {
            case .notes: false
            case .all: true
            case .unread: !article.isRead || article.id == selection
            case .feed(let id): store.isArticle(article, in: id)
            }
        }
    }
    private var scopeTitle: String {
        switch scope ?? .all {
        case .notes: "振り返り"
        case .all: "すべての記事"
        case .unread: "未読"
        case .feed(let id): store.feeds.first { $0.id == id }?.title ?? "記事"
        }
    }

    var body: some View {
        Group {
            if scope == .notes {
                WeeklyNotesView(store: store) { scope = priorReaderScope; listFocused = true }
            } else { reader }
        }
        .onChange(of: scope) { old, new in
            if new == .notes { priorReaderScope = old; return }
            if old != .notes { selection = nil }
            listFocused = true
        }
    }

    private var reader: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 185, ideal: 215, max: 280)
        } content: {
            articleList.navigationSplitViewColumnWidth(min: 280, ideal: 345, max: 470)
        } detail: {
            ZStack(alignment: .trailing) {
                detail.allowsHitTesting(originalPage.url == nil).accessibilityHidden(originalPage.url != nil)
                if let url = originalPage.url {
                    OriginalPageView(url: url, onClose: closeOriginal)
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
            originalPage.close()
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
        .onKeyPress("v") { guard shortcutsEnabled else { return .ignored }; openOriginal(); return .handled }
        .onExitCommand { if originalPage.url != nil { closeOriginal() } }
        .sheet(isPresented: $addingSubscription) {
            SubscriptionSheet(store: store) { scope = .feed($0) }
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
                sidebarRow("未読", symbol: "circle.dotted", count: store.articles.filter { !$0.isRead }.count).tag(LibraryScope.unread)
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
        .navigationTitle("RSS Reader")
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
                       count: store.articles.filter { store.isArticle($0, in: feed.id) && !$0.isRead }.count)
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
        List(selection: $selection) {
            ForEach(visibleArticles) { article in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(article.isRead ? Color.clear : .orange).frame(width: 6, height: 6)
                        Text(store.feeds.first { $0.id == article.feedID }?.title ?? article.publisher)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if article.publishedAt != .distantPast { Text(article.publishedAt, format: .dateTime.month().day()) }
                    }.font(.caption2).foregroundStyle(.secondary)
                    Text(article.title).font(.system(size: 14, weight: article.isRead ? .medium : .semibold))
                        .lineLimit(2).lineSpacing(2)
                    Text(article.summary).font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(2).lineSpacing(3)
                }
                .padding(.vertical, 8)
                .tag(article.id)
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.inset)
        .focused($listFocused)
        .navigationTitle(scopeTitle)
        .navigationSubtitle("\(visibleArticles.count)件の記事")
        .overlay {
            if visibleArticles.isEmpty {
                ContentUnavailableView("記事はありません", systemImage: "tray",
                    description: Text("購読を追加するか、ほかの一覧を選んでください。"))
            }
        }
        .onKeyPress("j") { guard shortcutsEnabled else { return .ignored }; move(1); return .handled }
        .onKeyPress("k") { guard shortcutsEnabled else { return .ignored }; move(-1); return .handled }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) { Text("j/k 移動"); Text("m 既読"); Text("b/v 原文") }
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 10).background(.bar)
        }
    }

    @ViewBuilder private var detail: some View {
        if let article = selectedArticle {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text(article.publisher.uppercased()).tracking(1.3)
                        Spacer()
                        Text(displayedContent?.articleID == article.id ? displayedContent!.coverage.label : "本文なし").padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }.font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text(article.title).font(.system(size: 30, weight: .bold))
                        .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if article.publishedAt == .distantPast { Text("公開日時不明") }
                        else { Text(article.publishedAt, format: .dateTime.year().month().day()) }
                    }.font(.caption).foregroundStyle(.secondary)
                    Divider()
                    if loading.loading { Label("本文を確認中", systemImage: "arrow.down.doc").font(.caption).foregroundStyle(.secondary) }
                    if loading.availableUpdate?.articleID == article.id {
                        Button("取得した本文に切り替える") { perform { try loading.applyAvailableUpdate() } }
                            .buttonStyle(.link).font(.caption)
                    }
                    if let error = loading.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                    if let content = displayedContent, content.articleID == article.id, let expiry = selectedExpiry, expiry > .now {
                        Text(content.text)
                            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in loading.recordInteraction(articleID: article.id) })
                            .font(.system(size: 16)).lineSpacing(8).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onAppear {
                                guard selection == content.articleID else { return }
                                perform { try store.markDisplayed(articleID: content.articleID, at: .now) }
                            }
                    } else {
                        Text("本文を利用できません。元ページから確認できます。")
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.top, 10)
                    HStack {
                        Label(displayedContent?.coverage.label ?? "本文は利用できません", systemImage: "doc.text")
                        Spacer()

                    }.font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 670)
                .padding(.horizontal, 42).padding(.vertical, 44)
                .frame(maxWidth: .infinity)
            }
            .id(article.id)
            .onScrollPhaseChange { _, phase in
                if phase != .idle { loading.recordInteraction(articleID: article.id) }
            }
            .simultaneousGesture(TapGesture().onEnded { loading.recordInteraction(articleID: article.id) })
            .background(Color(nsColor: .textBackgroundColor))
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

    private var shortcutsEnabled: Bool { !addingSubscription && editingFeed == nil && originalPage.url == nil }
    private func openExternal() {
        guard let string = selectedArticle?.originalURL, let url = ArticleURL.validated(string) else { return }
        if !NSWorkspace.shared.open(url) { saveError = "ブラウザを開けませんでした。" }
    }
    private func openOriginal() {
        guard let article = selectedArticle, let url = article.originalURL else { return }
        restoreListFocus = listFocused
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { _ = originalPage.open(articleID: article.id, url: url) }
    }
    private func closeOriginal() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { originalPage.close() }
        listFocused = restoreListFocus
    }

    private func move(_ offset: Int) {
        selection = ReaderNavigation.move(selection, by: offset, in: visibleArticles.map(\.id))
    }
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { saveError = error.localizedDescription }
    }
}
