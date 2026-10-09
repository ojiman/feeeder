import SwiftUI
import ReaderCore

/// The right column for one question: the question text, the person's own answer, and the evidence articles.
/// The answer saves on every change; the question text saves when the field is left or on Return.
struct QuestionEditor: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    let questionID: UUID
    let onOpenArticle: (UUID) -> Void
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var textFocused: Bool

    private var question: ThemeQuestion? { store.themeQuestions.first { $0.id == questionID } }

    var body: some View {
        if let question {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(question.lens.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("問い", text: $draft, axis: .vertical)
                        .font(.title3.weight(.semibold)).lineLimit(1...5)
                        .focused($textFocused).onSubmit(commitText)
                        .accessibilityLabel("問い")
                    Divider()
                    Text("自分の答え").font(.headline)
                    Text("答えは自分の言葉で書きます。AIは書き込みません。").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: Binding(get: { question.answer }, set: saveAnswer))
                        .font(.body).frame(minHeight: 180).accessibilityLabel("自分の答え")
                    Divider()
                    evidence(question)
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear { draft = question.text }
            .onChange(of: textFocused) { _, focused in if !focused { commitText() } }
            .onDisappear(perform: commitText)
            .onChange(of: question.text) { _, text in if !textFocused { draft = text } }
            .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("閉じる") { error = nil }
            } message: { Text(error ?? "") }
        } else {
            ContentUnavailableView("問いが見つかりません", systemImage: "questionmark.circle")
        }
    }

    private func evidence(_ question: ThemeQuestion) -> some View {
        let ids = store.themeArticleIDs(themeID: themeID)
        return VStack(alignment: .leading, spacing: 8) {
            Text("根拠の記事").font(.headline)
            if ids.isEmpty {
                Text("テーマに記事を入れると、ここで根拠にできます。").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(ids, id: \.self) { id in
                if let article = store.article(id: id) {
                    HStack(alignment: .firstTextBaseline) {
                        Toggle(isOn: Binding(get: { question.evidenceArticleIDs.contains(id) }, set: { setEvidence(id, on: $0) })) {
                            Text(article.title).lineLimit(2)
                        }
                        Spacer()
                        Button("読む") { onOpenArticle(id) }.buttonStyle(.link)
                            .accessibilityLabel("記事「\(article.title)」を読む")
                    }
                }
            }
        }
    }

    private func saveAnswer(_ text: String) {
        do { try store.saveAnswer(questionID: questionID, answer: text, at: .now) } catch { self.error = error.localizedDescription }
    }
    private func setEvidence(_ articleID: UUID, on: Bool) {
        guard let current = question?.evidenceArticleIDs else { return }
        let next = on ? current + [articleID] : current.filter { $0 != articleID }
        do { try store.setEvidence(questionID: questionID, articleIDs: next, at: .now) } catch { self.error = error.localizedDescription }
    }
    /// A blank question is never saved: the stored text comes back and the reason is shown.
    private func commitText() {
        guard let stored = question?.text, draft.trimmingCharacters(in: .whitespacesAndNewlines) != stored else { return }
        do { try store.updateQuestion(id: questionID, text: draft, at: .now) }
        catch { self.error = error.localizedDescription }
        if let saved = question?.text { draft = saved }
    }
}
