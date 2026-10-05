import SwiftUI
import AppKit
import ReaderCore

struct AIReviewView: View {
    @Bindable var store: ReaderStore
    @Bindable var review: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    let articleIDs: [UUID]
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<UUID>()
    @State private var options: [Option] = []
    @State private var language = "日本語"
    @State private var error: String?
    @State private var copied = false
    private struct Option: Identifiable {
        let id: UUID
        let title: String
        let coverage: String
        let available: Bool
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AIへの入力を確認").font(.title2.bold())
                Spacer()
                Button("閉じる") { review.clear(); dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                Picker("出力言語", selection: $language) { Text("日本語").tag("日本語"); Text("English").tag("English") }.frame(width: 250)
                Text("本文を省略せず、選択した出典と一緒に渡します。").font(.caption).foregroundStyle(.secondary)
            }
            HSplitView {
                List(options) { option in
                    Toggle(isOn: Binding(get: { selected.contains(option.id) }, set: { included in
                        if included { selected.insert(option.id) } else { selected.remove(option.id) }
                        generate()
                    })) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(option.title).lineLimit(2)
                            Text(option.coverage).font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(!option.available && !selected.contains(option.id)).padding(.vertical, 5)
                }.frame(minWidth: 200, idealWidth: 250, maxWidth: 340)
                VStack(alignment: .leading, spacing: 8) {
                    if let package = review.package {
                        Text("\(package.sources.count)出典 · \(Data(package.text.utf8).count.formatted()) bytes · 有効期限 \(package.expiresAt.formatted())")
                            .font(.caption).foregroundStyle(.secondary)
                        PackageTextView(text: package.text)
                        Text("SHA-256: \(package.sha256)").font(.caption2.monospaced()).textSelection(.enabled)
                    } else {
                        ContentUnavailableView("再生成して確認してください", systemImage: "doc.text.magnifyingglass",
                            description: Text(review.reason ?? "本文を利用できる記事を選んでください。"))
                    }
                }.frame(minWidth: 400)
            }
            if let message = error ?? review.reason { Text(message).foregroundStyle(.secondary).font(.caption) }
            if let message = handoff.error ?? handoff.maintenanceError { Text(message).foregroundStyle(.secondary).font(.caption) }
            if handoff.opened { Text("Claudeに確認画面を開きました。添付完了・送信・読取の確認はClaude側で行ってください。").font(.callout) }
            HStack {
                Button("再生成してレビュー", action: generate).disabled(selected.isEmpty)
                Spacer()
                Button(copied ? "コピーしました" : "全文をコピー") {
                    perform {
                        let package = try review.validated(at: .now)
                        NSPasteboard.general.clearContents()
                        guard NSPasteboard.general.setString(package.text, forType: .string) else { throw AIPackageError.invalid }
                        copied = true
                    }
                }.disabled(review.package == nil)
                Button("TXTを書き出す", action: export).disabled(review.package == nil)
                Button("分割を書き出す", action: exportSplit).disabled(review.package == nil)
                Button(handoff.error != nil ? "Claude起動を再試行" : handoff.opened ? "Claudeをもう一度開く" : "Claudeで開く") {
                    guard let package = review.package else { return }
                    Task { await handoff.open(package: package) }
                }.disabled(review.package == nil || handoff.launching).buttonStyle(.borderedProminent)
            }
            Text("確認済み: Claude Desktop 2.19675.0 / Pro / Cowork。通常Chatの自動添付は未検証です。Claude側でAttachを確認し、本人が送信してください。送信後に、生成物だけの専用フォルダの読取・変更許可が出る場合があります。処理はcloudで行われ、使用するファイルは端末を離れます。リンク由来の注意表示が出る場合もあります。Coworkを利用できない場合や添付制限時は、コピー・書き出しを選べます。")
                .font(.caption).foregroundStyle(.secondary)
            Text("Feeeder内のコピーは期限切れ・削除時に破棄します。本人が保存したファイルやAI側へ渡した内容は、この削除の対象外です。返答は本人が確認し、ノートへ貼り付け・編集してください。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 820, minHeight: 640)
        .onAppear { handoff.resetStatus(); refreshOptions(); selected = Set(options.filter(\.available).map(\.id)); generate() }
        .onChange(of: language) { _, _ in generate() }
        .onChange(of: store.contentRevision) { _, _ in review.reconcile(at: .now); refreshOptions(); copied = false }
        .task(id: review.package?.expiresAt) {
            guard let expiry = review.package?.expiresAt else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)))
                try Task.checkCancellation(); review.reconcile(at: .now); refreshOptions(); copied = false
            } catch { /* Closing or regenerating cancels the previous deadline. */ }
        }
        .onDisappear { review.clear() }
    }
    private func refreshOptions() {
        options = articleIDs.compactMap { id in
            guard let article = store.article(id: id) else { return nil }
            let content = try? store.content(articleID: id, at: .now)
            return Option(id: id, title: article.title, coverage: content?.coverage.label ?? "本文期限切れ・削除済み、または本文なし", available: content != nil)
        }
    }
    private func generate() {
        copied = false; error = nil; handoff.resetStatus()
        perform { try review.build(articleIDs: articleIDs.filter { selected.contains($0) }, language: language, at: .now) }
    }
    private func export() {
        perform {
            _ = try review.validated(at: .now)
            let panel = NSSavePanel(); panel.nameFieldStringValue = "Feeeder-review.txt"; panel.allowedContentTypes = [.plainText]
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                perform { let package = try review.validated(at: .now); try Data(package.text.utf8).write(to: url, options: .atomic) }
            }
        }
    }
    private func exportSplit() {
        perform {
            _ = try review.validated(at: .now)
            let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
            panel.prompt = "分割TXTを保存"; panel.message = "1MiB以下の各partを省略せず渡してください。これはClaudeの対応上限ではありません。"
            panel.begin { response in
                guard response == .OK, let destination = panel.url else { return }
                perform {
                    let package = try review.validated(at: .now)
                    let files = try HandoffFiles.writeSplit(package, directory: handoff.directory)
                    handoff.reconcile(with: store, at: .now)
                    guard review.package != nil, handoff.maintenanceError == nil else { throw AIPackageError.unavailable }
                    let folder = destination.appending(path: "Feeeder-review-" + package.id.uuidString, directoryHint: .isDirectory)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                    for file in files { try FileManager.default.copyItem(at: file, to: folder.appending(path: file.lastPathComponent)) }
                }
            }
        }
    }
    private func perform(_ operation: () throws -> Void) { do { try operation(); error = nil } catch { self.error = error.localizedDescription } }
}

// A selectable native text preview keeps large packages out of a per-paragraph SwiftUI view graph.
private struct PackageTextView: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true
        let view = NSTextView(); view.isEditable = false; view.isSelectable = true
        view.isRichText = false; view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.autoresizingMask = [.width]; view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.setAccessibilityLabel("AI入力パッケージ全文")
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text; view.textColor = .labelColor
        view.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}
