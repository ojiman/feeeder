import SwiftUI
import ReaderCore

struct FolderOrganizationSheet: View {
    @Bindable var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var feedID: UUID?
    @State private var folder = ""
    @State private var error: String?
    private var folders: [String] { Array(Set(store.feeds.map(\.folder).filter { !$0.isEmpty })).sorted() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("フォルダを整理").font(.title2.bold())
            Text("テーマごとに購読をまとめ、左カラムのフォルダから読めます。")
                .font(.callout).foregroundStyle(.secondary)
            Picker("購読元", selection: $feedID) {
                ForEach(store.feeds) { feed in Text(feed.title).tag(Optional(feed.id)) }
            }
            HStack {
                TextField("フォルダ名（空欄は未分類）", text: $folder)
                Menu("既存から選ぶ") {
                    Button("未分類") { folder = "" }
                    ForEach(folders, id: \.self) { name in Button(name) { folder = name } }
                }
            }
            Text("新しいテーマ名を入力すると、そのフォルダへ移動します。フォルダは1階層です。")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("キャンセル") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("移動") {
                    guard let feedID else { return }
                    do { try store.moveFeed(id: feedID, toFolder: folder); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.keyboardShortcut(.defaultAction).disabled(feedID == nil)
            }
        }.padding(24).frame(width: 520)
        .onAppear { feedID = store.feeds.first?.id; folder = store.feeds.first?.folder ?? "" }
        .onChange(of: feedID) { _, id in folder = id.flatMap { store.feed(id: $0)?.folder } ?? ""; error = nil }
    }
}
