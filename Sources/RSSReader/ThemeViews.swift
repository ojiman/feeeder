import SwiftUI
import ReaderCore

/// The [記事｜問い] switch at the top of a theme's center column.
struct ThemeFacePicker: View {
    @Binding var face: ThemeFace
    var body: some View {
        Picker("表示", selection: $face) {
            Text("記事").tag(ThemeFace.articles)
            Text("問い").tag(ThemeFace.questions)
        }
        .pickerStyle(.segmented).labelsHidden()
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
        .accessibilityLabel("テーマの表示")
    }
}

/// The questions face: the theme's "いまの理解" row first, then its questions. Row selection drives the right column.
struct ThemeQuestionsPane: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @Binding var face: ThemeFace
    @Binding var selection: ThemeQuestionSelection
    private var preview: String {
        let text = store.theme(id: themeID)?.understanding.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "まだ書かれていません" : text
    }
    var body: some View {
        List(selection: Binding<ThemeQuestionSelection?>(get: { selection }, set: { if let value = $0 { selection = value } })) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("いまの理解").font(.headline)
                    Text(preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } icon: { Image(systemName: "text.alignleft") }
                .padding(.vertical, 4).tag(ThemeQuestionSelection.understanding)
            Section("問い") {
                ForEach(store.questions(themeID: themeID), id: \.id) { question in
                    HStack(alignment: .top) {
                        Image(systemName: question.isAnswered ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(question.isAnswered ? Color.green : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(question.text).lineLimit(2)
                            Text(question.lens.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3).tag(ThemeQuestionSelection.question(question.id))
                    .accessibilityElement(children: .combine).accessibilityValue(question.isAnswered ? "回答済み" : "未回答")
                }
            }
        }
        .navigationTitle(store.theme(id: themeID)?.name ?? "テーマ")
        .navigationSubtitle("問い")
        .safeAreaInset(edge: .top) { ThemeFacePicker(face: $face) }
    }
}

/// Free-form, written by the person. Nothing else writes here (spec §3.3).
struct UnderstandingEditor: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @State private var error: String?
    var body: some View {
        if let theme = store.theme(id: themeID) {
            VStack(alignment: .leading, spacing: 12) {
                Text("いまの理解").font(.title2.bold())
                Text("このテーマについて、いま自分が理解していることを自分の言葉で書きます。AIは書き込みません。")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: Binding(get: { theme.understanding }, set: { text in
                    do { try store.saveUnderstanding(themeID: themeID, text: text, at: .now) } catch { self.error = error.localizedDescription }
                })).font(.body).accessibilityLabel("いまの理解")
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
            .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("閉じる") { error = nil }
            } message: { Text(error ?? "") }
        } else {
            ContentUnavailableView("テーマが見つかりません", systemImage: "questionmark.folder")
        }
    }
}
