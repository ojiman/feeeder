# Theme Questions Implementation Plan (PR 5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する（[決定0002](../../decisions/0002-single-supervised-writer.md)）。

**Goal:** テーマの「問い」面に、問いの一覧・レンズから問いを立てる操作・問いの編集・自分の答え・根拠の記事の選択と読書面への移動・回答済みの印を足し、AIなしで「Star→テーマ→問い→答え」を完結させる。

**Architecture:** 保存層（PR 3の`ThemeQuestion`と`setEvidence`など）はそのまま使う。選択状態（いまの理解／どの問い）は`ReaderWorkspaceState`が持つ。中央ペインは、問いの一覧・レンズ選択のポップオーバー・自由記述の問いと削除のダイアログを**自分で持ち**（`ReaderView`の連鎖は型検査の限界に近いため増やさない）、右カラムは選択に応じて「いまの理解」か問いの編集面を出す。

**Tech Stack:** Swift 6、SwiftUI、AppKit、SwiftData、Swift Testing。外部依存・AI・通信の追加なし。

**Spec:** [PRD](../../specification.md)第3.3節・第7節（PRD-04）、[決定0008](../../decisions/0008-theme-centered-notes.md)。ロードマップ: [テーマ中心のノート実装計画](2026-10-10-theme-notes.md)のPR 5。前提: PR 4（[#25](https://github.com/ojiman/feeeder/pull/25)、`main` `8735b9f`）。本計画はこのPRのマージで承認される。

## この計画で決めること（マージで承認される判断）

1. **問いを立てる入口**: 中央ペイン下部の「問いを立てる」ボタンが、ポップオーバーを開く。ポップオーバーには、5つのレンズ（前提を疑う／例外・反論／成り立つ条件／トレードオフ／自分の場合）のボタンと、「自由に書く…」がある。各レンズのボタンには、そのレンズの定型の問い（テーマ名を差し込んだもの）を説明として見せる。メニューではなくボタン一覧にするのは、説明を見せられ、キーボードでも辿れるため。
2. **レンズを選ぶと即座に問いができる**: レンズの定型文を下書きとして問いを作り、右カラムの編集面で書き換えて確定する。「自由に書く…」だけは、問いの文を入力するダイアログを先に出す（空の問いを保存しない）。
3. **問いの文は確定時に保存する**（入力欄を離れる／Returnのとき）。空にして確定した場合は、保存せず元の文へ戻し、理由を示す。答えは入力のたびに保存する（既存の保存経路と同じ）。
4. **根拠**: 右カラムの「根拠の記事」に、テーマの記事がチェック付きで並ぶ。チェックの切り替えは`setEvidence`で保存する。各行の「読む」で、テーマの記事面へ切り替えてその記事を選ぶ。記事をテーマから外すと根拠の紐付けだけが外れる（PR 3で実装済み）。
5. **問いの削除**は、一覧の右クリックから確認つきで行う。答えと根拠の紐付けは消えるが、記事は消えない。選択中の問いを消したら「いまの理解」へ戻る。
6. **選択状態はセッション内のみ**（面の記憶と同じ）。存在しない問いが選択されていたら「いまの理解」を出す。

## Global Constraints

- サポート下限macOS 27.0、ビルド下限26.6のまま。macOS 27 SDK専用のAPIを使わない（[決定0007](../../decisions/0007-support-floor-macos-27.md)）。外部依存・AI・通信を追加しない。
- 答え・いまの理解・問いの文に、AIや他の操作が自動で書き込まない。AIは使わない（PR 6・7）。
- テキスト入力・IME変換・修飾キー付き操作では、文字入力と標準操作を優先する。問いの面は読書面ではないので、`j/k/s/t`は効かない。
- 新しい変更経路は先頭で`reloadIfNeeded()`を呼び、失敗注入の試験を足す。UIはモデルの参照ではなくIDを持つ。保存失敗を成功扱いにしない。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・ブラウザprofileを使わない。実機確認は、**別Bundle IDのコピー**と一時データで行い、本人の`/Applications/Feeeder.app`を操作・撮影しない。
- 1PR1テーマ。失敗するテストを先に書き、失敗を確認してから実装する。**破壊試験の前に必ずコミットし、元に戻すときは該当の変更だけを戻す（ファイル全体の`git checkout`は使わない）。**
- シェルのループで変数を使うときはzshが単語分割しないことに注意し、引数は明示する。
- コミット／PRの末尾にはセッションが指定する共著表記を付ける。実装が完了したら、確認を待たずにブランチをpushしてPRを作る（`main`へのマージ・タグ・配布はしない）。

## Review Focus

1. 問いの文・答え・根拠が、保存失敗のときに失われた値を表示し続けない（入力欄を離れて確定に失敗したとき、元の文へ戻して理由を示す）→ Task 2。
2. 空白だけの問い・答えと、存在しない問い・テーマ・記事のID（削除済みの問いが選択に残る）で壊れない → Task 1・2。
3. 根拠にした記事をテーマから外した後、根拠の一覧・答えが壊れない → Task 2。
4. 問いを消したあとの選択（「いまの理解」へ戻る）、テーマを切り替えても選択が混ざらない → Task 1・3。
5. 「読む」で記事面へ移ったとき、選択した記事が読書面に出て、問い面へ戻ると同じ問いが選ばれている → Task 3（実機）。

---

### Task 1: 選択状態と、レンズから問いを立てるストア操作

**Files:**
- Modify: `Sources/ReaderCore/ReaderWorkspaceState.swift`、`Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ReaderWorkspaceTests.swift`、`Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: PR 3の`addQuestion(themeID:lens:text:at:)`、`QuestionLens.draft(themeName:)`、PR 4の`ReaderWorkspaceState`。
- Produces:
  - `ThemeQuestionSelection: Hashable, Sendable`（`.understanding`、`.question(UUID)`）
  - `ReaderWorkspaceState.questionSelection(of:) -> ThemeQuestionSelection`（既定は`.understanding`）、`selectQuestion(_:in:)`
  - `ReaderStore.addQuestion(themeID:lens:at:) throws -> ThemeQuestion`（`@discardableResult`。`.custom`以外のレンズの定型文を、そのテーマ名で差し込んだ問いを作る。`.custom`は`ThemeError.missingQuestionText`）

- [ ] **Step 1: 失敗するテストを書く**

`ReaderWorkspaceTests`の末尾（最後の`}`の前）に追加する。

```swift
    @Test func questionSelectionIsPerThemeAndDefaultsToUnderstanding() {
        var workspace = ReaderWorkspaceState()
        let first = UUID(), second = UUID(), question = UUID()
        #expect(workspace.questionSelection(of: first) == .understanding)
        workspace.selectQuestion(.question(question), in: first)
        #expect(workspace.questionSelection(of: first) == .question(question))
        #expect(workspace.questionSelection(of: second) == .understanding)
        workspace.selectQuestion(.understanding, in: first)
        #expect(workspace.questionSelection(of: first) == .understanding)
    }
```

`ThemeTests`の末尾に追加する。

```swift
    @Test func lensQuestionUsesTheThemeNameAndRejectsTheFreeLens() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "金利と家計", at: at)
        for lens in QuestionLens.allCases where lens != .custom {
            let question = try store.addQuestion(themeID: theme.id, lens: lens, at: at.addingTimeInterval(1))
            #expect(question.lens == lens && question.text == lens.draft(themeName: "金利と家計") && !question.isAnswered)
            #expect(question.text.contains("「金利と家計」"))
        }
        #expect(store.questions(themeID: theme.id).count == 5)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: theme.id, lens: .custom, at: at) }
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: UUID(), lens: .assumption, at: at) }
        try store.renameTheme(id: theme.id, to: "改名後", at: at)
        let renamed = try store.addQuestion(themeID: theme.id, lens: .condition, at: at.addingTimeInterval(2))
        #expect(renamed.text.contains("「改名後」"))
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter "ReaderWorkspaceTests|ThemeTests"`
Expected: FAIL（コンパイルエラー: `questionSelection`・`selectQuestion`・`addQuestion(themeID:lens:at:)`が未定義）

- [ ] **Step 3: 実装する**

`ReaderWorkspaceState.swift`に、`ThemeFace`の定義の直後へ追加する。

```swift
/// What the questions face has selected: the theme's "いまの理解" or one question.
public enum ThemeQuestionSelection: Hashable, Sendable { case understanding, question(UUID) }
```

`ReaderWorkspaceState`に、`themeFaces`の宣言の直後へ追加する。

```swift
    private var questionSelections: [UUID: ThemeQuestionSelection] = [:]
```

`face(of:)`の直後へ追加する。

```swift
    public func questionSelection(of themeID: UUID) -> ThemeQuestionSelection { questionSelections[themeID] ?? .understanding }
    public mutating func selectQuestion(_ selection: ThemeQuestionSelection, in themeID: UUID) { questionSelections[themeID] = selection }
```

`Themes.swift`の`addQuestion(themeID:lens:text:at:)`の直前に追加する。

```swift
    /// Starts a question from a fixed lens: the lens's draft with the theme's current name. The free lens needs text.
    @discardableResult public func addQuestion(themeID: UUID, lens: QuestionLens, at: Date) throws -> ThemeQuestion {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard lens != .custom else { throw ThemeError.missingQuestionText }
        return try addQuestion(themeID: themeID, lens: lens, text: lens.draft(themeName: theme.name), at: at)
    }
```

- [ ] **Step 4: 成功を確認し、全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS

```bash
git add Sources Tests
git commit -m "feat: 問いの選択状態と、レンズから問いを立てるストア操作を追加する"
```

---

### Task 2: 問いの一覧と、問いの編集面（問い・答え・根拠）

**Files:**
- Modify: `Sources/RSSReader/ThemeViews.swift`（`ThemeQuestionsPane`）、`Sources/RSSReader/ReaderView.swift`
- Create: `Sources/RSSReader/QuestionEditor.swift`
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`

**Interfaces:**
- Consumes: Task 1の`ThemeQuestionSelection`・`questionSelection(of:)`・`selectQuestion(_:in:)`、PR 3の`questions(themeID:)`・`updateQuestion`・`saveAnswer`・`setEvidence`・`themeArticleIDs(themeID:)`。
- Produces: `ThemeQuestionsPane(store:themeID:face:selection:)`（一覧）、`QuestionEditor(store:themeID:questionID:onOpenArticle:)`（編集面）、`ReaderView.init(..., initialQuestionSelection: ThemeQuestionSelection = .understanding)`（試験用の入口）。

- [ ] **Step 1: 失敗する統合テストを書く**

`ThemeReaderTests.swift`の`harness`の引数に`questionSelection: (ReaderStore) -> ThemeQuestionSelection = { _ in .understanding }`を足し、`ReaderView(...)`の呼び出しに`initialQuestionSelection: questionSelection(store)`を渡す。その上で、末尾に試験を追加する。

```swift
    @Test func questionFaceShowsTheSelectedQuestionsAnswer() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions,
                            questionSelection: { store in .question(store.themeQuestions[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            let question = try store.addQuestion(themeID: theme.id, lens: .assumption, at: .now)
            try store.saveAnswer(questionID: question.id, answer: "保存済みの自分の答え", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { containsText("保存済みの自分の答え", in: h.host) }
        #expect(!containsText("このテーマについて、いま自分が理解していること", in: h.host))
    }

    @Test func aMissingQuestionSelectionFallsBackToTheUnderstanding() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions,
                            questionSelection: { _ in .question(UUID()) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { containsText("既存のいまの理解", in: h.host) }
    }
```

（`containsText`は、PR 4で`ThemeReaderTests`に追加済みのヘルパー。）

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeReaderTests`
Expected: FAIL（コンパイルエラー: `initialQuestionSelection`が無い）

- [ ] **Step 3: `QuestionEditor.swift`を作る**

```swift
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
        catch { self.error = error.localizedDescription; draft = stored }
        if let saved = question?.text { draft = saved }
    }
}
```

- [ ] **Step 4: `ThemeQuestionsPane`を問いの一覧にする**

`ThemeViews.swift`の`ThemeQuestionsPane`を、次に置き換える（`ThemeFacePicker`と`UnderstandingEditor`は変更しない）。

```swift
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
```

- [ ] **Step 5: `ReaderView.swift`を変更する**

(a) `init`の引数に`initialQuestionSelection: ThemeQuestionSelection = .understanding`を足し、`initialWorkspace.scope = initialScope`の直後に追加する。

```swift
        if case .theme(let id) = initialScope { initialWorkspace.selectQuestion(initialQuestionSelection, in: id) }
```

(b) 詳細カラム。`UnderstandingEditor(store: store, themeID: id).id(id)`を含む`if case .theme(let id) = scope, workspace.face(of: id) == .questions { ... }`の本体を、次の1行に置き換える。

```swift
                questionsDetail(id)
```

(c) 中央カラム。`ThemeQuestionsPane(store: store, themeID: id, face: faceBinding(id)).id(id)`を次に置き換える。

```swift
            ThemeQuestionsPane(store: store, themeID: id, face: faceBinding(id), selection: questionSelectionBinding(id)).id(id)
```

(d) 補助。`faceBinding`の直前に追加する。

```swift
    /// A selection that points at a question that no longer exists shows the "いまの理解" instead.
    private func effectiveQuestionSelection(_ themeID: UUID) -> ThemeQuestionSelection {
        if case .question(let id) = workspace.questionSelection(of: themeID), store.themeQuestions.contains(where: { $0.id == id }) {
            return .question(id)
        }
        return .understanding
    }
    private func questionSelectionBinding(_ themeID: UUID) -> Binding<ThemeQuestionSelection> {
        Binding(get: { effectiveQuestionSelection(themeID) }, set: { workspace.selectQuestion($0, in: themeID) })
    }
    @ViewBuilder private func questionsDetail(_ themeID: UUID) -> some View {
        switch effectiveQuestionSelection(themeID) {
        case .understanding: UnderstandingEditor(store: store, themeID: themeID).id(themeID)
        case .question(let id): QuestionEditor(store: store, themeID: themeID, questionID: id, onOpenArticle: { openArticle($0, in: themeID) }).id(id)
        }
    }
    /// "読む": back to the articles face with that article selected.
    private func openArticle(_ articleID: UUID, in themeID: UUID) {
        setFace(.articles, of: themeID)
        selectArticle(articleID)
        listFocused = true
    }
```

- [ ] **Step 6: 成功を確認し、全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS。コンパイルが「型検査に時間がかかる」で失敗する場合は、`ReaderView`の連鎖を増やしていないか確認する（この計画の変更は、新しいモディファイアを足さない）。

```bash
git add Sources Tests
git commit -m "feat: テーマの問いの一覧と、問い・答え・根拠の編集面を追加する"
```

---

### Task 3: 問いを立てる・削除する

**Files:**
- Modify: `Sources/RSSReader/ThemeViews.swift`（`ThemeQuestionsPane`に、ポップオーバー・ダイアログ・右クリックを足す）
- Create: `Sources/RSSReader/LensChoiceView.swift`

**Interfaces:**
- Consumes: Task 1の`addQuestion(themeID:lens:at:)`、PR 3の`addQuestion(themeID:lens:text:at:)`・`deleteQuestion(id:at:)`、Task 2の`ThemeQuestionsPane`。
- Produces: 中央ペイン下部の「問いを立てる」ボタン、`LensChoiceView(themeName:onChoose:)`、問いの右クリック削除と確認。

このTaskのロジックは、Task 1（レンズから問いを立てる）とPR 3（削除）でテスト済み。画面の配線は、Task 4の実機確認で確かめる。

- [ ] **Step 1: `LensChoiceView.swift`を作る**

```swift
import SwiftUI
import ReaderCore

/// The popover behind "問いを立てる": one button per fixed lens, showing the question it would start with.
struct LensChoiceView: View {
    let themeName: String
    let onChoose: (QuestionLens) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("どの角度から問いますか").font(.headline)
            ForEach(QuestionLens.allCases.filter { $0 != .custom }, id: \.self) { lens in
                Button { onChoose(lens) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lens.title).font(.callout.weight(.semibold))
                        Text(lens.draft(themeName: themeName)).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lens.title)から問いを立てる")
            }
            Divider()
            Button { onChoose(.custom) } label: {
                Label("自由に書く…", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("自由に書いた問いを立てる")
        }
        .padding(14).frame(width: 320)
    }
}
```

- [ ] **Step 2: `ThemeQuestionsPane`に操作を足す**

状態を足す（`@Binding var selection`の直後）。

```swift
    @State private var choosingLens = false
    @State private var writingQuestion = false
    @State private var customText = ""
    @State private var deletingQuestion: UUID?
    @State private var error: String?
```

問いの行（`.tag(ThemeQuestionSelection.question(question.id))`の行の直後）に右クリックを足す。

```swift
                    .contextMenu { Button("問いを削除…", role: .destructive) { deletingQuestion = question.id } }
```

`.safeAreaInset(edge: .top) { ThemeFacePicker(face: $face) }`の直後に、次を足す。

```swift
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
            TextField("問い", text: $customText)
            Button("作成") { create(.custom, text: customText) }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("このテーマで考えたい問いを、自分の言葉で書きます。") }
        .confirmationDialog("この問いを削除しますか？", isPresented: Binding(get: { deletingQuestion != nil }, set: { if !$0 { deletingQuestion = nil } })) {
            Button("問いを削除", role: .destructive) { delete() }
        } message: { Text("自分の答えと、根拠の紐付けが消えます。記事は消えません。") }
        .alert("保存できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("閉じる") { error = nil }
        } message: { Text(error ?? "") }
```

`ThemeQuestionsPane`の末尾（`body`の後）に、操作の関数を足す。

```swift
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
```

- [ ] **Step 3: 全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS（コンパイルできること、既存の試験が壊れていないこと）

```bash
git add Sources
git commit -m "feat: レンズから問いを立てる操作と、問いの削除を追加する"
```

---

### Task 4: 実機確認・文書・検証記録・レビュー・PR

**Files:**
- Modify: `README.md`、`docs/specification.md`（冒頭の実装状況の注記）、`docs/architecture.md`（§6.1の問い面の記述が必要なら）、`docs/superpowers/plans/2026-10-10-theme-notes.md`（ロードマップのPR 5の行）
- Create: `docs/verification/YYYY-MM-DD-theme-questions.md`（YYYY-MM-DDは実行日）

- [ ] **Step 1: Releaseビルドと全体の検査**

```bash
bash scripts/build-app.sh release
swift test --scratch-path /private/tmp/feeeder-dogfooding-build
git diff --check origin/main
```

Expected: すべて成功。

- [ ] **Step 2: 合成インスタンスで実操作して確認する**

PR 4と同じ手順で、**別Bundle IDのコピー**を作って起動する（本人の`/Applications/Feeeder.app`と区別するため。`pgrep -fl RSSReader`で、`--data-directory`が一時ディレクトリのプロセスだけを操作対象にする）。

```bash
D=/private/tmp/feeeder-q-demo-app; rm -rf "$D" /private/tmp/feeeder-q-demo; mkdir -p "$D"
ditto .build/Feeeder.app "$D/FeeederQDemo.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier jp.ojiman.Feeeder.Questions.20261010" -c "Set :CFBundleName FeeederQDemo" -c "Set :CFBundleDisplayName FeeederQDemo" "$D/FeeederQDemo.app/Contents/Info.plist"
codesign --force --sign - "$D/FeeederQDemo.app"
open -n "$D/FeeederQDemo.app" --args --data-directory /private/tmp/feeeder-q-demo --seed-demo
pgrep -fl RSSReader
```

操作の許可は`jp.ojiman.Feeeder.Questions.20261010`だけに限る。確認する操作と期待:

1. テーマを作り、記事を2件入れる。「問い」面へ切り替える。一覧に「いまの理解」と、空の「問い」区画、下部に「問いを立てる」ボタンが出る。
2. 「問いを立てる」でポップオーバーが開き、5つのレンズと「自由に書く…」が並ぶ。「前提を疑う」を押すと、問いが一覧に追加され、選択され、右カラムに問い（テーマ名入り）・答え・根拠の記事が出る。
3. 問いの文を書き換えて入力欄を離れると、一覧が更新される。空にして離れると元へ戻り、理由が出る。
4. 答えを書くと、一覧の印が「回答済み」に変わる。再起動しても残る。
5. 根拠の記事にチェックを入れる／外す。「読む」を押すと、記事面へ切り替わり、その記事が選ばれる。「問い」へ戻ると、同じ問いが選ばれている。
6. 「自由に書く…」でダイアログが出て、書いた問いが作られる。
7. 問いを右クリックして削除（右クリックメニューが操作ツールで開けない場合は、未検証として残す）。削除後は「いまの理解」へ戻る。
8. 別のテーマへ移っても、選択が混ざらない。

確認できなかったものは未検証として残す。確認後は、検証用アプリを終了し（対象のpidを確認してから`kill`）、一時ディレクトリを削除し、操作権限を解放する。

- [ ] **Step 3: 文書を更新する**

- `README.md`: テーマの説明に、問い・レンズ・答え・根拠・回答済みの印を足す（「問い・レンズ・答えは次の更新で追加します」を削除）。
- `docs/specification.md`冒頭の注記: 「未実装」から問い・レンズ・答え・根拠を外し、「実装済み」に足す。
- ロードマップのPR 5の行は、そのままで良ければ変更しない。

- [ ] **Step 4: 検証記録を書く**

`docs/verification/YYYY-MM-DD-theme-questions.md`に、対象commit、環境、コマンドと結果（PASS／FAIL／NOT_RUN）、テスト件数、Step 2で確認した操作と結果、**未検証**（IME変換中の問い・答えの入力、VoiceOver、右クリック削除、問いが多数あるときの表示、長い問い文）を書く。

- [ ] **Step 5: 独立レビューを依頼する**

保存データ（答え・根拠）の扱いを含むため、固定commitに対して`docs/review-checklist.md`の観点で独立レビューを依頼する（読み取り専用。アプリは起動させない）。指摘は効果で再評価し、Critical・Importantは失敗するテストを先に確認して直す。

- [ ] **Step 6: コミットし、pushしてPRを作る**

```bash
git add README.md docs
git commit -m "docs: 問い・答え・根拠の実装状況と検証記録を反映する"
git push -u origin <branch>
gh pr create --base main --head <branch>
```

PR本文は`.github/pull_request_template.md`に従う。**含めないもの**: 端末内AI（PR 6・7）、Claude連携の入口（PR 8）、問いの並べ替え、レンズの追加・編集。**未検証**: Step 4の一覧。
