import SwiftUI
import ReaderCore

struct ReaderSettingsView: View {
    @Bindable var store: ReaderStore
    @Binding var appearance: String
    @State private var days = 30
    @State private var pendingDays: Int?
    @State private var deletingAll = false
    @State private var preview: DeletionPreview?
    @State private var error: String?

    var body: some View {
        TabView {
            Form {
                Picker("外観", selection: $appearance) {
                    Text("システムに合わせる").tag("system")
                    Text("ライト").tag("light")
                    Text("ダーク").tag("dark")
                }.pickerStyle(.segmented)
                Text("システムに合わせると、Macの外観設定に追従します。")
                    .font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped).padding()
                .tabItem { Label("外観", systemImage: "circle.lefthalf.filled") }
            storage
                .tabItem { Label("保存", systemImage: "externaldrive") }
            OnDeviceAISettingsView()
                .tabItem { Label("端末内AI", systemImage: "sparkles") }
        }.frame(width: 520, height: 340)
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .onAppear { days = store.retentionDays }
        .onChange(of: days) { _, value in
            guard value != store.retentionDays else { return }
            if value < store.retentionDays {
                perform { preview = try store.previewDeletion(days: value, allContent: false, at: .now); pendingDays = value }
            } else { perform { try store.applyRetention(days: value, at: .now) } }
        }
        .confirmationDialog(deletingAll ? "本文・RSS要約を削除しますか？" : "保持期間を\(pendingDays ?? days)日に変更しますか？",
                            isPresented: Binding(get: { preview != nil }, set: { if !$0 { cancel() } })) {
            Button(deletingAll ? "本文・RSS要約を削除" : "保持期間を変更", role: .destructive) {
                perform {
                    if deletingAll {
                        let current = try store.previewDeletion(days: nil, allContent: true, at: .now)
                        try store.deleteContent(articleIDs: current.articleIDs, at: .now)
                    } else if let pendingDays { try store.applyRetention(days: pendingDays, at: .now) }
                }
                cancel()
            }
            Button("キャンセル", role: .cancel) { cancel() }
        } message: {
            if let preview {
                Text("本文\(preview.bodyCount)件・RSS要約\(preview.summaryCount)件、約\(byteCount(preview.estimatedBytes))が削除対象です。テーマの記録は残ります。削除した本文は保持期間を延長しても復元されません。")
            }
        }
        .alert("変更できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("閉じる") { error = nil }
        } message: { Text(error ?? "") }
    }
    private var storage: some View {
        Form {
            Picker("記事本文・RSS要約の保持期間", selection: $days) {
                ForEach(RetentionPolicy.choices, id: \.self) { Text("\($0)日").tag($0) }
            }
            Text("未読は初回受信、読んだ記事は初回既読から数えます。再取り込みで期限を延長しません。")
                .font(.caption).foregroundStyle(.secondary)
            Text("テーマの記録（記事のタイトル・リンク・記録した要約、ノート）は自動削除しません。")
            Button("記事本文・RSS要約をすべて削除…", role: .destructive) {
                perform { preview = try store.previewDeletion(days: nil, allContent: true, at: .now); deletingAll = true }
            }
        }
        .formStyle(.grouped).padding()
    }
    private func byteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file; formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
    private func cancel() { preview = nil; pendingDays = nil; deletingAll = false; days = store.retentionDays }
    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { self.error = error.localizedDescription; days = store.retentionDays }
    }
}

/// One place for the switch's key and default, shared by Settings, the reader and the model.
enum OnDeviceAISetting {
    static let key = "onDeviceAIEnabled"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

struct OnDeviceAISettingsView: View {
    @AppStorage(OnDeviceAISetting.key) private var enabled = true
    @State private var availability: AssistantAvailability?

    var body: some View {
        Form {
            Toggle("端末内AIを使う", isOn: $enabled)
            Text("記事の要約を作るときに、この Mac の中だけで使います。外部へ送らず、アカウントも要りません。使わなくても、すべての操作ができます。")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("状態") { Text(statusText) }
            Text("言語の資産が端末に無い場合、アプリは自動で取得しません。AIが使えないだけで、ほかの操作は変わりません。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped).padding()
        .task(id: enabled) { availability = enabled ? await FoundationModelsGenerator().generationAvailability() : nil }
    }
    private var statusText: String {
        guard enabled else { return "オフ" }
        return switch availability {
        case nil: "確認中…"
        case .available: "使えます"
        case .assetsMissing: "モデルの準備中です"
        case .unsupported: "この環境では使えません"
        }
    }
}
