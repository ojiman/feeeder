import SwiftUI
import ReaderCore

struct WeeklyNotesView: View {
    @Bindable var store: ReaderStore
    @Bindable var aiReview: AIPackageReview
    @Bindable var handoff: ClaudeHandoffController
    var onReturn: () -> Void
    @State private var weekKey: String?
    @State private var noteID: UUID?
    @State private var draft = ""
    @State private var newTitle = ""
    @State private var deletingNote: WeeklyNote?
    @State private var error: String?
    @State private var reviewingWeek = false

    private var options: [WeekRange] {
        let current = WeekCalendar.range(containing: .now, timeZone: .current)
        let previous = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: .current)
        var values = Dictionary(uniqueKeysWithValues: store.weeks.map { ($0.weekKey, $0.range) })
        for range in [previous, current] where values[range.startDay] == nil { values[range.startDay] = range }
        return values.values.sorted { $0.start > $1.start }
    }
    private var range: WeekRange? { options.first { $0.startDay == weekKey } }
    private var period: WeeklyPeriod? { store.weeks.first { $0.weekKey == weekKey } }
    private var weekNotes: [WeeklyNote] { store.notes.filter { $0.weekID == period?.id } }
    private var note: WeeklyNote? { store.notes.first { $0.id == noteID } }

    var body: some View {
        NavigationSplitView {
            List(selection: $weekKey) {
                ForEach(options, id: \.startDay) { range in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(range.startDay)〜\(range.endDay)")
                        Text(range.timeZoneID + (range.end > .now ? " · 下書き" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }.tag(range.startDay)
                }
            }.navigationTitle("振り返り")
        } content: {
            List(selection: $noteID) {
                ForEach(weekNotes) { note in
                    Label(note.title, systemImage: note.isDefault ? "doc.text" : "doc")
                        .tag(note.id)
                }
            }
            .navigationTitle("ノート")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("新しいノートの名前", text: $newTitle)
                    Button("追加") { createNote() }.disabled(range == nil)
                }.padding()
            }
        } detail: {
            if let note {
                VStack(alignment: .leading, spacing: 12) {
                    Text(note.title).font(.title2.bold())
                    if let range { Text("\(range.startDay)〜\(range.endDay) (\(range.timeZoneID))").foregroundStyle(.secondary) }
                    TextEditor(text: $draft).font(.body).accessibilityLabel("ノート本文")
                        .onChange(of: draft) { _, text in
                            guard note.id == noteID, text != note.text else { return }
                            perform { try store.saveNote(id: note.id, text: text, at: .now) }
                        }
                    HStack {
                        Text("端末に保存 · 自動削除しません").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("削除", role: .destructive) { deletingNote = note }
                    }
                    Divider()
                    Text("採用済みの出典").font(.headline)
                    ForEach(store.noteSources.filter { $0.noteID == note.id }, id: \.key) { source in
                        if let url = source.url.flatMap({ ArticleURL.validated($0) }) { Link(source.title, destination: url) }
                        else { Text(source.title).foregroundStyle(.secondary) }
                    }
                    if let range {
                        DisclosureGroup("この週に読んだ記事（\(store.candidates(in: range).count)件）") {
                            ForEach(store.candidates(in: range)) { article in
                                HStack {
                                    Text(article.title).lineLimit(1)
                                    Spacer()
                                    Button("出典に追加") { perform { try store.adoptSources(noteID: note.id, articleIDs: [article.id]) } }
                                }
                            }
                        }
                    }
                }.padding(24)
            } else { ContentUnavailableView("週のノートを作成", systemImage: "square.and.pencil", description: Text("ノート名を入力して追加してください。AIを使わず編集できます。")) }
        }
        .toolbar {
            Button("読書に戻る", systemImage: "arrow.left", action: onReturn)
            Button("この週のAI入力を確認", systemImage: "doc.text.magnifyingglass") { reviewingWeek = true }.disabled(range == nil)
        }
        .sheet(isPresented: $reviewingWeek) {
            if let range { AIReviewView(store: store, review: aiReview, handoff: handoff, articleIDs: store.candidates(in: range).map(\.id)) }
        }
        .onAppear {
            if weekKey == nil {
                let current = WeekCalendar.range(containing: .now, timeZone: .current)
                weekKey = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: .current).startDay
            }
        }
        .onChange(of: weekKey) { _, _ in noteID = weekNotes.first?.id }
        .onChange(of: noteID) { _, _ in draft = note?.text ?? "" }
        .confirmationDialog("\(deletingNote?.title ?? "ノート")を削除しますか？", isPresented: Binding(get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } })) {
            Button("ノートを削除", role: .destructive) {
                guard let id = deletingNote?.id else { return }
                perform { try store.deleteNote(id: id) }; deletingNote = nil; noteID = weekNotes.first?.id
            }
        }
        .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("閉じる") { error = nil }
        } message: { Text(error ?? "") }
    }
    private func createNote() {
        guard let range else { return }
        perform { noteID = try store.createNote(in: range, title: newTitle, at: .now).id; newTitle = "" }
    }
    private func perform(_ operation: () throws -> Void) { do { try operation() } catch { self.error = error.localizedDescription } }
}
