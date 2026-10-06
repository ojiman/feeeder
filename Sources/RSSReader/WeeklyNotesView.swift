import SwiftUI
import ReaderCore

struct WeeklyNotesView: View {
    @Bindable var store: ReaderStore
    @Bindable var aiReview: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    @Binding var weekKey: String
    @Binding var noteID: UUID?
    let pane: NotePane
    @State private var newTitle = ""
    @State private var deletingNote = false
    @State private var error: String?
    @State private var reviewingWeek = false
    @State private var chosenScraps: [UUID: String] = [:]
    private var options: [WeekRange] { store.availableWeeks(at: .now, timeZone: .current) }
    private var range: WeekRange? { options.first { $0.startDay == weekKey } }
    private var period: WeeklyPeriod? { store.weeks.first { $0.weekKey == weekKey } }
    private var weekNotes: [WeeklyNote] { store.notes.filter { $0.weekID == period?.id } }
    private var note: WeeklyNote? { store.notes.first { $0.id == noteID } }
    var body: some View {
        Group {
            if pane == .list {
                VStack(spacing: 0) {
                    Picker("週", selection: $weekKey) {
                        ForEach(options, id: \.startDay) { range in Text("\(range.startDay)〜\(range.endDay) (\(range.timeZoneID))").tag(range.startDay) }
                    }.padding(12)
                    List(selection: $noteID) {
                        ForEach(weekNotes) { note in Label(note.title, systemImage: note.isDefault ? "doc.text" : "doc").tag(note.id) }
                    }
                    HStack { TextField("新しいノートの名前", text: $newTitle); Button("追加") { createNote() }.disabled(range == nil) }.padding()
                }.navigationTitle("週ノート")
                .onChange(of: weekKey) { _, _ in noteID = weekNotes.first?.id }
                .onAppear { if noteID == nil { noteID = weekNotes.first?.id } }
            } else if let note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text(note.title).font(.title2.bold()); Spacer(); Button("AI入力を確認", systemImage: "doc.text.magnifyingglass") { reviewingWeek = true } }
                        if let range { Text("\(range.startDay)〜\(range.endDay) (\(range.timeZoneID))").font(.caption).foregroundStyle(.secondary) }
                        TextEditor(text: Binding(get: { note.text }, set: { text in perform { try store.saveNote(id: note.id, text: text, at: .now) } }))
                            .frame(minHeight: 220).accessibilityLabel("週ノート本文")
                        HStack { Text("端末に保存 · 自動削除しません").font(.caption).foregroundStyle(.secondary); Spacer(); Button("ノートを削除…", role: .destructive) { deletingNote = true } }
                        Divider(); Text("採用済みの出典").font(.headline)
                        ForEach(store.noteSources.filter { $0.noteID == note.id }, id: \.key) { source in
                            VStack(alignment: .leading, spacing: 6) {
                                if let url = source.url.flatMap({ ArticleURL.validated($0) }) { Link(source.title, destination: url) } else { Text(source.title) }
                                if let summary = source.summary { Text(summary.isEmpty ? "保存時のRSS要約なし" : summary).font(.callout).textSelection(.enabled) }
                            }
                        }
                        if let range {
                            Divider(); Text("この週に残した関心").font(.headline)
                            ForEach(store.weeklyCandidates(in: range), id: \.articleID) { candidate in candidateRow(candidate, note: note) }
                            DisclosureGroup("既読の履歴（\(store.candidates(in: range).count)件）") {
                                ForEach(store.candidates(in: range)) { article in
                                    HStack { Text(article.title).lineLimit(1); Spacer(); Button("出典に追加") { perform { try store.adoptSources(noteID: note.id, articleIDs: [article.id]) } } }
                                }
                            }
                        }
                    }.padding(24)
                }
            } else { ContentUnavailableView("週のノートを作成", systemImage: "square.and.pencil", description: Text("中央で週を選び、ノートを追加してください。")) }
        }
        .sheet(isPresented: $reviewingWeek) {
            if let range {
                AIReviewView(store: store, review: aiReview, handoff: handoff, selections:
                    store.noteSources.filter { $0.noteID == noteID }.flatMap { [.noteSource($0.key), .article($0.articleID)] } +
                    store.weeklyCandidates(in: range).flatMap { candidate in candidate.scraps.map { .scrap($0.key) } + [.article(candidate.articleID)] })
            }
        }
        .confirmationDialog("この週ノートを削除しますか？", isPresented: $deletingNote) {
            Button("週ノートを削除", role: .destructive) { if let note { perform { try store.deleteNote(id: note.id); noteID = weekNotes.first?.id } } }
        }
        .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("閉じる") { error = nil } } message: { Text(error ?? "") }
    }
    private func candidateRow(_ candidate: WeeklyCandidate, note: WeeklyNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(candidate.scraps.first?.title ?? store.article(id: candidate.articleID)?.title ?? "出典").font(.headline)
            if !candidate.scraps.isEmpty {
                Picker("保存時の要約", selection: Binding(get: { chosenScraps[candidate.articleID] ?? candidate.scraps[0].key }, set: { chosenScraps[candidate.articleID] = $0 })) {
                    ForEach(candidate.scraps, id: \.key) { scrap in Text(scrap.savedAt.formatted()).tag(scrap.key) }
                }
                if let selected = candidate.scraps.first(where: { $0.key == (chosenScraps[candidate.articleID] ?? candidate.scraps[0].key) }) { Text(selected.summary.isEmpty ? "保存時のRSS要約なし" : selected.summary).font(.caption).lineLimit(4) }
            } else { Text("Starを付けた記事").font(.caption).foregroundStyle(.secondary) }
            Button("出典に採用") {
                perform {
                    if let key = chosenScraps[candidate.articleID] ?? candidate.scraps.first?.key { try store.adoptScraps(noteID: note.id, scrapKeys: [key]) }
                    else { try store.adoptSources(noteID: note.id, articleIDs: [candidate.articleID]) }
                }
            }.disabled(store.noteSources.contains { $0.noteID == note.id && $0.articleID == candidate.articleID })
        }.padding(.vertical, 8)
    }
    private func createNote() { guard let range else { return }; perform { noteID = try store.createNote(in: range, title: newTitle, at: .now).id; newTitle = "" } }
    private func perform(_ operation: () throws -> Void) { do { try operation() } catch { self.error = error.localizedDescription } }
}
