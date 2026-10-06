import SwiftUI
import ReaderCore

enum NotePane { case list, detail }

struct DailyNotesView: View {
    @Bindable var store: ReaderStore
    @Binding var noteID: UUID?
    let pane: NotePane
    @State private var error: String?
    @State private var deletingNote = false
    @State private var removingScrap: String?
    private var note: DailyNote? { store.dailyNotes.first { $0.id == noteID } }
    var body: some View {
        Group {
            if pane == .list {
                List(selection: $noteID) {
                    ForEach(store.dailyNotes) { note in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(note.title).font(.headline)
                            Text("\(store.scraps.filter { $0.noteID == note.id }.count)件のスクラップ · \(note.timeZoneID)").font(.caption).foregroundStyle(.secondary)
                        }.tag(note.id)
                    }
                }.navigationTitle("日次ノート")
            } else if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text(note.title).font(.title2.bold()); Spacer(); Button("ノートを削除…", role: .destructive) { deletingNote = true } }
                        Text("\(note.day) (\(note.timeZoneID)) · 自動削除しません").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: Binding(get: { note.text }, set: { text in perform { try store.saveDailyNote(id: note.id, text: text, at: .now) } }))
                            .frame(minHeight: 160).accessibilityLabel("日次ノート本文")
                        Divider()
                        ForEach(store.scraps.filter { $0.noteID == note.id }, id: \.key) { scrap in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(scrap.title).font(.headline)
                                if let url = scrap.url.flatMap({ ArticleURL.validated($0) }) { Link(url.host ?? "出典", destination: url) }
                                Text(scrap.savedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                                if scrap.summary.isEmpty { Text("保存時のRSS要約なし · タイトルとリンクを保存").font(.caption).foregroundStyle(.secondary) }
                                else { DisclosureGroup("保存時のRSS要約") { Text(scrap.summary).textSelection(.enabled) } }
                                TextField("自分のメモ", text: Binding(get: { scrap.memo }, set: { memo in perform { try store.saveScrapMemo(key: scrap.key, memo: memo, at: .now) } }), axis: .vertical)
                                    .textFieldStyle(.roundedBorder).accessibilityLabel("スクラップのメモ")
                                Button("スクラップを削除…", role: .destructive) { removingScrap = scrap.key }.font(.caption)
                            }
                            Divider()
                        }
                    }.padding(24)
                }
            } else { ContentUnavailableView("当日のノートはまだありません", systemImage: "square.and.pencil", description: Text("記事で n を押すと、当日のノートに保存できます。過去のノートは中央で選択できます。")) }
        }
        .confirmationDialog("この日次ノートとスクラップを削除しますか？", isPresented: $deletingNote) {
            Button("日次ノートを削除", role: .destructive) { if let note { perform { try store.deleteDailyNote(id: note.id); noteID = nil } } }
        } message: { Text("週ノートに採用済みの出典は残ります。") }
        .confirmationDialog("このスクラップを削除しますか？", isPresented: Binding(get: { removingScrap != nil }, set: { if !$0 { removingScrap = nil } })) {
            Button("スクラップを削除", role: .destructive) { if let key = removingScrap { perform { try store.removeScrap(key: key) }; removingScrap = nil } }
        }
        .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("閉じる") { error = nil } } message: { Text(error ?? "") }
    }
    private func perform(_ operation: () throws -> Void) { do { try operation() } catch { self.error = error.localizedDescription } }
}
