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
                Text("本文\(preview.bodyCount)件・RSS要約\(preview.summaryCount)件、約\(byteCount(preview.estimatedBytes))が削除対象です。ノートと出典は残ります。削除した本文は保持期間を延長しても復元されません。")
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
            Text("ノートと採用済み出典タイトル・リンクは自動削除しません。")
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
