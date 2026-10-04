import SwiftUI
import ReaderCore

private enum LibraryScope: Hashable {
    case all, unread, feed(UUID)
}

struct ReaderView: View {
    @Bindable var store: ReaderStore
    @Binding var appearance: String
    @State private var scope: LibraryScope? = .all
    @State private var selection: UUID?
    @State private var saveError: String?
    @State private var displayedContent: ArticleContent?
    @State private var addingSubscription = false
    @State private var editingFeed: Feed?
    @State private var removingFeed: Feed?
    @State private var originalPage = OriginalPageState()
    @State private var restoreListFocus = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    private var selectedArticle: Article? { store.articles.first { $0.id == selection } }
    private var visibleArticles: [Article] {
        store.articles.filter { article in
            switch scope ?? .all {
            case .all: true
            case .unread: !article.isRead || article.id == selection
            case .feed(let id): store.isArticle(article, in: id)
            }
        }
    }
    private var scopeTitle: String {
        switch scope ?? .all {
        case .all: "すべての記事"
        case .unread: "未読"
        case .feed(let id): store.feeds.first { $0.id == id }?.title ?? "記事"
        }
    }

    var body: some View {
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
                    .help("XMLから購読を追加").accessibilityLabel("購読を追加")
            }
            ToolbarItemGroup(placement: .primaryAction) {
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
        .onChange(of: selection) { _, id in
            originalPage.close()
            if let article = store.articles.first(where: { $0.id == id }) {
                perform { displayedContent = try store.content(articleID: article.id, at: .now) }
            } else { displayedContent = nil }
        }
        .onChange(of: scope) { _, _ in selection = nil; listFocused = true }
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
                Text("＋からフィードXMLを取り込み。\n自動取得・AI要約は準備中です。")
                    .font(.caption2).foregroundStyle(.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private func subscriptionRow(_ feed: Feed) -> some View {
        sidebarRow(feed.title, symbol: feed.symbol,
                   count: store.articles.filter { store.isArticle($0, in: feed.id) && !$0.isRead }.count)
            .tag(LibraryScope.feed(feed.id))
            .contextMenu {
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
                    if let content = displayedContent, content.articleID == article.id {
                        Text(content.text)
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
                        Label(article.identityKey == nil ? "サンプルの記事" : "フィード提供分 · 全文取得は未実装", systemImage: "doc.text")
                        Spacer()

                    }.font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 670)
                .padding(.horizontal, 42).padding(.vertical, 44)
                .frame(maxWidth: .infinity)
            }
            .id(article.id)
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
