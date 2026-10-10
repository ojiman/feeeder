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
    var onEditGoal: () -> Void = {}
    @State private var choosingLens = false
    @State private var writingQuestion = false
    @State private var customText = ""
    @State private var deletingQuestion: UUID?
    @State private var error: String?
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
                    .contextMenu { Button("問いを削除…", role: .destructive) { deletingQuestion = question.id } }
                }
            }
        }
        .navigationTitle(store.theme(id: themeID)?.name ?? "テーマ")
        .navigationSubtitle("問い")
        .safeAreaInset(edge: .top) { VStack(spacing: 0) { ThemeFacePicker(face: $face); ThemeGoalStrip(goal: store.theme(id: themeID)?.goal ?? "", onEdit: onEditGoal) } }
        .safeAreaInset(edge: .bottom) {
            Button { choosingLens = true } label: { Label("問いを立てる", systemImage: "plus").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).padding(10).background(.bar)
                .popover(isPresented: $choosingLens, arrowEdge: .top) {
                    LensChoiceView(themeName: store.theme(id: themeID)?.name ?? "") { lens in
                        choosingLens = false
                        if lens == .custom { customText = ""; writingQuestion = true } else { create(lens, text: nil) }
                    }
                }
                .accessibilityLabel("問いを立てる")
        }
        .alert("自由に書いた問い", isPresented: $writingQuestion) {
            TextField("問い", text: $customText.singleLine())
            Button("作成") { create(.custom, text: customText) }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("このテーマで考えたい問いを、自分の言葉で書きます。") }
        .confirmationDialog("この問いを削除しますか？", isPresented: Binding(get: { deletingQuestion != nil }, set: { if !$0 { deletingQuestion = nil } })) {
            Button("問いを削除", role: .destructive) { delete() }
        } message: { Text("自分の答えと、根拠の紐付けが消えます。記事は消えません。") }
        .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("閉じる") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func create(_ lens: QuestionLens, text: String?) {
        do {
            let question = try text.map { try store.addQuestion(themeID: themeID, lens: lens, text: $0, at: .now) }
                ?? store.addQuestion(themeID: themeID, lens: lens, at: .now)
            selection = .question(question.id)
        } catch { self.error = error.localizedDescription }
    }
    private func delete() {
        guard let id = deletingQuestion else { return }
        deletingQuestion = nil
        do {
            try store.deleteQuestion(id: id, at: .now)
            if selection == .question(id) { selection = .understanding }
        } catch { self.error = error.localizedDescription }
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

/// The theme's goal under the face switch. An empty goal is a quiet invitation to write one.
struct ThemeGoalStrip: View {
    let goal: String
    let onEdit: () -> Void
    var body: some View {
        Button(action: onEdit) {
            Group {
                if goal.isEmpty { Text("ゴールを書く…").foregroundStyle(.tertiary) }
                else { Text(goal).foregroundStyle(.secondary).lineLimit(2) }
            }
            .font(.caption).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8).background(.bar)
        .accessibilityLabel(goal.isEmpty ? "学習ゴールを書く" : "学習ゴール: \(goal)").accessibilityHint("名前とゴールを編集")
    }
}
