# 端末内AI②: テーマ名の案・問いの具体化（PR 7）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する（[決定0002](../../decisions/0002-single-supervised-writer.md)）。

**Goal:** まとまりからテーマを作るときの「名前の案」と、レンズから立てた問いの「具体化した案」を、端末内の言語モデル（`FoundationModels`）で出す。案は別のカードに出るだけで、本人が「使う／採用」を押すまで何も書き換えない。モデルが使えない・失敗する・出力が崩れているときは、案が出ないだけで、手動の操作は何も変わらない。

**Architecture:** 文字の整形（名前・問いの検査）、プロンプトの組み立て、案を出してよい状態の判定は、`ReaderCore`の純粋関数にする。`ThemeAssistant`に「テキスト生成」を1つ足し（`generate(_:)`）、`ThemeSuggestionModel`が入力を集め、出力を検査し、古い応答・無効化後の応答を捨てる。実物は、アプリ側の`FoundationModels`（プレーンテキスト応答、出力トークン上限、10秒の期限）。画面は、まとまりの名前入力の下の「案: …［使う］」と、問いの編集面の「AIの案」カード（採用／別の案／閉じる）、Settingsの状態表示。

**Tech Stack:** Swift 6、SwiftUI、FoundationModels、Swift Testing。外部依存の追加なし。

**Spec:** [PRD](../../specification.md)第3.3節・第5.1節・PRD-12・PRD-13、[Architecture](../../architecture.md)第3.1節、[決定0009](../../decisions/0009-on-device-ai-principles.md)・[0010](../../decisions/0010-on-device-suggestion-defaults.md)、[spike](../../verification/2026-10-10-on-device-ai-spike.md)。ロードマップは[theme-notes計画](2026-10-10-theme-notes.md)のPR 7。前提のPR 3〜6は[#23](https://github.com/ojiman/feeeder/pull/23)・[#25](https://github.com/ojiman/feeeder/pull/25)・[#27](https://github.com/ojiman/feeeder/pull/27)・[#30](https://github.com/ojiman/feeeder/pull/30)でマージ済み（main `07d27a2`）。本計画はこのPRのマージで承認される。計画承認を最終製品受入とは扱わない。

## 判断してほしい点（このPRのマージが承認になる）

迷ったときの基準は、ユーザー体験の最大化と、「速くなめらかに、掘り起こして再発見する」という方向。次の7点を、私が選んだ側で計画に入れている。違う側がよければ、マージ前に指摘してほしい。

1. **案は別のカードに出し、自動では何も書き換えない**。レンズを選ぶと、これまでどおり定型の問い（テーマ名入り）が**すぐ**入る。約1秒後に、その問いの下へ「AIの案」が出て、「採用」を押したときだけ問いの文が置き換わる（「別の案」「閉じる」もある）。まとまりの名前も、入力欄は空のままで、下に「案: …［使う］」が出る。代案: 定型の問いを入れる代わりに、案が届くまで待つ（遅くなるので不採用）。
2. **名前の案は、まとまりからテーマを作るときだけ**。`t`で新しいテーマ名を入力するとき、既存テーマの名前変更では出さない（本人が打つ名前を邪魔しない）。
3. **問いの案は、問いがまだ定型の文のままのときだけ**出す。本人が一文字でも直したら、案は出さず、すでに出ていた案も消える。「自由に書く」では出さない。
4. **出力の検査**（モデルの文をそのまま信用しない）。名前は先頭の1行のみ、番号・引用符・「テーマ名:」を外し、閉じ括弧・引用符・`}`より後ろを切り、2〜24文字。問いは先頭の1行のみ、10〜80文字、疑問で終わるもの（「〜か」は「。」を補う）だけ。満たさなければ案を出さない。
5. **入力**は、まとまり・テーマの記事のうち新しい16件まで、タイトル＋要約を120文字に切ったもの（決定0009の約20件より控えめにして、4096トークンに収める）。テーマに記録した要約だけを使い、期限切れ全文は使わない。
6. **10秒で打ち切る**。失敗・ガードレール・上限超過・取消・期限切れはどれも「案なし」で、エラーを見せない。
7. **スイッチは1つ**（Settingsの「端末内AI」）。切ると生成も可否の確認も一切呼ばない。Settingsには、埋め込みとは別に、名前・問いの案の状態（使えます／モデルの準備中／この環境では使えません）を出す。

プロンプトの質は、この環境（macOS 27.0.1）の実物で先に試した。名前は6〜14文字の名詞句を指示して「住宅ローンの金利変動と家計の負担」「睡眠の質と体内時計」のような妥当な案が出た（一度は「大規模言語モデルの推論最適化」と、3件のうち2件の話題だけに寄った）。問いは、疑問文で終えさせれば疑問文になったが、**指定した角度（前提・トレードオフなど）に沿っていないことが多く、長くなることもある**。案の質の判断は本人に委ね、PASSは「仕組み」（失敗しても止まらない・自動で書かない）に付ける。

## Global Constraints

- サポート下限はmacOS 27.0、ビルド下限はmacOS 26.6のまま。macOS 27 SDK専用のAPI、およびmacOS 27で非推奨になった`LanguageModelSession.GenerationError`の型での`catch`は使わない（失敗はすべて同じ「案なし」で扱う）（[決定0007](../../decisions/0007-support-floor-macos-27.md)）。
- 外部通信・アカウント・APIキー・BYOK・Private Cloud Computeを使わない。資産の自動取得を起こさない（[決定0009](../../decisions/0009-on-device-ai-principles.md)）。プロンプトに入れた記事の内容を、ログ・保存に残さない。
- AIは提案だけ。答え・いまの理解・問いの文・テーマ名を自動で書き込まない。構造化出力（`@Generable`）の自由文字列欄と正規表現ガイドに頼らず、プレーンテキストと出力トークン上限を使う（決定0009の7）。
- 無効のときは生成も可否の確認も呼ばない。利用不可・失敗・取消は「案なし」で、操作を止めない。結果は要求ごとに検査し、遅れて届いた結果・無効化後の結果・編集済みの問いへの結果を捨てる。
- `Binding`のsetterにメソッド参照を渡さず、明示的なクロージャを使う。`@MainActor`のクロージャで、可変のローカル変数を後から書き換えない（CIのSwift 6.3.3が落ちる。PR #14・#27・#30）。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・Keychain・ブラウザprofileを使わない。1PR1テーマ。バグ・新機能は失敗するテストを先に書く。コミット／PRの末尾にはセッションが指定する共著表記を付ける。
- 署名・配布・Tag／Release、`main`への直接pushをしない。実装完了後は、確認を待たずにブランチをpushしてPRを作る（本人の標準指示）。

## Review Focus

仕様が暗黙に求めているが、通常のテストでは見落としやすい入力・失敗を、起きやすい順に挙げる。担当Taskにそれぞれ試験を置く。

1. モデルの出力が崩れている（後ろに無関係な文・`」}」`・番号・箇条書き・説明文・断定文・長すぎる・空）。表示も適用もされない → Task 1。
2. ガードレールの誤検知・コンテキスト超過・10秒超過・取消・モデル利用不可。案が出ないだけで、スピナーが残らず、手動の操作が変わらない → Task 2・3・4。
3. 案が届く前に、本人が名前を打つ／問いを直す／別の問いへ移る。案が上書きしない、届いた案も捨てる → Task 2・4。
4. AIを切った（切った後に届いた）。生成も可否の確認も呼ばない → Task 2。
5. 巨大なテーマ（記事数百件）、長すぎるタイトル・要約、期限切れの記事。プロンプトは新しい16件・各120文字に収まり、期限切れ全文を含まない → Task 1・2。
6. 「別の案」で同じ文が返る、または今の問いと同じ文。案として出さない → Task 2。

---

## ファイル構成

| ファイル | 責務 |
|---|---|
| `Sources/ReaderCore/SuggestionText.swift`（新規） | 名前・問いの検査と整形、プロンプト、案を出してよい問いの判定（純粋関数） |
| `Sources/ReaderCore/Deadline.swift`（新規） | 期限つきで非同期処理を走らせる |
| `Sources/ReaderCore/ThemeAssistant.swift`（変更） | `generate(_:)`・`generationAvailability()`の追加、`ThemeSuggestionModel`の`proposeName`・`proposeQuestion` |
| `Sources/RSSReader/OnDeviceThemeAssistant.swift`（変更） | 生成の委譲と期限 |
| `Sources/RSSReader/FoundationModelsGenerator.swift`（新規） | `TextGenerating`の実物（`FoundationModels`） |
| `Sources/RSSReader/ClusterSuggestionsView.swift`・`QuestionEditor.swift`・`ReaderSettingsView.swift`・`ReaderView.swift`（変更） | 案の表示、状態の表示、配線 |
| `Tests/ReaderCoreTests/SuggestionTextTests.swift`・`DeadlineTests.swift`（新規）、`ThemeSuggestionModelTests.swift`（変更） | 試験 |
| `Tests/ReaderUITests/OnDeviceThemeAssistantTests.swift`（変更） | 生成の委譲・期限・任意の実物スモーク |

検証コマンド: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter <名前>`。CIの条件は`--scratch-path /private/tmp/feeeder-ci-build --force-resolved-versions --disable-keychain --disable-netrc`。

---

### Task 1: 出力の検査・プロンプト・案を出してよい問いの判定（純粋関数）

**Files:**
- Create: `Sources/ReaderCore/SuggestionText.swift`
- Test: `Tests/ReaderCoreTests/SuggestionTextTests.swift`

**Interfaces:**
- Consumes: `SuggestionItem`、`QuestionLens`（`draft(themeName:)`）
- Produces: `SuggestionText.name(from:) -> String?`、`SuggestionText.question(from:) -> String?`、`SuggestionPrompts.Request(instructions:prompt:maximumTokens:)`、`SuggestionPrompts.name(items:) -> Request`、`SuggestionPrompts.question(lens:template:themeName:items:) -> Request?`（`.custom`はnil）、`SuggestionPrompts.maximumItems`（16）・`itemTextLimit`（120）、`QuestionProposalEligibility.isEligible(lens:text:themeName:) -> Bool`

- [ ] **Step 1: 失敗するテストを書く**

```swift
import Foundation
import Testing
@testable import ReaderCore

struct SuggestionTextTests {
    @Test func aCleanNameIsKeptAndWrappingMarksAreRemoved() {
        #expect(SuggestionText.name(from: "金利と家計") == "金利と家計")
        #expect(SuggestionText.name(from: "  「住宅ローンの金利変動と家計の負担」\n") == "住宅ローンの金利変動と家計の負担")
        #expect(SuggestionText.name(from: "テーマ名: 睡眠習慣と体内時計。") == "睡眠習慣と体内時計")
        #expect(SuggestionText.name(from: "1. 小型AIモデルの端末内推論") == "小型AIモデルの端末内推論")
        #expect(SuggestionText.name(from: "- AI（端末内）の推論") == "AI（端末内）の推論")
    }

    @Test func junkAfterTheNameIsCutAndUnusableNamesAreRejected() {
        #expect(SuggestionText.name(from: "睡眠」}」この記事は睡眠について書かれています") == "睡眠")    // spike §2: text after 」}」
        #expect(SuggestionText.name(from: "金利と家計\nこのテーマは、金利が家計に与える影響を扱います。") == "金利と家計")
        #expect(SuggestionText.name(from: "") == nil)
        #expect(SuggestionText.name(from: " \n ") == nil)
        #expect(SuggestionText.name(from: "。") == nil)
        #expect(SuggestionText.name(from: "あ") == nil)                                          // too short
        #expect(SuggestionText.name(from: String(repeating: "あ", count: 25)) == nil)            // too long
        #expect(SuggestionText.name(from: "{\"name\": \"金利\"}") == nil)
    }

    @Test func aQuestionMustBeAQuestionOnOneLineWithinTheLength() {
        #expect(SuggestionText.question(from: "預金金利の上昇で家計の貯蓄行動はどう変わるか") == "預金金利の上昇で家計の貯蓄行動はどう変わるか。")
        #expect(SuggestionText.question(from: "「住宅ローンを変動金利型で組んでいると、返済負担は増えるだろうか。」") == "住宅ローンを変動金利型で組んでいると、返済負担は増えるだろうか。")
        #expect(SuggestionText.question(from: "1. 朝の光を浴びる時間は、睡眠の質にどう影響するのか？\n補足の説明です。") == "朝の光を浴びる時間は、睡眠の質にどう影響するのか？")
        #expect(SuggestionText.question(from: "How does sleep affect memory in daily life?") == "How does sleep affect memory in daily life?")
    }

    @Test func statementsTooShortTooLongAndBlankQuestionsAreRejected() {
        #expect(SuggestionText.question(from: "夜の睡眠の質は、朝の光を浴びることで向上する。") == nil)      // a statement
        #expect(SuggestionText.question(from: "なぜか") == nil)                                       // too short
        #expect(SuggestionText.question(from: String(repeating: "あ", count: 80) + "か。") == nil)     // too long
        #expect(SuggestionText.question(from: "") == nil)
        #expect(SuggestionText.question(from: "{\"q\": \"どうなるか\"}") == nil)
    }

    @Test func aFixedLensQuestionPassesThroughUnchanged() {
        // The model may repeat the template; it must still be recognised as the template, not mangled by the quote handling.
        for lens in QuestionLens.allCases where lens != .custom {
            let template = lens.draft(themeName: "金利と家計")
            #expect(SuggestionText.question(from: template) == template)
        }
    }

    @Test func promptsKeepTheNewestItemsAndCutTheirLength() {
        let items = (0..<40).map { SuggestionItem(id: UUID(), text: "記事 \($0)\n" + String(repeating: "あ", count: 400)) }
        let request = SuggestionPrompts.name(items: items)
        let lines = request.prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems)
        #expect(lines.first?.hasPrefix("- 記事 0 ") == true && lines.last?.hasPrefix("- 記事 15 ") == true)   // input is newest first
        #expect(lines.allSatisfy { $0.count <= SuggestionPrompts.itemTextLimit + 2 })                      // "- " + text
        #expect(!request.prompt.contains("記事 16"))
        #expect(request.maximumTokens == SuggestionPrompts.nameTokenLimit && request.instructions.contains("名前だけ"))
    }

    @Test func aQuestionPromptCarriesTheAngleTheTemplateAndTheThemeName() throws {
        let items = [SuggestionItem(id: UUID(), text: "金利が上がる\n家計の返済負担が増える")]
        let template = QuestionLens.tradeoff.draft(themeName: "金利と家計")
        let request = try #require(SuggestionPrompts.question(lens: .tradeoff, template: template, themeName: "金利と家計", items: items))
        #expect(request.prompt.contains("金利と家計") && request.prompt.contains(template) && request.prompt.contains("手放して"))
        #expect(request.prompt.contains("- 金利が上がる 家計の返済負担が増える"))               // newline inside an item becomes a space
        #expect(request.maximumTokens == SuggestionPrompts.questionTokenLimit && request.instructions.contains("疑問文"))
        #expect(SuggestionPrompts.question(lens: .custom, template: "", themeName: "A", items: items) == nil)
    }

    @Test func onlyAnUneditedTemplateOfAFixedLensIsEligible() {
        let template = QuestionLens.assumption.draft(themeName: "金利と家計")
        #expect(QuestionProposalEligibility.isEligible(lens: .assumption, text: template, themeName: "金利と家計"))
        #expect(QuestionProposalEligibility.isEligible(lens: .assumption, text: "  " + template + "\n", themeName: " 金利と家計 "))
        #expect(!QuestionProposalEligibility.isEligible(lens: .assumption, text: template + "追記", themeName: "金利と家計"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .assumption, text: template, themeName: "改名後"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .custom, text: "", themeName: "A"))
        #expect(!QuestionProposalEligibility.isEligible(lens: .custom, text: "自由な問い", themeName: "A"))
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter SuggestionTextTests`
Expected: コンパイルエラー（`SuggestionText`などが無い）。

- [ ] **Step 3: 実装**

`Sources/ReaderCore/SuggestionText.swift`を新規作成する。

```swift
import Foundation

/// Turns the model's raw text into something safe to show, or nil. The model's own words are never trusted as-is:
/// the spike saw names followed by 「」}」 and unrelated sentences, numbered lines, and statements instead of questions.
public enum SuggestionText {
    static let nameLength = 2...24
    static let questionLength = 10...80
    private static let leadingMarks = try! NSRegularExpression(pattern: #"^\s*(?:(?:テーマ名|名前|タイトル|問い)\s*[:：]\s*|(?:[-・*•]|\d+\s*[.)、．])\s*)"#)
    private static let wrappers: Set<Character> = ["「", "『", "“", "\"", "'", "「"]
    private static let closers: Set<Character> = ["」", "』", "”", "\"", "'", "}", "{"]

    /// A theme name: first line, marks removed, cut before any closing quote or brace, 2–24 characters.
    public static func name(from raw: String) -> String? {
        guard var text = firstLine(of: raw) else { return nil }
        text = String(text.drop(while: { wrappers.contains($0) }))
        if let cut = text.firstIndex(where: { closers.contains($0) }) { text = String(text[..<cut]) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "。、．.,:：")))
        guard nameLength.contains(text.count), !text.contains("{"), !text.contains("}") else { return nil }
        return text
    }

    /// A question: first line, marks and wrapping quotes removed, ends as a question, 10–80 characters.
    public static func question(from raw: String) -> String? {
        guard var text = firstLine(of: raw) else { return nil }
        text = unwrap(text).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("か") { text += "。" }
        let endsAsQuestion = text.hasSuffix("か。") || text.hasSuffix("か？") || text.hasSuffix("？") || text.hasSuffix("?")
        guard endsAsQuestion, questionLength.contains(text.count), !text.contains("{"), !text.contains("}") else { return nil }
        return text
    }

    /// Removes one pair of quotes around the whole text. A fixed question that merely starts with 「テーマ名」 is left alone.
    private static func unwrap(_ text: String) -> String {
        let pairs: [Character: Character] = ["「": "」", "『": "』", "“": "”", "\"": "\"", "'": "'"]
        guard let first = text.first, let close = pairs[first], text.count >= 2, text.last == close else { return text }
        return String(text.dropFirst().dropLast())
    }

    private static func firstLine(of raw: String) -> String? {
        guard let line = raw.split(whereSeparator: \.isNewline).map({ String($0).trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        let stripped = leadingMarks.stringByReplacingMatches(in: line, range: range, withTemplate: "")
        let result = stripped.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }
}

public enum SuggestionPrompts {
    public static let maximumItems = 16
    public static let itemTextLimit = 120
    public static let nameTokenLimit = 32
    public static let questionTokenLimit = 90

    public struct Request: Sendable, Equatable {
        public let instructions: String
        public let prompt: String
        public let maximumTokens: Int
        public init(instructions: String, prompt: String, maximumTokens: Int) {
            self.instructions = instructions; self.prompt = prompt; self.maximumTokens = maximumTokens
        }
    }

    /// `items` are newest first; only the first `maximumItems` are used, each cut to `itemTextLimit` characters.
    public static func name(items: [SuggestionItem]) -> Request {
        Request(
            instructions: "あなたは読書ノートの整理を手伝います。記事のタイトル一覧に共通するテーマを、具体的な名詞句の名前（6〜14文字）にして日本語で1つだけ答えます。例: 「住宅ローン金利と家計の負担」「小型AIモデルの端末内推論」。名前だけを出力し、説明・記号・引用符は付けません。",
            prompt: "記事:\n" + list(items), maximumTokens: nameTokenLimit)
    }

    /// The fixed lens's own question is the template. `.custom` has none, so no request.
    public static func question(lens: QuestionLens, template: String, themeName: String, items: [SuggestionItem]) -> Request? {
        guard let angle = angle(for: lens) else { return nil }
        return Request(
            instructions: "あなたは読書ノートの整理を手伝います。『角度』に沿って、記事の内容に即した問いを日本語で1つだけ作ります。必ず「〜か。」「〜だろうか。」のような疑問文で終え、50文字以内にします。問いだけを出力し、番号・説明・引用符は付けません。記事にない事実は作りません。",
            prompt: "テーマ: \(themeName)\n角度: \(angle)\n定型の問い: \(template)\n記事:\n" + list(items), maximumTokens: questionTokenLimit)
    }

    static func angle(for lens: QuestionLens) -> String? {
        switch lens {
        case .assumption: "その主張が成り立つために暗黙に置いている前提を疑う"
        case .exception: "当てはまらない例外や、反対の立場からの反論を問う"
        case .condition: "どんな条件のもとで成り立ち、条件が変わると何が変わるかを問う"
        case .tradeoff: "得るものと引き換えに手放しているものを問う"
        case .personal: "読者自身の生活や仕事に当てはめるとどうかを問う"
        case .custom: nil
        }
    }

    private static func list(_ items: [SuggestionItem]) -> String {
        items.prefix(maximumItems).map { item in
            let flat = item.text.split(whereSeparator: \.isNewline).joined(separator: " ")
            return "- " + String(flat.prefix(itemTextLimit))
        }.joined(separator: "\n")
    }
}

/// A question proposal is only offered while the question is still the lens's untouched template.
public enum QuestionProposalEligibility {
    public static func isEligible(lens: QuestionLens, text: String, themeName: String) -> Bool {
        guard lens != .custom else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == lens.draft(themeName: themeName).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: 通ることを確認し、変異確認をする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter SuggestionTextTests`
Expected: 全件PASS。変異確認（コミットしてから行い、戻すのは行の置換で行う）: (a) `closers`から`"}"`を外すと`junkAfterTheNameIsCut…`が落ちる、(b) `question`の疑問の判定（`endsAsQuestion`）を常にtrueにすると`statementsTooShort…`が落ちる、(c) `prefix(maximumItems)`を外すと`promptsKeepTheNewestItems…`が落ちる。

- [ ] **Step 5: コミット**

```bash
git add Sources/ReaderCore/SuggestionText.swift Tests/ReaderCoreTests/SuggestionTextTests.swift
git commit -m "feat: 名前・問いの出力検査、プロンプト、案を出してよい問いの判定を純粋関数として追加する"
```

---

### Task 2: `ThemeAssistant`の生成と、案を返す`ThemeSuggestionModel`

**Files:**
- Modify: `Sources/ReaderCore/ThemeAssistant.swift`
- Modify: `Sources/RSSReader/OnDeviceThemeAssistant.swift`（Task 3で置き換える仮の本体だけ）
- Test: `Tests/ReaderCoreTests/ThemeSuggestionModelTests.swift`

**Interfaces:**
- Consumes: Task 1の型、既存の`ThemeSuggestionModel`・`FakeAssistant`
- Produces: `ThemeAssistant`に`func generationAvailability() async -> AssistantAvailability`・`func generate(_ request: SuggestionPrompts.Request) async throws -> String`を追加。`ThemeSuggestionModel.generationAvailability`、`proposeName(forArticles:) async -> String?`、`proposeQuestion(for:) async -> String?`

- [ ] **Step 1: 失敗するテストを書く**

`FakeAssistant`（`ThemeSuggestionModelTests.swift`の先頭）に、生成の台本と呼び出し記録を足す。

```swift
    private var generated: [String] = []
    private var generationFailure: (any Error)?
    private var generationAvailabilityValue = AssistantAvailability.available
    private var holdGeneration = false
    private var parkedGeneration: CheckedContinuation<Void, Never>?
    private(set) var generateCalls: [SuggestionPrompts.Request] = []
    private(set) var generationAvailabilityCalls = 0

    func scriptGeneration(_ outputs: [String] = [], failure: (any Error)? = nil, hold: Bool = false, availability: AssistantAvailability = .available) {
        generated = outputs; generationFailure = failure; holdGeneration = hold; generationAvailabilityValue = availability
    }
    var generationParked: Bool { parkedGeneration != nil }
    func releaseGeneration() { parkedGeneration?.resume(); parkedGeneration = nil }

    func generationAvailability() async -> AssistantAvailability { generationAvailabilityCalls += 1; return generationAvailabilityValue }
    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        generateCalls.append(request)
        if holdGeneration { await withCheckedContinuation { parkedGeneration = $0 } }
        if let generationFailure { throw generationFailure }
        return generated.isEmpty ? "" : generated.removeFirst()
    }
```

`ThemeSuggestionModelTests`に追加する（`Boom`・`makeStore`・`model`・`waitUntil`・`SuggestionSwitch`は既存）。

```swift
    @Test func aNameIsProposedFromTheGroupsArticlesAndJunkIsCleaned() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 20)
        let ids = store.articles.map(\.id)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["「住宅ローンの金利変動と家計の負担」}」この記事は…"])
        let suggestions = model(store, fake)
        let name = await suggestions.proposeName(forArticles: Array(ids.prefix(18)))
        #expect(name == "住宅ローンの金利変動と家計の負担")
        let calls = await fake.generateCalls
        let lines = calls[0].prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems && lines.first == "- 記事 0 要約 0")
        #expect(await suggestions.proposeName(forArticles: [ids[0]]) == nil)          // one article is not a group
        let after = await fake.generateCalls
        #expect(after.count == 1)
    }

    @Test func aBrokenNameOrAFailureOrADisabledSwitchGivesNoProposalAndNoCall() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let ids = Array(store.articles.map(\.id).prefix(3))
        let fake = FakeAssistant()
        await fake.scriptGeneration([""])
        let suggestions = model(store, fake)
        #expect(await suggestions.proposeName(forArticles: ids) == nil)               // empty output
        await fake.scriptGeneration(failure: Boom())
        #expect(await suggestions.proposeName(forArticles: ids) == nil)               // guardrail / overflow / anything
        await fake.scriptGeneration(["金利と家計"])
        let off = model(store, fake, enabled: false)
        #expect(await off.proposeName(forArticles: ids) == nil)
        await off.refreshAvailability()
        let (calls, availabilityCalls) = (await fake.generateCalls, await fake.generationAvailabilityCalls)
        #expect(calls.count == 2 && availabilityCalls == 0)                           // the disabled model called nothing
        #expect(await model(store, nil).proposeName(forArticles: ids) == nil)
    }

    @Test func aProposalThatArrivesAfterTheSwitchWasTurnedOffIsDropped() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let ids = Array(store.articles.map(\.id).prefix(3))
        let fake = FakeAssistant()
        await fake.scriptGeneration(["金利と家計"], hold: true)
        let enabled = SuggestionSwitch()
        let suggestions = ThemeSuggestionModel(store: store, assistant: fake, isEnabled: { enabled.on }, now: { self.at })
        let task = Task { await suggestions.proposeName(forArticles: ids) }
        try await waitUntil { await fake.generationParked }
        enabled.on = false
        await fake.releaseGeneration()
        #expect(await task.value == nil)
    }

    @Test func aQuestionProposalUsesTheThemesRecordedArticlesAndTheTemplate() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 30)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "金利と家計", at: at)
        for (offset, id) in ids[5..<25].enumerated() { try store.addArticle(id, toTheme: theme.id, at: at.addingTimeInterval(Double(offset))) }
        let question = try store.addQuestion(themeID: theme.id, lens: .tradeoff, at: at)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["住宅ローンを組む家計は、金利上昇と引き換えに何を手放すのか。"])
        let suggestions = model(store, fake)
        let proposal = await suggestions.proposeQuestion(for: question.id)
        #expect(proposal == "住宅ローンを組む家計は、金利上昇と引き換えに何を手放すのか。")
        let request = try #require(await fake.generateCalls.first)
        #expect(request.prompt.contains(question.text) && request.prompt.contains("テーマ: 金利と家計"))
        let lines = request.prompt.split(separator: "\n").filter { $0.hasPrefix("- ") }
        #expect(lines.count == SuggestionPrompts.maximumItems && lines.first == "- 記事 24 要約 24")      // newest additions first
    }

    @Test func noQuestionProposalForAnEditedAFreeOrAMissingQuestionOrAnUnchangedAnswer() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[0].id, store.articles[1].id], at: at)
        let edited = try store.addQuestion(themeID: theme.id, lens: .assumption, at: at)
        try store.updateQuestion(id: edited.id, text: "自分で直した問いです、どうなるか。", at: at)
        let free = try store.addQuestion(themeID: theme.id, lens: .custom, text: "自由な問いをここに書きます。", at: at)
        let plain = try store.addQuestion(themeID: theme.id, lens: .exception, at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await fake.scriptGeneration(["自分で直した問いです、どうなるか。"])
        #expect(await suggestions.proposeQuestion(for: edited.id) == nil)
        #expect(await suggestions.proposeQuestion(for: free.id) == nil)
        #expect(await suggestions.proposeQuestion(for: UUID()) == nil)
        let untouched = await fake.generateCalls
        #expect(untouched.isEmpty)
        await fake.scriptGeneration([plain.text])                                        // the model just repeats the template
        #expect(await suggestions.proposeQuestion(for: plain.id) == nil)
        await fake.scriptGeneration(["これは問いではなく、記事の要約です。"])
        #expect(await suggestions.proposeQuestion(for: plain.id) == nil)                 // not a question
    }

    @Test func aQuestionProposalIsDroppedWhenTheQuestionWasEditedWhileWaiting() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[0].id, store.articles[1].id], at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .condition, at: at)
        let fake = FakeAssistant()
        await fake.scriptGeneration(["この条件が変わると、結論はどう変わるのだろうか。"], hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.proposeQuestion(for: question.id) }
        try await waitUntil { await fake.generationParked }
        try store.updateQuestion(id: question.id, text: "本人が書き直した問いはこちらです。", at: at)
        await fake.releaseGeneration()
        #expect(await task.value == nil)
    }

    @Test func generationAvailabilityIsReportedOnlyWhileEnabled() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 1)
        let fake = FakeAssistant()
        await fake.scriptGeneration(availability: .assetsMissing)
        let suggestions = model(store, fake)
        await suggestions.refreshAvailability()
        #expect(suggestions.generationAvailability == .assetsMissing)
        let off = model(store, fake, enabled: false)
        await off.refreshAvailability()
        #expect(off.generationAvailability == nil)
    }
```

（`#expect(await …)`の中で`await`と`&&`を混ぜるとコンパイルできないので、`await`は単独の式として書く。上のコードは単独の比較だけにしてある。）

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeSuggestionModelTests`
Expected: コンパイルエラー（`generate`・`proposeName`などが無い）。

- [ ] **Step 3: 実装**

`ThemeAssistant.swift`: プロトコルに2つ追加し、`ThemeSuggestionModel`に状態とメソッドを足し、`candidateInputs`の中身を取り出して再利用する。

```swift
public protocol ThemeAssistant: Sendable {
    func availability() async -> AssistantAvailability
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch]
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]]
    /// State of the text-generation model, separate from the embedding's. Never starts a download.
    func generationAvailability() async -> AssistantAvailability
    /// Plain text from the on-device model. Throws on any failure; callers treat every throw as "no proposal".
    func generate(_ request: SuggestionPrompts.Request) async throws -> String
}
```

```swift
    public private(set) var generationAvailability: AssistantAvailability?
```

`refreshAvailability()`を次の形に直す（無効なら両方nil）。

```swift
    public func refreshAvailability() async {
        guard isEnabled() else { availability = nil; generationAvailability = nil; return }
        guard let assistant else { availability = .unsupported; generationAvailability = .unsupported; return }
        let embedding = await assistant.availability()
        let generation = await assistant.generationAvailability()
        let on = isEnabled()
        availability = on ? embedding : nil
        generationAvailability = on ? generation : nil
    }
```

問いの案には、テーマの記録からプロンプトの上限（16件）まで使う（近いテーマの比較用の10件とは別）。

```swift
    private func questionItems(themeID: UUID) -> [SuggestionItem] {
        store.themeArticles.filter { $0.themeID == themeID }
            .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.key < $1.key }
            .prefix(SuggestionPrompts.maximumItems)
            .compactMap { Self.item(id: $0.articleID, title: $0.title, summary: $0.summary) }
    }

    /// A name for a group of articles (newest first), or nil. Any failure, an unusable output, a late answer and a
    /// switched-off assistant all give nil.
    public func proposeName(forArticles ids: [UUID]) async -> String? {
        guard isEnabled(), let assistant else { return nil }
        let items = ids.compactMap { suggestionItem(for: $0) }
        guard items.count >= 2 else { return nil }
        do {
            let raw = try await assistant.generate(SuggestionPrompts.name(items: items))
            guard !Task.isCancelled, isEnabled() else { return nil }
            return SuggestionText.name(from: raw)
        } catch { return nil }
    }

    /// A more specific version of an untouched lens question, or nil. Never for an edited or free question, and
    /// dropped if the question changed while the model was working.
    public func proposeQuestion(for questionID: UUID) async -> String? {
        guard isEnabled(), let assistant, let (question, themeName) = eligibleQuestion(questionID) else { return nil }
        let items = questionItems(themeID: question.themeID)
        guard !items.isEmpty,
              let request = SuggestionPrompts.question(lens: question.lens, template: question.text, themeName: themeName, items: items) else { return nil }
        do {
            let raw = try await assistant.generate(request)
            guard !Task.isCancelled, isEnabled(), let current = eligibleQuestion(questionID),
                  current.0.text == question.text, let text = SuggestionText.question(from: raw), text != question.text else { return nil }
            return text
        } catch { return nil }
    }

    private func eligibleQuestion(_ id: UUID) -> (ThemeQuestion, String)? {
        guard let question = store.themeQuestions.first(where: { $0.id == id }), let theme = store.theme(id: question.themeID),
              QuestionProposalEligibility.isEligible(lens: question.lens, text: question.text, themeName: theme.name) else { return nil }
        return (question, theme.name)
    }
```

`OnDeviceThemeAssistant`に、Task 3で置き換える仮の本体を足す（ビルドを通すため）。

```swift
    func generationAvailability() async -> AssistantAvailability { .unsupported }
    func generate(_ request: SuggestionPrompts.Request) async throws -> String { throw CancellationError() }
```

- [ ] **Step 4: 通ることを確認し、変異確認をする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeSuggestionModelTests`
Expected: 全件PASS。変異確認（コミット後）: (a) `proposeName`の`isEnabled()`の再読み込みを外すと`aProposalThatArrivesAfterTheSwitch…`が落ちる、(b) `proposeQuestion`の`current.0.text == question.text`を外すと`…EditedWhileWaiting`が落ちる、(c) `text != question.text`を外すと`noQuestionProposalFor…`が落ちる、(d) `refreshAvailability`の無効時の早期returnを外すと`…OnlyWhileEnabled`が落ちる。

- [ ] **Step 5: コミット**

```bash
git add Sources Tests
git commit -m "feat: ThemeAssistantに生成を足し、名前・問いの案を検査して返す"
```

---

### Task 3: 実物の生成（`FoundationModels`）と10秒の期限

**Files:**
- Create: `Sources/ReaderCore/Deadline.swift`、`Sources/RSSReader/FoundationModelsGenerator.swift`
- Modify: `Sources/RSSReader/OnDeviceThemeAssistant.swift`
- Test: `Tests/ReaderCoreTests/DeadlineTests.swift`、`Tests/ReaderUITests/OnDeviceThemeAssistantTests.swift`

**Interfaces:**
- Consumes: Task 1・2の型
- Produces: `withDeadline(_:_:)`と`DeadlineExceeded`、`protocol TextGenerating: Sendable { availability(); generate(_:) }`、`struct FoundationModelsGenerator: TextGenerating`、`OnDeviceThemeAssistant.init(embedder:generator:generationDeadline:)`

使うAPIは、この環境（macOS 27.0.1）で、`SystemLanguageModel.default.availability`（`.available`／`.unavailable(reason)`）、`LanguageModelSession(instructions:)`、`respond(to:options: GenerationOptions(maximumResponseTokens:))`が使えることを使い捨てのスクリプトで確認済み。非推奨の`GenerationError`は型で受けない。

- [ ] **Step 1: 失敗するテストを書く**

`DeadlineTests.swift`:

```swift
import Foundation
import Testing
@testable import ReaderCore

struct DeadlineTests {
    @Test func aFastOperationReturnsItsValue() async throws {
        let value = try await withDeadline(5) { 42 }
        #expect(value == 42)
    }

    @Test func aSlowOperationIsCutOffAtTheDeadline() async {
        await #expect(throws: DeadlineExceeded.self) {
            try await withDeadline(0.05) { try await Task.sleep(for: .seconds(30)); return 1 }
        }
    }

    @Test func anOperationsOwnErrorPassesThrough() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) { try await withDeadline(5) { () async throws -> Int in throw Boom() } }
    }

    @Test func cancellingTheCallerCancelsTheOperation() async throws {
        let task = Task { try await withDeadline(30) { try await Task.sleep(for: .seconds(30)); return 1 } }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
```

`OnDeviceThemeAssistantTests.swift`に追加する（偽の生成器と、生成の委譲・期限・可否の試験）。

```swift
private final class ScriptedGenerator: TextGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [SuggestionPrompts.Request] = []
    var output = "金利と家計"
    var delay: Duration?
    var failure: (any Error)?
    var state = AssistantAvailability.available
    var requests: [SuggestionPrompts.Request] { lock.withLock { seen } }
    func availability() async -> AssistantAvailability { state }
    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        lock.withLock { seen.append(request) }
        if let delay { try await Task.sleep(for: delay) }
        if let failure { throw failure }
        return output
    }
}
```

```swift
    @Test func generationIsDelegatedUnchangedAndItsStateIsReported() async throws {
        let generator = ScriptedGenerator()
        generator.output = "睡眠と体内時計"
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder(), generator: generator)
        let request = SuggestionPrompts.name(items: [item("朝の光"), item("昼寝")])
        let text = try await assistant.generate(request)
        #expect(text == "睡眠と体内時計" && generator.requests == [request])
        generator.state = .assetsMissing
        #expect(await assistant.generationAvailability() == .assetsMissing)
        #expect(await OnDeviceThemeAssistant(embedder: KeywordEmbedder(), generator: nil).generationAvailability() == .unsupported)
    }

    @Test func aSlowOrFailingOrMissingGeneratorThrowsInsteadOfHanging() async {
        let slow = ScriptedGenerator(); slow.delay = .seconds(30)
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder(), generator: slow, generationDeadline: 0.05)
        let request = SuggestionPrompts.name(items: [item("朝の光"), item("昼寝")])
        await #expect(throws: DeadlineExceeded.self) { try await assistant.generate(request) }
        let failing = ScriptedGenerator(); failing.failure = CancellationError()
        await #expect(throws: (any Error).self) { try await OnDeviceThemeAssistant(embedder: KeywordEmbedder(), generator: failing).generate(request) }
        await #expect(throws: (any Error).self) { try await OnDeviceThemeAssistant(embedder: KeywordEmbedder(), generator: nil).generate(request) }
    }

    /// Opt-in: the real on-device model on synthetic topics, printed for the verification record. Quality is judged by a person.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FEEEDER_RUN_ONDEVICE_AI"] == "1"))
    func realGenerationSmoke() async throws {
        let assistant = OnDeviceThemeAssistant()
        let state = await assistant.generationAvailability()
        #expect(state == .available)
        let topics = [
            ["日銀が政策金利を引き上げ、住宅ローン金利も上昇する見通し", "変動金利型の住宅ローンを組む家計の返済負担が増える", "預金金利の上昇で家計の貯蓄行動はどう変わるか", "インフレと賃金上昇の関係を家計の視点で読む"],
            ["睡眠の質を上げるための就寝前の習慣", "朝の光を浴びると体内時計が整う", "昼寝の長さと夜の眠りの関係", "カフェインを摂る時間帯が睡眠に与える影響"],
            ["小型のAIモデルを端末内で動かすための量子化の基本", "ローカルで動く大規模言語モデルの推論最適化", "AIモデルの蒸留で軽量化する手法のまとめ"]
        ]
        for titles in topics {
            let items = titles.map { item($0) }
            let raw = try? await assistant.generate(SuggestionPrompts.name(items: items))
            let name = raw.flatMap { SuggestionText.name(from: $0) }
            print("NAME", raw ?? "(failed)", "→", name ?? "(rejected)")
            let template = QuestionLens.assumption.draft(themeName: name ?? "テーマ")
            if let request = SuggestionPrompts.question(lens: .assumption, template: template, themeName: name ?? "テーマ", items: items) {
                let rawQuestion = try? await assistant.generate(request)
                print("QUESTION", rawQuestion ?? "(failed)", "→", rawQuestion.flatMap { SuggestionText.question(from: $0) } ?? "(rejected)")
            }
        }
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter "DeadlineTests|OnDeviceThemeAssistantTests"`
Expected: コンパイルエラー（`withDeadline`・`TextGenerating`・`generator:`が無い）。

- [ ] **Step 3: 実装**

`Sources/ReaderCore/Deadline.swift`:

```swift
import Foundation

public struct DeadlineExceeded: Error, Equatable, Sendable {}

/// Runs `operation` and gives up with `DeadlineExceeded` after `seconds`. The operation is cancelled when it loses,
/// and cancelling the caller cancels both.
public func withDeadline<T: Sendable>(_ seconds: Double, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask { try await Task.sleep(for: .seconds(seconds)); throw DeadlineExceeded() }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw CancellationError() }
        return first
    }
}
```

`Sources/RSSReader/FoundationModelsGenerator.swift`:

```swift
import Foundation
import FoundationModels
import ReaderCore

protocol TextGenerating: Sendable {
    func availability() async -> AssistantAvailability
    func generate(_ request: SuggestionPrompts.Request) async throws -> String
}

/// The system's on-device language model, asked for plain text with an output-token cap. Every failure (guardrail,
/// context overflow, unavailable model, cancellation) is just thrown: callers treat any throw as "no proposal".
/// Never starts a model download. Prompts are not logged.
struct FoundationModelsGenerator: TextGenerating {
    func availability() async -> AssistantAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(let reason): reason == .modelNotReady ? .assetsMissing : .unsupported
        @unknown default: .unsupported
        }
    }

    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        let session = LanguageModelSession(instructions: request.instructions)
        let response = try await session.respond(to: request.prompt, options: GenerationOptions(maximumResponseTokens: request.maximumTokens))
        return response.content
    }
}
```

`OnDeviceThemeAssistant`を次のように直す（仮の2メソッドを置き換え、イニシャライザを広げる）。

```swift
actor OnDeviceThemeAssistant: ThemeAssistant {
    private let embedder: any TextEmbedder
    private let generator: (any TextGenerating)?
    private let generationDeadline: Double
    init(embedder: any TextEmbedder = ContextualTextEmbedder(), generator: (any TextGenerating)? = FoundationModelsGenerator(),
         generationDeadline: Double = 10) {
        self.embedder = embedder; self.generator = generator; self.generationDeadline = generationDeadline
    }

    func generationAvailability() async -> AssistantAvailability { await generator?.availability() ?? .unsupported }

    func generate(_ request: SuggestionPrompts.Request) async throws -> String {
        guard let generator else { throw CancellationError() }
        return try await withDeadline(generationDeadline) { try await generator.generate(request) }
    }
    // availability / nearestThemes / clusters / embed: unchanged
}
```

- [ ] **Step 4: 通ることを確認し、実物のスモークを一度実行する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter "DeadlineTests|OnDeviceThemeAssistantTests"`
Expected: 全件PASS（実物のスモークはスキップ）。続けて、実物を一度だけ動かし、出力を検証記録用に控える。

Run: `FEEEDER_RUN_ONDEVICE_AI=1 swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter realGenerationSmoke 2>&1 | grep -E "NAME|QUESTION|✔ Test|✘"`
Expected: PASS。`NAME`・`QUESTION`の行で、生のモデル出力と検査後の結果を見る（「(rejected)」が出ても失敗ではなく、検査が働いた証拠）。変異確認（コミット後）: `withDeadline`の`group.cancelAll()`を外すと`cancellingTheCaller…`が落ちるか、`DeadlineExceeded`を投げる側を消すと`aSlowOperation…`が落ちる。

- [ ] **Step 5: コミット**

```bash
git add Sources Tests
git commit -m "feat: FoundationModelsによる名前・問いの案の生成を、10秒の期限つきで追加する"
```

---

### Task 4: 画面（名前の案、問いの案、Settingsの状態、配線）

**Files:**
- Modify: `Sources/RSSReader/ClusterSuggestionsView.swift`、`QuestionEditor.swift`、`ReaderSettingsView.swift`、`ReaderView.swift`

**Interfaces:**
- Consumes: Task 2の`proposeName`・`proposeQuestion`・`generationAvailability`
- Produces: `QuestionEditor(…, suggestions: ThemeSuggestionModel? = nil)`

- [ ] **Step 1: まとまりの名前の案（`ClusterSuggestionsView`）**

`ClusterSuggestionsView`に状態を足す。

```swift
    private enum NameProposal: Equatable { case none, loading, ready(String) }
    @State private var proposal = NameProposal.none
```

`body`の末尾の修飾子（`.onChange(of: model.clusters.groups)`の隣）に、名前入力が始まったグループごとに案を取りに行くタスクを足す。入力が変わる・グループが消える・ポップオーバーが閉じるとタスクは取り消され、遅れた結果は入らない。

```swift
        .task(id: naming) {
            proposal = .none
            guard let group = naming else { return }
            proposal = .loading
            let text = await model.proposeName(forArticles: group)
            guard !Task.isCancelled else { return }
            proposal = text.map { .ready($0) } ?? .none
        }
```

`card(_:)`の、名前入力（`HStack`）の直後に案の行を足す。**入力欄には自動で入れない。**

```swift
                switch proposal {
                case .loading:
                    HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("名前の案を考え中…").font(.caption).foregroundStyle(.secondary) }
                case .ready(let text):
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").foregroundStyle(.orange)
                        Text("案: \(text)").font(.callout).lineLimit(2)
                        Spacer()
                        Button("使う") { name = text }.accessibilityLabel("名前の案「\(text)」を使う")
                    }
                case .none: EmptyView()
                }
```

- [ ] **Step 2: 問いの案（`QuestionEditor`）**

`QuestionEditor`にプロパティと状態を足す。

```swift
    var suggestions: ThemeSuggestionModel? = nil
    @State private var proposal: String?
    @State private var proposing = false
    @State private var proposalDismissed = false
    @State private var round = 0
    private struct ProposalKey: Hashable { let text: String; let round: Int }
```

問いの`TextField`の直後（最初の`Divider()`の前）にカードを足す。

```swift
                    proposalCard
```

```swift
    @ViewBuilder private var proposalCard: some View {
        if let proposal, !proposalDismissed {
            VStack(alignment: .leading, spacing: 6) {
                Label("AIの案（この Mac の中で作成）", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                Text(proposal).font(.callout)
                HStack {
                    Button("採用") { adopt(proposal) }
                    Button("別の案") { round += 1 }
                    Button("閉じる") { proposalDismissed = true }
                }
            }
            .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        } else if proposing, !proposalDismissed {
            HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("問いの案を考え中…").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func adopt(_ text: String) {
        do { try store.updateQuestion(id: questionID, text: text, at: .now); proposal = nil } catch { self.error = error.localizedDescription }
    }
```

`ScrollView`の修飾子（`.onChange(of: question.text)`の隣）に、案を取りに行くタスクを足す。問いの文が変わる（本人が直した・採用した）とタスクが取り消され、案は消える。

```swift
            .task(id: ProposalKey(text: question.text, round: round)) {
                proposal = nil
                guard let suggestions, !proposalDismissed else { return }
                proposing = true
                let result = await suggestions.proposeQuestion(for: questionID)
                guard !Task.isCancelled else { return }
                proposing = false
                proposal = result
            }
```

（`proposing`は、取り消されたときは次のタスクが引き継ぐので、取り消し側では戻さない。次のタスクが`guard`で早く抜ける場合に`proposing`が残らないよう、`guard let suggestions…`の失敗側で`proposing = false`にする。実装時に、スピナーが残らないことを確認する。）

- [ ] **Step 3: Settingsと配線**

`OnDeviceAISettingsView`の「状態」の下に1行足す。

```swift
            LabeledContent("テーマ名・問いの案") { Text(generationText) }
```

```swift
    private var generationText: String {
        guard enabled else { return "オフ" }
        return switch suggestions.generationAvailability {
        case nil: "確認中…"
        case .available: "使えます"
        case .assetsMissing: "モデルの準備中です"
        case .unsupported: "この環境では使えません"
        }
    }
```

説明文を、近いテーマ・まとまりに加えて名前・問いの案にも触れる形に直す（「案は別に表示され、自分で選ぶまで何も書き換えません」）。

`ReaderView`の`questionsDetail`が作る`QuestionEditor(...)`に`suggestions: suggestions`を渡す。

- [ ] **Step 4: ビルド・全テスト**

Run: `swift build --scratch-path /private/tmp/feeeder-dogfooding-build`、`swift test --scratch-path /private/tmp/feeeder-dogfooding-build`、`bash scripts/build-app.sh release`、`codesign --verify --deep --strict .build/Feeeder.app`、`git diff --check`。`grep -rn "set: [a-zA-Z]*)" Sources/RSSReader | grep -v "set: {"`でメソッド参照のsetterが無いことを確認する。
Expected: すべて通る。

- [ ] **Step 5: コミット**

```bash
git add Sources
git commit -m "feat: まとまりの名前の案と、レンズの問いの具体化の案を、自分で選べる形で表示する"
```

---

### Task 5: 文書・実機確認・独立レビュー・PR

**Files:**
- Modify: `docs/specification.md`、`README.md`、`docs/architecture.md`、`docs/decisions/README.md`
- Create: `docs/decisions/0011-on-device-generation-defaults.md`、`docs/verification/2026-10-10-theme-ai-names.md`

- [ ] **Step 1: 決定記録0011を書く**

形式は[0010](../../decisions/0010-on-device-suggestion-defaults.md)に合わせる（状態: 有効（PR 7の計画のマージで承認）、決定: 「判断してほしい点」の7つ、影響: プロンプトと検査はコードとテストが正で、変えるときは本記録を直す、未確認: 案の質・指定した角度への忠実さ・実データでの傾向・ガードレールの誤検知の頻度・IME/VoiceOver）。`docs/decisions/README.md`の一覧に足す。

- [ ] **Step 2: 仕様・README・Architectureを実装に合わせる**

- `specification.md`冒頭: 「実装済み」に名前の案・問いの具体化を足し、「未実装」はテーマからのClaude連携だけにする。§5.1の3つの提案が揃ったことを書く。PRD-12の欄があれば合わせる。
- `README.md`: まとまりからテーマを作るときの「案: …［使う］」、レンズの問いの「AIの案」カード（採用／別の案／閉じる）、Settingsの状態、案は自動では何も書き換えないこと、モデルが使えなくても手動で変わらないこと。
- `architecture.md` §3.1の「名前」「レンズの具体化」に、検査（先頭1行・長さ・疑問で終わる）、入力の上限（新しい16件・各120文字）、10秒の期限、「案を出してよい問い」の条件、`GenerationError`を型で受けないことを書き足す。

- [ ] **Step 3: 合成インスタンスでの実操作**

AGENTS.mdの手順に従う。本人の実Feeederには触れない。リリースビルドを`/private/tmp`へコピーして別Bundle IDにして署名し直し、一時の`--data-directory`で起動する。**この環境には実物のモデルがあるので、案が実際に出る**。まとまりのある合成データ（金利4・睡眠4・AI4の記事を全部Star済み）を、使い捨てのテスト（コミットしない）でストアに書いてから起動し、`pgrep -fl RSSReader`で引数に一時のデータディレクトリが含まれることを確認し、computer-useの許可はその別Bundle IDにだけ求める。確認する項目と、背景入力の限界（ポップオーバーが開いていると、別の操作が通らないことがある）:

1. 「未整理のStar」→まとまりの提案→「n件でテーマにする…」: 約1秒で「案: …」が出る。「使う」で入力欄に入る。入力欄が自動では埋まらない。
2. 作ったテーマの問いの面で「問いを立てる」→レンズ: 定型の問いがすぐ入り、約1秒後に「AIの案」が出る。「採用」で問いの文が置き換わる。「閉じる」「別の案」。問いを直すと案が消える。
3. Settingsの「端末内AI」: 「テーマ名・問いの案」が「使えます」。スイッチをオフにすると両方「オフ」で、まとまりの名前の案・問いの案が出ない。
4. 案が出ないとき（検査で弾かれる／失敗）に、スピナーが残らず、手動の操作ができる（再現しにくいので、無理に作らず未検証にしてよい）。

終わったら、確認済みの一時プロセスだけを終了し、一時ディレクトリを削除し、`app_release`する。

- [ ] **Step 4: 検証記録を書く**

`docs/verification/2026-10-10-theme-ai-names.md`に、環境、自動検証（全テスト・Releaseビルド・署名・`git diff --check`・各変異確認）、実物のスモークの出力（`NAME`・`QUESTION`の生の出力と検査後の結果。**生成された名前・問いの質は筆者（Claude）が読んだ所見で、PdMの判断は別**）、実操作の結果、独立レビューの結果と対応、未検証（実データでの質、角度への忠実さ、ガードレールの誤検知の頻度、案の到着と本人の入力が重なる実機の挙動、IME・VoiceOver、macOS 26のCI）を書く。

- [ ] **Step 5: 最終確認と独立レビュー**

全テスト、Releaseビルド、署名検証、`git diff --check`を通す。並行処理（取消・期限・古い応答の破棄）と、モデルの出力を画面へ出す経路を含むので、固定commitを`opus`の独立レビューに出す（読み取り専用、`docs/review-checklist.md`を使う）。焦点は、出力の検査の抜け、`isEnabled`の再読み込み、スピナーの取り残し、期限・取消の後始末、編集済みの問いへの上書き、プロンプトが入力量の上限に収まるか、試験が判別できるか（変異で落ちるか）、文書と挙動の一致。Critical・Importantは失敗するテストを先に書いて直す。

- [ ] **Step 6: push・PR**

ブランチ`claude/theme-ai-names`をpushし、確認を待たずにPRを作る（本人の標準指示）。本文に、含まないもの（テーマからのClaude連携＝PR 8、名前変更、既存テーマの名前変更・`t`での名前の案）、検証、未検証、判断してほしい点7つへの参照を書く。CIが落ちたら、まずSwift 6.3.3のコンパイラクラッシュや、`@MainActor`クロージャでの可変変数の捕捉を疑う。mergeはしない。

---

## 自己レビュー

**仕様の網羅**（§3.3・§5.1・決定0009のうちこのPR分）: テーマ名の案→Task 1〜4。レンズの具体化（1回1問・失敗時は定型文・60字以内相当）→Task 1〜4（定型の問いは常に先に入り、案は別カード）。入力量の上限と「提案に使った件数」→プロンプトは新しい16件に切る（件数の表示は、生成の案では出さない。決定0011に明記する）。失敗・ガードレール・上限超過・取消が手動を止めない→Task 2〜4。無効のとき呼ばない→Task 2。プレーンテキストと出力上限、構造化出力に頼らない→Task 3。自動書き込みをしない→Task 4。Claude連携はPR 8。

**型の整合**: `SuggestionPrompts.Request`はTask 1で定義し、Task 2の`ThemeAssistant.generate`・Task 3の`TextGenerating`が使う。`SuggestionText`・`QuestionProposalEligibility`はTask 1、`proposeName`・`proposeQuestion`はTask 2で定義し、Task 4の画面が使う。`withDeadline`・`DeadlineExceeded`はTask 3で定義し、同じTaskの`OnDeviceThemeAssistant`が使う。

**プレースホルダー走査**: 「TBD」の類は無い。Task 4のスピナーの取り残しは、実装時に確認する項目として明記した（コードは動く形で示してある）。

**コードの事前確認**（Swift 6.4、macOS 27.0.1）: Task 1〜3のコードと試験は、計画の記述を一時的にリポジトリへ置き、全テスト（179件）が通ることを確認してから取り除いた。この確認で、定型の問いが「「テーマ名」…」で始まるため、先頭の引用符を取る処理が定型文そのものを壊す不具合を見つけ、**全体を囲む引用符の対だけを外す**形に直した（`aFixedLensQuestionPassesThroughUnchanged`）。Task 4・5の画面部分は、まだコンパイルしていない。実装時にコンパイルエラーが出たら、期待値ではなく型・APIを直す。

**実物のモデルの先行観察**（任意スモークをそのまま一度実行。合成の日本語3分野）: 名前は「家計の金利負担と経済変動」「睡眠の質と体内時計」「大規模言語モデルの推論最適化」で、検査はすべて通った（3件目はAIの記事3件のうち2件の話題に寄っている）。問い（前提を疑う）は3件とも疑問文で、検査を通った。ただし、角度への忠実さ・自然さは筆者の読みで、PdMの判断は別。

