# 端末内AI①: 近いテーマ・まとまりの提案（PR 6）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する（[決定0002](../../decisions/0002-single-supervised-writer.md)）。

**Goal:** `t`の選択に「近いテーマ」を、「未整理のStar」に「まとまりの提案」を、端末内の埋め込みだけで出す。AIを無効にしても、資産が無くても、失敗しても、手動の操作は何も変わらない。

**Architecture:** 計算の中心は`ReaderCore`の純粋関数（コサイン類似度・中心化・平均連結クラスタリング・近いテーマの順位付け）と、`ThemeAssistant`プロトコル、その結果を要求IDで検査して画面へ渡す`ThemeSuggestionModel`。実物の`OnDeviceThemeAssistant`（`NLContextualEmbedding`）はアプリ側に置き、テストは偽の埋め込みと偽の`ThemeAssistant`で行う。画面は、`t`のポップオーバーの並び替え、「未整理のStar」上部の提案帯、Settingsの「端末内AI」タブ。

**Tech Stack:** Swift 6、SwiftUI、SwiftData、NaturalLanguage（`NLContextualEmbedding`、`NLLanguageRecognizer`）、Swift Testing。外部依存の追加なし。`FoundationModels`はこのPRでは使わない（PR 7）。

**Spec:** [PRD](../../specification.md)第5.1節・PRD-06・PRD-13、[Architecture](../../architecture.md)第3.1節、[決定0009](../../decisions/0009-on-device-ai-principles.md)、[spike](../../verification/2026-10-10-on-device-ai-spike.md)。ロードマップは[theme-notes計画](2026-10-10-theme-notes.md)のPR 6。前提のPR 3〜5は[#23](https://github.com/ojiman/feeeder/pull/23)・[#25](https://github.com/ojiman/feeeder/pull/25)・[#27](https://github.com/ojiman/feeeder/pull/27)でマージ済み（main `e9bcd93`）。本計画はこのPRのマージで承認される。計画承認を最終製品受入とは扱わない。

## 判断してほしい点（このPRのマージが承認になる）

迷ったときの基準は、ユーザー体験の最大化と、本人の「速くなめらかに、掘り起こして再発見する」という方向（[Mogura/Unagi](../../../README.md)は未改名）。次の7点を、私が選んだ側で計画に入れている。違う側がよければ、マージ前に指摘してほしい。

1. **`t`で近いテーマを先頭に並べる**。入力が空のとき、近いテーマを上に出し、「近い」の印を付ける。既定のハイライトは先頭の行のままなので、`t`→Returnで一番近いテーマに入る。ただし、提案が届く前に入力・↑↓・クリックをしていたら、並びは変えない（指の下で行が動かない）。代案: 並びは変えず、印だけ付ける。
2. **まとまりの提案は、「未整理のStar」を開いたときに自動で計算する**（0.5秒待ってからバックグラウンドで）。ボタンを押させない。未整理が3件未満なら何もしない。代案: 「まとまりを探す」ボタン。
3. **中心化の基準に、ライブラリの新しい記事40件を足す**。spikeは分野が分かれた36件自身の平均を引いていたが、実際の「未整理のStar」は数件のことも多く、少数の平均は不安定になる。40件の新しい記事（購読を横断）を背景として加え、平均を安定させる。実物のライブラリでの効果は未検証。
4. **数値**: 類似度の閾値は、まとまり・近いテーマとも0.15（spikeの値）。「未整理のStar」は新しい120件まで、テーマごとの比較対象は新しい10件まで、近いテーマは上位3つ、まとまりは上位5つ、2件未満の塊は出さない。すべて`SuggestionTuning`に集め、後で調整できるようにする。実データでの妥当性は未検証。
5. **英語など日本語以外の記事**: 日本語は日本語の埋め込み、ラテン文字の言語（英語など）はラテン文字用の埋め込みを使い、**空間が違う記事どうしは比べない**。日本語でもラテン文字でもない言語の記事は提案の対象にしない（手動操作は変わらない）。
6. **既定は有効**。Settingsに「端末内AI」タブを追加し、切るとモデルも埋め込みも一切呼ばない（可否の確認もしない）。資産が端末に無い場合、アプリは取得を要求せず、「端末に資産がありません」と案内するだけ。
7. **テーマ名はこのPRでは提案しない**。まとまりから作るテーマの名前は本人が入力する（名前案はPR 7）。

## Global Constraints

- サポート下限はmacOS 27.0、ビルド下限はmacOS 26.6のまま。`NLContextualEmbedding`はこの下限で使える。macOS 27 SDK専用のAPIは使わない（[決定0007](../../decisions/0007-support-floor-macos-27.md)）。
- 外部通信・アカウント・APIキー・BYOK・Private Cloud Computeを使わない。**アプリが資産の取得（`requestAssets`など）を自動で起こさない**（[決定0009](../../decisions/0009-on-device-ai-principles.md)4）。
- AIは提案だけ。答え・いまの理解・テーマ名・テーマへの所属を自動で書き込まない。採用・編集・破棄は本人が決める。
- Settingsで無効にでき、無効のときはモデルも埋め込みも呼ばない。利用不可・失敗・取消・上限超過は「提案が出ない」だけで、すべての操作を手動で続けられる。
- 入力は保持中の内容（タイトル・RSS要約）とテーマが記録した要約に限り、期限切れ全文を使わない。ベクトルは保存せず、必要なときに計算する（プロセス内のキャッシュは可。再起動で消える）。
- 計算はMainActorを塞がない。結果は要求ごとのIDで検査し、画面が移った後の遅延応答を捨てる。
- 新しい変更経路（`createTheme(name:adding:[UUID])`）は先頭で`reloadIfNeeded()`を呼び、保存／再読み込みの失敗注入試験の2つの一覧に加える。失敗後はIDから現在のモデルを解決する。
- テキスト入力・IME変換・修飾キー付き操作を優先する既存の規則を守る。`Binding`のsetterにメソッド参照を渡さず、明示的なクロージャを使う（CIのSwift 6.3.3が落ちる。PR #14・#27）。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・Keychain・ブラウザprofileを使わない。1PR1テーマ。バグ・新機能は失敗するテストを先に書く。コミット／PRの末尾にはセッションが指定する共著表記を付ける。
- 署名・配布・Tag／Release、`main`への直接pushをしない。実装完了後は、確認を待たずにブランチをpushしてPRを作る（本人の標準指示）。

## Review Focus

仕様が暗黙に求めているが、通常のテストでは見落としやすい入力・失敗を、起きやすい順に挙げる。担当Taskにそれぞれ試験を置く。

1. 提案の計算中に、別の記事へ移る／ポップオーバーを閉じる／AIを切る。遅れて届いた結果が、今の画面に出ない（古い結果で上書きしない）→ Task 3・5。
2. AIが無効、資産が無い、埋め込みが失敗する。モデルも埋め込みも呼ばない（無効のとき）／提案が出ないだけで、`t`・Star・テーマ作成は変わらない → Task 3・4。
3. 英語・日本語の混在、要約が空・期限切れでタイトルだけ、空白だけの記事。クラッシュせず、空間の違うベクトルを比べない → Task 2・4。
4. テーマが0個、記事が1件だけのテーマ、「未整理のStar」が2件以下。提案なしで、クラッシュしない → Task 2・3。
5. 「未整理のStar」が数百件。新しい120件に絞り、使った件数を示し、MainActorを塞がない（速度は実測を未検証として残す）→ Task 3・5。
6. 提案が届いたとき、利用者がすでに入力・↑↓をしていたら、ハイライトが動かない → Task 5。
7. まとまりからテーマを作る途中で保存が失敗する。空のテーマも一部の記事だけのテーマも残らず、再試行できる → Task 1。

---

## ファイル構成

| ファイル | 責務 |
|---|---|
| `Sources/ReaderCore/Themes.swift`（変更） | `createTheme(name:adding:[UUID])`（まとまりから作る、1回の保存） |
| `Sources/ReaderCore/ThemeClustering.swift`（新規） | 埋め込みの数学（コサイン、中心化、平均連結クラスタリング、近いテーマの順位）と`SuggestionTuning` |
| `Sources/ReaderCore/ThemeAssistant.swift`（新規） | `ThemeAssistant`プロトコルと入出力の型、`ThemeSuggestionModel`（要求ID・上限・有効／無効・結果の検査） |
| `Sources/ReaderCore/ThemePicker.swift`（変更） | 近いテーマを先頭へ並べ替える純粋ロジック |
| `Sources/RSSReader/OnDeviceThemeAssistant.swift`（新規） | `TextEmbedder`、`ContextualTextEmbedder`（`NLContextualEmbedding`）、`OnDeviceThemeAssistant` |
| `Sources/RSSReader/ThemePickerView.swift`（変更） | 近いテーマの取り込み・印・ハイライトの扱い |
| `Sources/RSSReader/ClusterSuggestionsView.swift`（新規） | 「未整理のStar」の提案帯と、まとまりのポップオーバー |
| `Sources/RSSReader/ReaderSettingsView.swift`（変更） | 「端末内AI」タブ |
| `Sources/RSSReader/ReaderView.swift`・`RSSReaderApp.swift`（変更） | モデルの受け渡し、提案帯、自動計算のトリガー、有効／無効 |
| `Tests/ReaderCoreTests/ThemeTests.swift`（変更） | まとまりからの作成、失敗注入の一覧への追加 |
| `Tests/ReaderCoreTests/ThemeClusteringTests.swift`（新規） | 数学の試験 |
| `Tests/ReaderCoreTests/ThemeSuggestionModelTests.swift`（新規） | モデルと偽の`ThemeAssistant` |
| `Tests/ReaderCoreTests/ThemePickerTests.swift`（変更） | 並び替え |
| `Tests/ReaderUITests/OnDeviceThemeAssistantTests.swift`（新規） | 偽の埋め込みでの試験、`requestAssets`不使用の検査、実物の任意スモーク |

検証コマンド（以降のTaskで使う）: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter <名前>`。CIの条件は`--scratch-path /private/tmp/feeeder-ci-build --force-resolved-versions --disable-keychain --disable-netrc`（AGENTS.md）。

---

### Task 1: まとまりからテーマを作る（1回の保存）

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift`（`createTheme(name:adding:at:)`の隣）
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: 既存の`recordedSummary(of:at:)`、`reloadIfNeeded()`、`save()`、`reload()`
- Produces: `@discardableResult public func createTheme(name: String, adding articleIDs: [UUID], at: Date) throws -> Theme`。重複IDは1つにまとめ（順序は保つ）、IDが1つでも存在しなければ`ThemeError.missingArticle`で何も保存しない。空のIDリストは空のテーマを作る。

- [ ] **Step 1: 失敗するテストを書く**

`ThemeTests`に追加する（`at`は既存のプロパティ）。

```swift
    @Test func createThemeFromAGroupAddsEveryArticleInOneSave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = Array(store.articles.prefix(3).map(\.id))
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        #expect(store.unfiledStarCount == 3)
        let theme = try store.createTheme(name: "  金利と家計  ", adding: [ids[0], ids[1], ids[1], ids[2]], at: at)
        #expect(theme.name == "金利と家計")
        #expect(store.themeArticleIDs(themeID: theme.id) == store.articleIDs.filter { ids.contains($0) })
        #expect(store.themeArticleCount(themeID: theme.id) == 3 && store.unfiledStarCount == 0)
        let link = try #require(store.themeArticles.first { $0.articleID == ids[0] })
        #expect(link.title == store.article(id: ids[0])?.title)
    }

    @Test func createThemeFromAGroupRejectsBadInputAndChangesNothing() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(throws: ThemeError.self) { try store.createTheme(name: "  ", adding: [id], at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "A", adding: [id, UUID()], at: at) }
        #expect(store.themes.isEmpty && store.themeArticles.isEmpty)
        let empty = try store.createTheme(name: "空", adding: [UUID](), at: at)
        #expect(store.themeArticleCount(themeID: empty.id) == 0)
    }
```

失敗注入の2つの一覧にも加える。`failedSaveLeavesNoPartialThemeStateAndCanBeRetried`では、`deleteQuestion`の失敗確認の後ろ（`removeArticle`の前）に、`eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds`では、`deleteQuestion`の後ろ（`deleteTheme`の前）に置く。

```swift
        // failedSaveLeavesNoPartialThemeStateAndCanBeRetried: 前のテーマ数を数えてから
        let themeCount = store.themes.count, linkCount = store.themeArticles.count
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失われる束", adding: [ids[0], ids[1]], at: at) }
        #expect(store.themes.count == themeCount && store.themeArticles.count == linkCount)
```

```swift
        // eachThemeChangeRecoversOnItsFirstCallAfterReloadSucceeds
        induceFailedRecovery()
        let grouped = try store.createTheme(name: "束", adding: [ids[3]], at: at)
        #expect(store.themeArticleCount(themeID: grouped.id) == 1)
```

（`ids`は両テストで既存。`eachTheme…`では`ids[3]`が使えること＝デモの記事が4件以上であることを確認する。足りなければ`ids[2]`を使い、`ids[2]`が先に別のテーマへ入っていても重複追加の影響が無いことを確認する。）

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: コンパイルエラー（`createTheme(name:adding:at:)`に配列を渡すオーバーロードが無い）。

- [ ] **Step 3: 最小の実装**

`Themes.swift`の`createTheme(name:adding articleID:…)`の直後に追加する。

```swift
    /// Creates the theme and all of its articles in one save, so a failure leaves neither an empty theme nor a partial one.
    /// Duplicate IDs collapse (order kept); a missing article rejects the whole request.
    @discardableResult public func createTheme(name: String, adding articleIDs: [UUID], at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        var seen = Set<UUID>()
        let unique = articleIDs.filter { seen.insert($0).inserted }
        let articles = try unique.map { id -> Article in
            guard let article = article(id: id) else { throw ThemeError.missingArticle }
            return article
        }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        for article in articles {
            context.insert(ThemeArticle(themeID: theme.id, article: article, summary: recordedSummary(of: article, at: at), at: at))
        }
        try save(); try reload()
        return theme
    }
```

- [ ] **Step 4: 通ることを確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: 全件PASS。続けて、変異確認として、`for article in articles {…}`の`context.insert`を一時的に`articles.prefix(1)`へ変え、「3件入る」の試験が落ちることを確認してから戻す（戻すのは該当行の置換で行い、`git checkout`は使わない）。

- [ ] **Step 5: コミット**

```bash
git add Sources/ReaderCore/Themes.swift Tests/ReaderCoreTests/ThemeTests.swift
git commit -m "feat: まとまりから、記事を束ねたテーマを1回の保存で作る"
```

---

### Task 2: 埋め込みの数学（純粋関数）

**Files:**
- Create: `Sources/ReaderCore/ThemeClustering.swift`
- Test: `Tests/ReaderCoreTests/ThemeClusteringTests.swift`

**Interfaces:**
- Produces: `EmbeddedItem(id:space:vector:)`、`ThemeMatch(themeID:score:)`、`SuggestionTuning`（定数）、`EmbeddingMath.cosine(_:_:) -> Float?`、`EmbeddingMath.centered(_:) -> [EmbeddedItem]`、`ThemeClustering.clusters(of:threshold:) -> [[UUID]]`、`ThemeRanking.nearest(articleID:pool:candidates:threshold:limit:) -> [ThemeMatch]`。いずれも`public`・`Sendable`。

下のコードは、使い捨てのスクリプトでコンパイルと基本の動作（分野の分かれた4件が2塊と単独に分かれる、空・1件で落ちない、最も近いテーマが先頭に来る）を確認済み。

- [ ] **Step 1: 失敗するテストを書く**

```swift
import Foundation
import Testing
@testable import ReaderCore

struct ThemeClusteringTests {
    let ids = (0..<10).map { _ in UUID() }
    func item(_ index: Int, _ vector: [Float], space: String = "ja") -> EmbeddedItem {
        EmbeddedItem(id: ids[index], space: space, vector: vector)
    }
    func indices(_ groups: [[UUID]]) -> [[Int]] { groups.map { $0.map { id in ids.firstIndex(of: id)! } } }

    @Test func cosineHandlesMismatchedEmptyAndZeroVectors() {
        #expect(EmbeddingMath.cosine([1, 0], [1, 0]) == 1)
        #expect(EmbeddingMath.cosine([1, 0], [0, 1]) == 0)
        #expect(EmbeddingMath.cosine([1, 0], [-1, 0]) == -1)
        #expect(EmbeddingMath.cosine([1, 0], [1]) == nil)
        #expect(EmbeddingMath.cosine([], []) == nil)
        #expect(EmbeddingMath.cosine([0, 0], [1, 1]) == nil)
    }

    @Test func centeringSubtractsEachSpacesOwnMean() {
        let items = [item(0, [2, 0]), item(1, [4, 0]), item(2, [100, 100], space: "latin")]
        let centered = EmbeddingMath.centered(items)
        #expect(centered[0].vector == [-1, 0] && centered[1].vector == [1, 0])
        #expect(centered[2].vector == [0, 0])            // a space with one item has no direction left
        #expect(centered.map(\.id) == items.map(\.id))
    }

    @Test func clustersSeparateTopicsAndLeaveSingletonsAlone() {
        let items = EmbeddingMath.centered([
            item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [5, 5, 12])
        ])
        let groups = ThemeClustering.clusters(of: items, threshold: SuggestionTuning.clusterThreshold)
        #expect(indices(groups) == [[0, 1], [2, 3], [4]])
    }

    @Test func clustersAreDeterministicOrderedBySizeThenPosition() {
        let items = EmbeddingMath.centered([
            item(0, [0, 10, 1]), item(1, [10, 1, 0]), item(2, [10, 0, 1]), item(3, [1, 10, 0]), item(4, [10, 1, 1])
        ])
        let first = indices(ThemeClustering.clusters(of: items, threshold: 0.15))
        #expect(first == [[1, 2, 4], [0, 3]])             // larger first; members keep input order
        #expect(first == indices(ThemeClustering.clusters(of: items, threshold: 0.15)))
    }

    @Test func differentSpacesNeverMergeAndDegenerateInputIsSafe() {
        let mixed = [item(0, [1, 0], space: "ja"), item(1, [1, 0], space: "latin")]
        #expect(indices(ThemeClustering.clusters(of: mixed, threshold: -1)) == [[0], [1]])
        #expect(ThemeClustering.clusters(of: [], threshold: 0.15).isEmpty)
        #expect(indices(ThemeClustering.clusters(of: [item(0, [1, 0])], threshold: 0.15)) == [[0]])
        #expect(indices(ThemeClustering.clusters(of: [item(0, [0, 0]), item(1, [0, 0])], threshold: 0.15)) == [[0], [1]])
    }

    @Test func aHighThresholdKeepsEverythingApart() {
        let items = EmbeddingMath.centered([item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1])])
        #expect(ThemeClustering.clusters(of: items, threshold: 1.1).count == 3)
    }

    @Test func nearestRanksThemesByTheirClosestMembersAndHonorsThresholdAndLimit() {
        let finance = UUID(), cooking = UUID(), empty = UUID()
        let pool = [item(0, [10, 1, 0]), item(1, [10, 0, 1]), item(2, [0, 10, 1]), item(3, [1, 10, 0]),
                    item(4, [5, 5, 12]), item(5, [-6, -6, 6]), item(6, [-8, 4, -4])]
        let matches = ThemeRanking.nearest(articleID: ids[0], pool: pool,
            candidates: [(cooking, [ids[2], ids[3]]), (finance, [ids[1]]), (empty, [])])
        #expect(matches.map(\.themeID) == [finance])      // cooking is below the threshold, the empty theme has no members
        #expect(matches[0].score > SuggestionTuning.nearestThreshold)
        let limited = ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(cooking, [ids[2]]), (finance, [ids[1]])],
                                           threshold: -1, limit: 1)
        #expect(limited.map(\.themeID) == [finance])
    }

    @Test func nearestSkipsTheArticleItselfAndOtherSpacesAndUnknownIDs() {
        let theme = UUID()
        let pool = [item(0, [10, 1, 0]), item(1, [10, 0, 1], space: "latin"), item(2, [0, 10, 1]), item(3, [1, 10, 0]), item(4, [-9, -9, 9])]
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(theme, [ids[0], ids[1], UUID()])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: UUID(), pool: pool, candidates: [(theme, [ids[2]])]).isEmpty)
        #expect(ThemeRanking.nearest(articleID: ids[0], pool: [], candidates: [(theme, [ids[2]])]).isEmpty)
    }

    @Test func nearestBreaksScoreTiesByThemeID() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let pool = [item(0, [10, 1, 0]), item(1, [10, 1, 0]), item(2, [-5, 4, 4]), item(3, [-5, -4, -4])]
        let matches = ThemeRanking.nearest(articleID: ids[0], pool: pool, candidates: [(b, [ids[1]]), (a, [ids[1]])], threshold: -1)
        #expect(matches.map(\.themeID) == [a, b])
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeClusteringTests`
Expected: コンパイルエラー（`EmbeddedItem`などが無い）。

- [ ] **Step 3: 実装**

`Sources/ReaderCore/ThemeClustering.swift`を新規作成する。

```swift
import Foundation

/// A text turned into a vector. Vectors from different `space`s (embedding models) are never compared.
public struct EmbeddedItem: Sendable, Equatable {
    public let id: UUID
    public let space: String
    public let vector: [Float]
    public init(id: UUID, space: String, vector: [Float]) { self.id = id; self.space = space; self.vector = vector }
}

public struct ThemeMatch: Sendable, Equatable {
    public let themeID: UUID
    public let score: Float
    public init(themeID: UUID, score: Float) { self.themeID = themeID; self.score = score }
}

/// Tunable numbers for the on-device suggestions. Values come from the synthetic spike
/// (docs/verification/2026-10-10-on-device-ai-spike.md); their fit to real libraries is unverified.
public enum SuggestionTuning {
    public static let clusterThreshold: Float = 0.15
    public static let nearestThreshold: Float = 0.15
    public static let nearestTopSimilarities = 3
    public static let maximumSuggestedThemes = 3
    public static let minimumClusterSize = 2
    public static let minimumItemsToCluster = 3
    public static let maximumClusters = 5
    public static let maximumClusterItems = 120
    public static let maximumMembersPerTheme = 10
    public static let backgroundItems = 40
    public static let textCharacterLimit = 300
}

public enum EmbeddingMath {
    /// Cosine similarity; nil when the vectors differ in length, are empty, or one has no length.
    public static func cosine(_ a: [Float], _ b: [Float]) -> Float? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for index in a.indices { dot += a[index] * b[index]; na += a[index] * a[index]; nb += b[index] * b[index] }
        guard na > 0, nb > 0 else { return nil }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    /// Subtracts each space's mean from its items. Without this every vector points the same way and all
    /// items look alike (spike §1). Items keep their order; a space with a single item becomes the zero vector.
    public static func centered(_ items: [EmbeddedItem]) -> [EmbeddedItem] {
        var sums: [String: [Float]] = [:], counts: [String: Int] = [:]
        for item in items {
            var sum = sums[item.space] ?? [Float](repeating: 0, count: item.vector.count)
            guard sum.count == item.vector.count else { continue }
            for index in item.vector.indices { sum[index] += item.vector[index] }
            sums[item.space] = sum; counts[item.space, default: 0] += 1
        }
        return items.map { item in
            guard let sum = sums[item.space], sum.count == item.vector.count, let count = counts[item.space] else { return item }
            let mean = sum.map { $0 / Float(count) }
            return EmbeddedItem(id: item.id, space: item.space, vector: zip(item.vector, mean).map { $0 - $1 })
        }
    }
}

public enum ThemeClustering {
    /// Average-linkage agglomerative clustering of (already centered) vectors. Clusters never mix spaces.
    /// Deterministic: members keep input order; clusters are ordered by size (largest first), then by first member.
    public static func clusters(of items: [EmbeddedItem], threshold: Float) -> [[UUID]] {
        let count = items.count
        guard count > 0 else { return [] }
        var sums = [[Float]](repeating: [Float](repeating: -.infinity, count: count), count: count)
        for i in 0..<count {
            for j in (i + 1)..<max(count, i + 1) where j < count {
                let similarity = items[i].space == items[j].space ? EmbeddingMath.cosine(items[i].vector, items[j].vector) : nil
                sums[i][j] = similarity ?? -.infinity; sums[j][i] = sums[i][j]
            }
        }
        var members = (0..<count).map { [$0] }
        var alive = Array(0..<count)
        while alive.count > 1 {
            var best: (Float, Int, Int)?
            for a in 0..<alive.count {
                for b in (a + 1)..<alive.count {
                    let i = alive[a], j = alive[b]
                    let average = sums[i][j] / Float(members[i].count * members[j].count)
                    if average >= threshold, best == nil || average > best!.0 { best = (average, a, b) }
                }
            }
            guard let (_, a, b) = best else { break }
            let i = alive[a], j = alive[b]
            for other in alive where other != i && other != j { sums[i][other] += sums[j][other]; sums[other][i] = sums[i][other] }
            members[i] += members[j]; members[j] = []
            alive.remove(at: b)
        }
        let position = Dictionary(items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        return alive.map { members[$0].sorted().map { items[$0].id } }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : (position[lhs[0]] ?? 0) < (position[rhs[0]] ?? 0)
            }
    }
}

public enum ThemeRanking {
    /// Themes whose members are most similar to one article. A theme's score is the mean of its (up to) three
    /// highest member similarities. `pool` must hold the article, every candidate member and the background items;
    /// it is centered here.
    public static func nearest(articleID: UUID, pool: [EmbeddedItem], candidates: [(themeID: UUID, memberIDs: [UUID])],
                               threshold: Float = SuggestionTuning.nearestThreshold,
                               limit: Int = SuggestionTuning.maximumSuggestedThemes) -> [ThemeMatch] {
        let centered = EmbeddingMath.centered(pool)
        let byID = Dictionary(centered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let article = byID[articleID] else { return [] }
        let matches = candidates.compactMap { candidate -> ThemeMatch? in
            let similarities = candidate.memberIDs.compactMap { id -> Float? in
                guard id != articleID, let member = byID[id], member.space == article.space else { return nil }
                return EmbeddingMath.cosine(article.vector, member.vector)
            }.sorted(by: >)
            guard !similarities.isEmpty else { return nil }
            let top = similarities.prefix(SuggestionTuning.nearestTopSimilarities)
            let score = top.reduce(0, +) / Float(top.count)
            return score >= threshold ? ThemeMatch(themeID: candidate.themeID, score: score) : nil
        }
        return matches.sorted { $0.score != $1.score ? $0.score > $1.score : $0.themeID.uuidString < $1.themeID.uuidString }
            .prefix(limit).map { $0 }
    }
}
```

- [ ] **Step 4: 通ることを確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeClusteringTests`
Expected: 全件PASS。通らない試験があれば、**試験の期待値を実装に合わせて書き換える前に**、手計算（コサイン・中心化）で期待値が正しいかを確かめる。数値は手で検算できる小さなベクトルにしてある。変異確認として、`centered`の平均減算を外して（`mean`を0にして）`clustersSeparateTopicsAndLeaveSingletonsAlone`が落ちることを確認してから戻す。

- [ ] **Step 5: コミット**

```bash
git add Sources/ReaderCore/ThemeClustering.swift Tests/ReaderCoreTests/ThemeClusteringTests.swift
git commit -m "feat: 埋め込みの中心化・クラスタリング・近いテーマの順位付けを純粋関数として追加する"
```

---

### Task 3: `ThemeAssistant`と`ThemeSuggestionModel`

**Files:**
- Create: `Sources/ReaderCore/ThemeAssistant.swift`
- Test: `Tests/ReaderCoreTests/ThemeSuggestionModelTests.swift`

**Interfaces:**
- Consumes: Task 2の`ThemeMatch`・`SuggestionTuning`、`ReaderStore`の`articles`・`themes`・`themeArticles`・`article(id:)`・`theme(id:)`・`unfiledStarredArticleIDs(keeping:)`・`isContentAvailable(_:at:)`
- Produces:
  - `SuggestionItem(id:text:)`、`ThemeCandidateInput(themeID:members:)`、`AssistantAvailability`（`.available/.assetsMissing/.unsupported`）
  - `protocol ThemeAssistant: Sendable { availability(); nearestThemes(for:candidates:background:); clusters(of:background:) }`
  - `@Observable @MainActor final class ThemeSuggestionModel`: `nearestArticleID`・`nearestThemes`・`clusters`（`Clusters{groups,usedCount,totalCount}`）・`isFindingClusters`・`availability`、`init(store:assistant:isEnabled:now:)`、`loadNearest(for:)`・`loadClusters()`・`invalidate()`・`invalidateClusters()`・`refreshAvailability()`

- [ ] **Step 1: 失敗するテストを書く**

```swift
import Foundation
import Testing
@testable import ReaderCore

/// Scripted stand-in for the real model. A held call parks until released, so tests can finish requests in any order.
actor FakeAssistant: ThemeAssistant {
    struct NearestCall: Sendable { let item: SuggestionItem; let candidates: [ThemeCandidateInput]; let background: [SuggestionItem] }
    struct ClusterCall: Sendable { let items: [SuggestionItem]; let background: [SuggestionItem] }
    private var availabilityValue = AssistantAvailability.available
    private var nearestByArticle: [UUID: [ThemeMatch]] = [:]
    private var groups: [[UUID]] = []
    private var failure: (any Error)?
    private var holding = false
    private(set) var nearestCalls: [NearestCall] = []
    private(set) var clusterCalls: [ClusterCall] = []
    private(set) var availabilityCalls = 0
    private var parked: [UUID: CheckedContinuation<Void, Never>] = [:]
    private var parkedClusters: CheckedContinuation<Void, Never>?

    func script(nearest: [UUID: [ThemeMatch]] = [:], groups: [[UUID]] = [], failure: (any Error)? = nil, hold: Bool = false,
                availability: AssistantAvailability = .available) {
        nearestByArticle = nearest; self.groups = groups; self.failure = failure; holding = hold; availabilityValue = availability
    }
    var parkedCount: Int { parked.count + (parkedClusters == nil ? 0 : 1) }
    func release(article id: UUID) { parked.removeValue(forKey: id)?.resume() }
    func releaseClusters() { parkedClusters?.resume(); parkedClusters = nil }

    func availability() async -> AssistantAvailability { availabilityCalls += 1; return availabilityValue }
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch] {
        nearestCalls.append(NearestCall(item: item, candidates: candidates, background: background))
        if holding { await withCheckedContinuation { parked[item.id] = $0 } }
        if let failure { throw failure }
        return nearestByArticle[item.id] ?? []
    }
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]] {
        clusterCalls.append(ClusterCall(items: items, background: background))
        if holding { await withCheckedContinuation { parkedClusters = $0 } }
        if let failure { throw failure }
        return groups
    }
}

@MainActor struct ThemeSuggestionModelTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    struct Boom: Error {}

    /// `count` synthetic articles, newest first: 記事 0 is the newest.
    func makeStore(_ library: TestLibrary, articles count: Int) throws -> ReaderStore {
        let store = try ReaderStore(url: library.url, now: at)
        let entries = (0..<count).map { index in
            ParsedEntry(sourceID: "s-\(index)", title: "記事 \(index)", url: URL(string: "https://synthetic.example/\(index)"),
                        summary: "要約 \(index)", body: "本文 \(index)", coverage: .feedProvided,
                        publishedAt: at.addingTimeInterval(Double(-index) * 60))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "https://synthetic.example/feed")!,
                                            entries: entries, skippedEntries: 0), receivedAt: at)
        return store
    }
    func model(_ store: ReaderStore, _ assistant: (any ThemeAssistant)?, enabled: Bool = true) -> ThemeSuggestionModel {
        ThemeSuggestionModel(store: store, assistant: assistant, isEnabled: { enabled }, now: { self.at })
    }
    func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        let reached = await condition()
        #expect(reached, "condition not reached")
    }

    @Test func aDisabledOrMissingAssistantIsNeverCalledAndLeavesNothing() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[1].id], at: at)
        let fake = FakeAssistant()
        let off = model(store, fake, enabled: false)
        await off.loadNearest(for: store.articles[0].id)
        for id in store.articles.prefix(3).map(\.id) { try store.setStar(articleID: id, isStarred: true, at: at) }
        await off.loadClusters(); await off.refreshAvailability()
        let (nearestCalls, clusterCalls, availabilityCalls) = (await fake.nearestCalls, await fake.clusterCalls, await fake.availabilityCalls)
        #expect(nearestCalls.isEmpty && clusterCalls.isEmpty && availabilityCalls == 0)
        #expect(off.nearestThemes.isEmpty && off.clusters == .empty && off.availability == nil)
        let none = model(store, nil)
        await none.loadNearest(for: store.articles[0].id); await none.loadClusters(); await none.refreshAvailability()
        #expect(none.nearestThemes.isEmpty && none.clusters == .empty && none.availability == .unsupported)
        _ = theme
    }

    @Test func nearestSendsSnapshotCandidatesNewestFirstCappedAndAnItemWithSummary() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 70)
        let ids = store.articles.map(\.id)
        let subject = ids[0]
        let theme = try store.createTheme(name: "A", at: at)
        for (offset, id) in ids[20..<35].enumerated() { try store.addArticle(id, toTheme: theme.id, at: at.addingTimeInterval(Double(offset))) }
        _ = try store.createTheme(name: "空", at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: subject)
        let nearestCalls = await fake.nearestCalls
        let call = try #require(nearestCalls.first)
        #expect(call.item.id == subject && call.item.text == "記事 0\n要約 0")
        #expect(call.candidates.count == 1)                                   // the empty theme is not a candidate
        let members = call.candidates[0].members
        #expect(members.count == SuggestionTuning.maximumMembersPerTheme)
        #expect(members.first?.id == ids[34] && members.last?.id == ids[25])    // newest additions first
        #expect(members.first?.text == "記事 34\n要約 34")                       // the theme's recorded snapshot
        #expect(call.background.count == SuggestionTuning.backgroundItems)
        let used = Set([subject] + members.map(\.id))
        #expect(call.background.allSatisfy { !used.contains($0.id) })
        #expect(call.background.first?.id == ids[1])                             // newest articles first
    }

    @Test func expiredContentContributesOnlyItsTitleAndLongTextIsCut() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let expired = store.articles[0], long = store.articles[1]
        expired.contentDeletedAt = at
        long.summary = String(repeating: "あ", count: 1_000)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        _ = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        await suggestions.loadNearest(for: expired.id)
        await suggestions.loadNearest(for: long.id)
        let calls = await fake.nearestCalls
        #expect(calls[0].item.text == "記事 0")
        #expect(calls[1].item.text.count == SuggestionTuning.textCharacterLimit && calls[1].item.text.hasPrefix("記事 1\nあ"))
    }

    @Test func noThemesMeansNoCallAndNoSuggestions() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        _ = try store.createTheme(name: "空", at: at)
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: store.articles[0].id)
        let calls = await fake.nearestCalls
        #expect(calls.isEmpty && suggestions.nearestThemes.isEmpty)
        #expect(suggestions.nearestArticleID == store.articles[0].id)
    }

    @Test func aLateAnswerForAnEarlierArticleIsDiscarded() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 4)
        let theme = try store.createTheme(name: "A", adding: [store.articles[3].id], at: at)
        let (first, second) = (store.articles[0].id, store.articles[1].id)
        let fake = FakeAssistant()
        await fake.script(nearest: [first: [ThemeMatch(themeID: theme.id, score: 0.2)], second: [ThemeMatch(themeID: theme.id, score: 0.9)]], hold: true)
        let suggestions = model(store, fake)
        let early = Task { await suggestions.loadNearest(for: first) }
        try await waitUntil { await fake.parkedCount == 1 }
        let late = Task { await suggestions.loadNearest(for: second) }
        try await waitUntil { await fake.parkedCount == 2 }
        await fake.release(article: second); await late.value
        await fake.release(article: first); await early.value          // arrives last, must not overwrite
        #expect(suggestions.nearestArticleID == second && suggestions.nearestThemes.map(\.score) == [0.9])
    }

    @Test func switchingTheAssistantOffWhileWaitingDiscardsTheAnswer() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let theme = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        let subject = store.articles[0].id
        let fake = FakeAssistant()
        await fake.script(nearest: [subject: [ThemeMatch(themeID: theme.id, score: 0.5)]], hold: true)
        var enabled = true
        let suggestions = ThemeSuggestionModel(store: store, assistant: fake, isEnabled: { enabled }, now: { self.at })
        let task = Task { await suggestions.loadNearest(for: subject) }
        try await waitUntil { await fake.parkedCount == 1 }
        enabled = false
        await fake.release(article: subject); await task.value
        #expect(suggestions.nearestThemes.isEmpty)
    }

    @Test func suggestionsForDeletedThemesAreDroppedAndFailuresAreQuiet() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 3)
        let theme = try store.createTheme(name: "A", adding: [store.articles[2].id], at: at)
        let subject = store.articles[0].id
        let fake = FakeAssistant()
        await fake.script(nearest: [subject: [ThemeMatch(themeID: theme.id, score: 0.5), ThemeMatch(themeID: UUID(), score: 0.4)]])
        let suggestions = model(store, fake)
        await suggestions.loadNearest(for: subject)
        #expect(suggestions.nearestThemes.map(\.themeID) == [theme.id])
        await fake.script(failure: Boom())
        await suggestions.loadNearest(for: subject)
        #expect(suggestions.nearestThemes.isEmpty)
    }

    @Test func clustersNeedThreeUnfiledArticlesAndUseTheNewestOnesUpToTheCap() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 130)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(2) { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        let suggestions = model(store, fake)
        await suggestions.loadClusters()
        let earlyCalls = await fake.clusterCalls
        #expect(earlyCalls.isEmpty && suggestions.clusters == .empty)
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        await fake.script(groups: [[ids[0], ids[1]], [ids[2], ids[3], ids[4]], [ids[5]]])
        await suggestions.loadClusters()
        let clusterCalls = await fake.clusterCalls
        let call = try #require(clusterCalls.first)
        #expect(call.items.count == SuggestionTuning.maximumClusterItems && call.items.first?.id == ids[0])
        #expect(suggestions.clusters.usedCount == 120 && suggestions.clusters.totalCount == 130)
        #expect(suggestions.clusters.groups == [[ids[0], ids[1]], [ids[2], ids[3], ids[4]]])   // a single member is not a cluster
        #expect(!suggestions.isFindingClusters)
    }

    @Test func clusterMembersWhoLeftTheInboxAreRemovedAndAtMostFiveGroupsRemain() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 16)
        let ids = store.articles.map(\.id)
        for id in ids { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        let pairs = stride(from: 0, to: 14, by: 2).map { [ids[$0], ids[$0 + 1]] }      // 7 pairs
        await fake.script(groups: pairs, hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.loadClusters() }
        try await waitUntil { await fake.parkedCount == 1 }
        #expect(suggestions.isFindingClusters)
        _ = try store.createTheme(name: "先に作った", adding: [ids[1]], at: at)        // leaves the inbox while the model works
        await fake.releaseClusters(); await task.value
        #expect(suggestions.clusters.groups.count == 5)
        #expect(!suggestions.clusters.groups.joined().contains(ids[1]) && !suggestions.clusters.groups.contains([ids[0]]))
        #expect(suggestions.clusters.groups.first == [ids[2], ids[3]])                  // the pair broken by the new theme is gone
    }

    @Test func invalidateDiscardsWhatIsStillInFlight() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 5)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(4) { try store.setStar(articleID: id, isStarred: true, at: at) }
        let fake = FakeAssistant()
        await fake.script(groups: [[ids[0], ids[1]]], hold: true)
        let suggestions = model(store, fake)
        let task = Task { await suggestions.loadClusters() }
        try await waitUntil { await fake.parkedCount == 1 }
        suggestions.invalidate()
        #expect(!suggestions.isFindingClusters)
        await fake.releaseClusters(); await task.value
        #expect(suggestions.clusters == .empty)
    }

    @Test func availabilityIsReportedOnlyWhileEnabled() async throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try makeStore(library, articles: 1)
        let fake = FakeAssistant()
        await fake.script(availability: .assetsMissing)
        let suggestions = model(store, fake)
        await suggestions.refreshAvailability()
        #expect(suggestions.availability == .assetsMissing)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeSuggestionModelTests`
Expected: コンパイルエラー（`ThemeAssistant`・`ThemeSuggestionModel`が無い）。

- [ ] **Step 3: 実装**

`Sources/ReaderCore/ThemeAssistant.swift`を新規作成する。

```swift
import Foundation
import Observation

/// A piece of text the assistant may look at: an article's title and, while it is still held, its RSS summary.
public struct SuggestionItem: Sendable, Equatable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) { self.id = id; self.text = text }
}

public struct ThemeCandidateInput: Sendable, Equatable {
    public let themeID: UUID
    public let members: [SuggestionItem]
    public init(themeID: UUID, members: [SuggestionItem]) { self.themeID = themeID; self.members = members }
}

public enum AssistantAvailability: Sendable, Equatable { case available, assetsMissing, unsupported }

/// The on-device assistant behind a protocol so tests never touch a real model. Implementations must not use the
/// network and must not request system assets (decision 0009). They run off the main actor.
public protocol ThemeAssistant: Sendable {
    func availability() async -> AssistantAvailability
    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch]
    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]]
}

/// Asks the assistant for suggestions and hands the screen only answers that are still current: a request ID
/// is checked when the answer arrives, and the enable switch is read again at that moment.
@Observable @MainActor public final class ThemeSuggestionModel {
    public struct Clusters: Equatable, Sendable {
        public var groups: [[UUID]]
        public var usedCount: Int
        public var totalCount: Int
        public static let empty = Clusters(groups: [], usedCount: 0, totalCount: 0)
    }

    public private(set) var nearestArticleID: UUID?
    public private(set) var nearestThemes: [ThemeMatch] = []
    public private(set) var clusters = Clusters.empty
    public private(set) var isFindingClusters = false
    public private(set) var availability: AssistantAvailability?

    private let store: ReaderStore
    private let assistant: (any ThemeAssistant)?
    private let isEnabled: @MainActor () -> Bool
    private let now: () -> Date
    private var nearestToken = UUID()
    private var clusterToken = UUID()

    public init(store: ReaderStore, assistant: (any ThemeAssistant)?, isEnabled: @escaping @MainActor () -> Bool = { true },
                now: @escaping () -> Date = { .now }) {
        self.store = store; self.assistant = assistant; self.isEnabled = isEnabled; self.now = now
    }

    /// Reads the system's state only while the setting is on; "off" is the setting's own answer.
    public func refreshAvailability() async {
        guard isEnabled() else { availability = nil; return }
        guard let assistant else { availability = .unsupported; return }
        let value = await assistant.availability()
        availability = isEnabled() ? value : nil
    }

    public func invalidate() {
        nearestToken = UUID(); nearestThemes = []; nearestArticleID = nil
        invalidateClusters()
    }
    public func invalidateClusters() {
        clusterToken = UUID(); clusters = .empty; isFindingClusters = false
    }

    public func loadNearest(for articleID: UUID) async {
        let token = UUID(); nearestToken = token
        nearestArticleID = articleID; nearestThemes = []
        guard isEnabled(), let assistant, let item = suggestionItem(for: articleID) else { return }
        let candidates = candidateInputs(excluding: articleID)
        guard !candidates.isEmpty else { return }
        let used = Set([articleID] + candidates.flatMap { $0.members.map(\.id) })
        let background = backgroundItems(excluding: used)
        do {
            let matches = try await assistant.nearestThemes(for: item, candidates: candidates, background: background)
            guard token == nearestToken, !Task.isCancelled, isEnabled() else { return }
            nearestThemes = matches.filter { store.theme(id: $0.themeID) != nil }
        } catch { /* No suggestion. The manual picker is unaffected. */ }
    }

    public func loadClusters() async {
        let token = UUID(); clusterToken = token
        guard isEnabled(), let assistant else { clusters = .empty; isFindingClusters = false; return }
        let all = store.unfiledStarredArticleIDs(keeping: nil)
        guard all.count >= SuggestionTuning.minimumItemsToCluster else { clusters = .empty; isFindingClusters = false; return }
        let items = all.prefix(SuggestionTuning.maximumClusterItems).compactMap { self.suggestionItem(for: $0) }
        guard items.count >= SuggestionTuning.minimumItemsToCluster else { clusters = .empty; isFindingClusters = false; return }
        let background = backgroundItems(excluding: Set(items.map(\.id)))
        isFindingClusters = true
        defer { if token == clusterToken { isFindingClusters = false } }
        do {
            let groups = try await assistant.clusters(of: items, background: background)
            guard token == clusterToken, !Task.isCancelled, isEnabled() else { return }
            let stillUnfiled = Set(store.unfiledStarredArticleIDs(keeping: nil))
            let cleaned = groups.map { $0.filter { stillUnfiled.contains($0) } }
                .filter { $0.count >= SuggestionTuning.minimumClusterSize }
            clusters = Clusters(groups: Array(cleaned.prefix(SuggestionTuning.maximumClusters)), usedCount: items.count, totalCount: all.count)
        } catch {
            if token == clusterToken { clusters = .empty }
        }
    }

    // MARK: Inputs. Only held content and the themes' own records are used; expired text never comes back.

    private func suggestionItem(for articleID: UUID) -> SuggestionItem? {
        guard let article = store.article(id: articleID) else { return nil }
        let summary = store.isContentAvailable(article, at: now()) ? article.summary : ""
        return Self.item(id: articleID, title: article.title, summary: summary)
    }
    private func candidateInputs(excluding articleID: UUID) -> [ThemeCandidateInput] {
        store.themes.compactMap { theme in
            let links = store.themeArticles.filter { $0.themeID == theme.id && $0.articleID != articleID }
                .sorted { $0.addedAt != $1.addedAt ? $0.addedAt > $1.addedAt : $0.key < $1.key }
                .prefix(SuggestionTuning.maximumMembersPerTheme)
            let members = links.compactMap { Self.item(id: $0.articleID, title: $0.title, summary: $0.summary) }
            return members.isEmpty ? nil : ThemeCandidateInput(themeID: theme.id, members: members)
        }
    }
    /// The newest articles of the whole library, used only to give the centering step a steadier average.
    private func backgroundItems(excluding used: Set<UUID>) -> [SuggestionItem] {
        store.articles.lazy.filter { !used.contains($0.id) }.compactMap { self.suggestionItem(for: $0.id) }
            .prefix(SuggestionTuning.backgroundItems).map { $0 }
    }
    private static func item(id: UUID, title: String, summary: String) -> SuggestionItem? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = summary.isEmpty ? title : title + "\n" + summary
        guard !text.isEmpty else { return nil }
        return SuggestionItem(id: id, text: String(text.prefix(SuggestionTuning.textCharacterLimit)))
    }
}
```

- [ ] **Step 4: 通ることを確認し、変異確認をする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeSuggestionModelTests`
Expected: 全件PASS。変異確認（変異の前にコミットしておき、戻すのは行の置換で行う）: (a) `guard token == nearestToken`の比較を外すと`aLateAnswerForAnEarlierArticleIsDiscarded`が落ちる、(b) `isEnabled()`の再読み込みを外すと`switchingTheAssistantOffWhileWaiting…`が落ちる、(c) `stillUnfiled`のフィルタを外すとクラスタの試験が落ちる、(d) `invalidateClusters`の`clusterToken = UUID()`を外すと`invalidateDiscards…`が落ちる。

- [ ] **Step 5: コミット**

```bash
git add Sources/ReaderCore/ThemeAssistant.swift Tests/ReaderCoreTests/ThemeSuggestionModelTests.swift
git commit -m "feat: ThemeAssistantと、古い応答を捨てる提案モデルを追加する"
```

---

### Task 4: 実物の`OnDeviceThemeAssistant`（`NLContextualEmbedding`）

**Files:**
- Create: `Sources/RSSReader/OnDeviceThemeAssistant.swift`
- Test: `Tests/ReaderUITests/OnDeviceThemeAssistantTests.swift`

**Interfaces:**
- Consumes: Task 2・3の型
- Produces: `struct EmbeddedVector`、`protocol TextEmbedder: Sendable { availability(); vector(for:) }`、`actor ContextualTextEmbedder: TextEmbedder`、`actor OnDeviceThemeAssistant: ThemeAssistant`（`init(embedder: any TextEmbedder = ContextualTextEmbedder())`）

使うAPIは、使い捨てのスクリプトで、この環境（macOS 27.0.1 / Swift 6.4）でコンパイルでき、日本語の埋め込み（512次元）・英語・ラテン文字の資産が端末にあることを確認済み。資産の取得（`requestAssets`）は呼ばない。

- [ ] **Step 1: 失敗するテストを書く**

```swift
import Foundation
import Testing
import ReaderCore
@testable import RSSReader

/// Keyword-driven stand-in for the real embedding.
private final class KeywordEmbedder: TextEmbedder, @unchecked Sendable {
    private let lock = NSLock()
    private var counted = 0
    var onFirstCall: (@Sendable () -> Void)?
    var calls: Int { lock.withLock { counted } }
    func availability() async -> AssistantAvailability { .available }
    func vector(for text: String) async -> EmbeddedVector? {
        let first = lock.withLock { counted += 1; return counted == 1 }
        if first { onFirstCall?() }
        if text.contains("UNEMBEDDABLE") { return nil }
        if text.contains("finance") { return EmbeddedVector(space: "latin", values: [9, 1, 0]) }
        if text.contains("金利") { return EmbeddedVector(space: "ja", values: [10, 1, 0]) }
        if text.contains("住宅") { return EmbeddedVector(space: "ja", values: [10, 0, 1]) }
        if text.contains("料理") { return EmbeddedVector(space: "ja", values: [0, 10, 1]) }
        if text.contains("レシピ") { return EmbeddedVector(space: "ja", values: [1, 10, 0]) }
        return EmbeddedVector(space: "ja", values: [-4, -4, 4])
    }
}

struct OnDeviceThemeAssistantTests {
    func item(_ text: String) -> SuggestionItem { SuggestionItem(id: UUID(), text: text) }
    let background = (0..<4).map { SuggestionItem(id: UUID(), text: "背景 \($0)") }

    @Test func clustersGroupByTopicAndSkipWhatCannotBeEmbedded() async throws {
        let embedder = KeywordEmbedder()
        let assistant = OnDeviceThemeAssistant(embedder: embedder)
        let items = [item("金利が上がる"), item("住宅ローン"), item("料理の基本"), item("レシピ帳"), item("UNEMBEDDABLE"), item("finance news")]
        let groups = try await assistant.clusters(of: items, background: background)
        let ids = items.map(\.id)
        #expect(groups.contains([ids[0], ids[1]]) && groups.contains([ids[2], ids[3]]))
        #expect(!groups.joined().contains(ids[4]))                              // not embeddable: no suggestion, no crash
        #expect(!groups.contains { $0.contains(ids[5]) && $0.count > 1 })        // another space is never merged into the Japanese groups
        #expect(!groups.joined().contains { $0 == background[0].id })            // background shapes the average only
    }

    @Test func nearestThemesPutsTheThemeWithSimilarMembersFirst() async throws {
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder())
        let subject = item("金利の話")
        let money = ThemeCandidateInput(themeID: UUID(), members: [item("住宅ローン"), item("金利と家計")])
        let food = ThemeCandidateInput(themeID: UUID(), members: [item("料理の基本"), item("レシピ帳")])
        let matches = try await assistant.nearestThemes(for: subject, candidates: [food, money], background: background)
        #expect(matches.map(\.themeID) == [money.themeID])
    }

    @Test func aDifferentSpaceNeverMatches() async throws {
        let assistant = OnDeviceThemeAssistant(embedder: KeywordEmbedder())
        let subject = item("finance news")
        let candidate = ThemeCandidateInput(themeID: UUID(), members: [item("金利と家計"), item("住宅ローン")])
        let matches = try await assistant.nearestThemes(for: subject, candidates: [candidate], background: background)
        #expect(matches.isEmpty)
    }

    @Test func cancellationStopsTheEmbeddingLoop() async throws {
        let embedder = KeywordEmbedder()
        let assistant = OnDeviceThemeAssistant(embedder: embedder)
        let items = (0..<20).map { item("金利 \($0)") }
        final class Holder: @unchecked Sendable { var task: Task<[[UUID]], any Error>? }
        let holder = Holder()
        embedder.onFirstCall = { holder.task?.cancel() }
        holder.task = Task { try await assistant.clusters(of: items, background: []) }
        await #expect(throws: CancellationError.self) { try await holder.task!.value }
        #expect(embedder.calls < items.count)
    }

    @Test func availabilityPassesThrough() async {
        let state = await OnDeviceThemeAssistant(embedder: KeywordEmbedder()).availability()
        #expect(state == .available)
    }

    /// Decision 0009: the app never starts a system-asset download by itself. Guard the sources against the call.
    @Test func sourcesNeverRequestSystemAssets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let enumerator = try #require(FileManager.default.enumerator(at: root.appending(path: "Sources"), includingPropertiesForKeys: nil))
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            #expect(!(try String(contentsOf: url, encoding: .utf8)).contains("requestAssets"), "\(url.lastPathComponent) requests assets")
        }
        #expect(scanned > 10)
    }

    /// Opt-in: runs the real on-device embedding on synthetic Japanese sentences and prints what it finds, for the
    /// verification record. Quality is judged by a person, not asserted. FEEEDER_RUN_ONDEVICE_AI=1 to run.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FEEEDER_RUN_ONDEVICE_AI"] == "1"))
    func realEmbeddingSmoke() async throws {
        let assistant = OnDeviceThemeAssistant()
        let state = await assistant.availability()
        #expect(state == .available)
        let topics = [
            ["日銀が政策金利を引き上げ、住宅ローン金利も上昇する見通し", "変動金利型の住宅ローンを組む家計の返済負担が増える", "預金金利の上昇で家計の貯蓄行動はどう変わるか", "インフレと賃金上昇の関係を家計の視点で読む"],
            ["小型のAIモデルを端末内で動かすための量子化の基本", "オンデバイスAIのレイテンシとプライバシーの両立", "ローカルで動く大規模言語モデルの推論最適化", "AIモデルの蒸留で軽量化する手法のまとめ"],
            ["睡眠の質を上げるための就寝前の習慣", "朝の光を浴びると体内時計が整う", "昼寝の長さと夜の眠りの関係", "カフェインを摂る時間帯が睡眠に与える影響"]
        ]
        let items = topics.flatMap { $0 }.map { item($0) }
        let bg = ["新しいカメラの発表会", "週末の天気と花粉の予報", "地方の鉄道路線の見直し", "映画賞のノミネート発表"].map { item($0) }
        let groups = try await assistant.clusters(of: items, background: bg)
        let titles = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.text) })
        for group in groups { print("CLUSTER", group.map { titles[$0] ?? "?" }) }
        #expect(!groups.isEmpty)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter OnDeviceThemeAssistantTests`
Expected: コンパイルエラー（`TextEmbedder`・`OnDeviceThemeAssistant`が無い）。

- [ ] **Step 3: 実装**

`Sources/RSSReader/OnDeviceThemeAssistant.swift`を新規作成する。

```swift
import Foundation
import NaturalLanguage
import ReaderCore

struct EmbeddedVector: Sendable, Equatable {
    let space: String
    let values: [Float]
}

protocol TextEmbedder: Sendable {
    func availability() async -> AssistantAvailability
    func vector(for text: String) async -> EmbeddedVector?
}

/// `NLContextualEmbedding`: Japanese text uses the Japanese model, other Latin-script languages the Latin-script
/// model, and anything else gets no vector. Only assets already on the device are used; the app never asks the
/// system to download any (decision 0009). An article's vector is the mean of its token vectors.
actor ContextualTextEmbedder: TextEmbedder {
    private enum Space: String { case japanese = "ja", latin = "latin" }
    private var models: [Space: NLContextualEmbedding] = [:]
    private var loaded: Set<Space> = []
    private var cache: [String: EmbeddedVector] = [:]
    private let cacheLimit = 600

    private func model(for space: Space) -> NLContextualEmbedding? {
        if let model = models[space] { return model }
        let model = switch space {
        case .japanese: NLContextualEmbedding(language: .japanese)
        case .latin: NLContextualEmbedding(script: .latin)
        }
        models[space] = model
        return model
    }

    func availability() async -> AssistantAvailability {
        let available = [Space.japanese, .latin].compactMap { model(for: $0) }
        if available.isEmpty { return .unsupported }
        return available.contains { $0.hasAvailableAssets } ? .available : .assetsMissing
    }

    func vector(for text: String) async -> EmbeddedVector? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let hit = cache[text] { return hit }
        guard let (space, language) = Self.route(text), let model = readyModel(for: space),
              let result = try? model.embeddingResult(for: text, language: language) else { return nil }
        var sum = [Double](repeating: 0, count: model.dimension), count = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            for index in 0..<min(vector.count, sum.count) { sum[index] += vector[index] }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        let vector = EmbeddedVector(space: space.rawValue, values: sum.map { Float($0 / Double(count)) })
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[text] = vector
        return vector
    }

    /// The model only when its assets are already on the device; `load()` runs once.
    private func readyModel(for space: Space) -> NLContextualEmbedding? {
        guard let model = model(for: space), model.hasAvailableAssets else { return nil }
        if !loaded.contains(space) {
            guard (try? model.load()) != nil else { return nil }
            loaded.insert(space)
        }
        return model
    }

    private static func route(_ text: String) -> (Space, NLLanguage)? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        if language == .japanese { return (.japanese, language) }
        if let latin = NLContextualEmbedding(script: .latin), latin.languages.contains(language) { return (.latin, language) }
        return nil
    }
}

actor OnDeviceThemeAssistant: ThemeAssistant {
    private let embedder: any TextEmbedder
    init(embedder: any TextEmbedder = ContextualTextEmbedder()) { self.embedder = embedder }

    func availability() async -> AssistantAvailability { await embedder.availability() }

    func nearestThemes(for item: SuggestionItem, candidates: [ThemeCandidateInput], background: [SuggestionItem]) async throws -> [ThemeMatch] {
        let pool = try await embed([item] + candidates.flatMap(\.members) + background)
        return ThemeRanking.nearest(articleID: item.id, pool: pool, candidates: candidates.map { ($0.themeID, $0.members.map(\.id)) })
    }

    func clusters(of items: [SuggestionItem], background: [SuggestionItem]) async throws -> [[UUID]] {
        let embedded = try await embed(items + background)
        let wanted = Set(items.map(\.id))
        let centered = EmbeddingMath.centered(embedded).filter { wanted.contains($0.id) }
        return ThemeClustering.clusters(of: centered, threshold: SuggestionTuning.clusterThreshold)
    }

    private func embed(_ items: [SuggestionItem]) async throws -> [EmbeddedItem] {
        var seen = Set<UUID>(), result: [EmbeddedItem] = []
        for item in items where seen.insert(item.id).inserted {
            try Task.checkCancellation()
            if let vector = await embedder.vector(for: item.text) {
                result.append(EmbeddedItem(id: item.id, space: vector.space, vector: vector.values))
            }
        }
        return result
    }
}
```

`NLContextualEmbedding.languages`が`[NLLanguage]`でない等でコンパイルが通らなければ、`Set(latin.languages)`などAPIの実際の型に合わせる（スクリプトでは`hasAvailableAssets`・`dimension`・`load()`・`embeddingResult(for:language:)`・`enumerateTokenVectors`までを確認済みで、`languages`は未確認）。

- [ ] **Step 4: 通ることを確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter OnDeviceThemeAssistantTests`
Expected: 全件PASS（`realEmbeddingSmoke`は環境変数が無いのでスキップ）。続けて任意スモークを一度実行し、出力を検証記録用に控える。

Run: `FEEEDER_RUN_ONDEVICE_AI=1 swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter realEmbeddingSmoke 2>&1 | grep -E "CLUSTER|✔|✘"`
Expected: PASS。`CLUSTER`の行で、金利・AI・睡眠の3分野がどう束なったかを目で確認し、結果（PASS/不一致の内容・環境）を記録に残す。分野が混ざる・束ならない場合も、閾値の調整を急がず、そのまま記録する（この環境の合成文での観察であり、実データの精度ではない）。変異確認として、`embed`の`Task.checkCancellation()`を外すと`cancellationStopsTheEmbeddingLoop`が落ちることを確認してから戻す。

- [ ] **Step 5: コミット**

```bash
git add Sources/RSSReader/OnDeviceThemeAssistant.swift Tests/ReaderUITests/OnDeviceThemeAssistantTests.swift
git commit -m "feat: NLContextualEmbeddingによる端末内の提案（資産は自動取得しない）を追加する"
```

---

### Task 5: 画面（`t`の近いテーマ、未整理のStarの提案帯、Settings、配線）

**Files:**
- Modify: `Sources/ReaderCore/ThemePicker.swift`、`Tests/ReaderCoreTests/ThemePickerTests.swift`
- Modify: `Sources/RSSReader/ThemePickerView.swift`
- Create: `Sources/RSSReader/ClusterSuggestionsView.swift`
- Modify: `Sources/RSSReader/ReaderSettingsView.swift`、`Sources/RSSReader/ReaderView.swift`、`Sources/RSSReader/RSSReaderApp.swift`

**Interfaces:**
- Consumes: Task 1〜4
- Produces: `ThemePicker.rows(themes:memberOf:query:suggested:)`（`suggested: [UUID] = []`）、`ThemePickerRow.suggested`、`enum OnDeviceAISetting { static let key; static var isEnabled: Bool }`、`ReaderView(…, suggestions: ThemeSuggestionModel? = nil)`、`ReaderSettingsView(…, suggestions: ThemeSuggestionModel? = nil)`

- [ ] **Step 1: 並び替えの失敗するテストを書く（純粋ロジック）**

`ThemePickerTests`に追加する。

```swift
    @Test func suggestedThemesComeFirstOnlyWhileTheQueryIsEmptyAndAreFlagged() {
        let rows = ThemePicker.rows(themes: themes, memberOf: [], query: "", suggested: [llm])
        #expect(rows.map(\.kind) == [.theme(llm), .theme(finance)])
        #expect(rows.map(\.suggested) == [true, false])
        let typed = ThemePicker.rows(themes: themes, memberOf: [], query: "金", suggested: [llm])
        #expect(typed.map(\.kind) == [.theme(finance), .create("金")] && typed.allSatisfy { !$0.suggested })
        let all = ThemePicker.rows(themes: themes, memberOf: [], query: " ", suggested: [llm, finance])
        #expect(all.map(\.kind) == [.theme(llm), .theme(finance)])      // the suggestion's own order is kept
    }

    @Test func unknownOrRepeatedSuggestionsAreIgnoredAndNoSuggestionChangesNothing() {
        let rows = ThemePicker.rows(themes: themes, memberOf: [llm], query: "", suggested: [UUID(), finance, finance])
        #expect(rows.map(\.kind) == [.theme(finance), .theme(llm)] && rows.map(\.suggested) == [true, false])
        #expect(ThemePicker.rows(themes: themes, memberOf: [llm], query: "") == ThemePicker.rows(themes: themes, memberOf: [llm], query: "", suggested: []))
        #expect(ThemePicker.defaultHighlight(rows: rows, query: "") == 0)
    }
```

（`ThemePickerRow`は`Equatable`なので、`suggested`を含めた比較になる。上の2行目の期待は、`suggested`未指定と`[]`が同じ結果になることの確認。）

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemePickerTests` → コンパイルエラーを確認。

- [ ] **Step 2: 実装（`ThemePicker.swift`）**

`ThemePickerRow`に`suggested`を足し（既存の呼び出しは壊さない）、`rows`に`suggested`を足す。

```swift
public struct ThemePickerRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case theme(UUID), create(String) }
    public let kind: Kind
    public let title: String
    public let included: Bool
    /// A "near" theme proposed by the on-device assistant. Only a hint: it never acts by itself.
    public let suggested: Bool
    public init(kind: Kind, title: String, included: Bool, suggested: Bool = false) {
        self.kind = kind; self.title = title; self.included = included; self.suggested = suggested
    }
}
```

```swift
    public static func rows(themes: [(id: UUID, name: String)], memberOf: Set<UUID>, query: String, suggested: [UUID] = []) -> [ThemePickerRow] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var order = themes
        let known = Set(themes.map(\.id))
        var seen = Set<UUID>()
        let hints = suggested.filter { known.contains($0) && seen.insert($0).inserted }
        if query.isEmpty, !hints.isEmpty {
            let byID = Dictionary(themes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            order = hints.compactMap { byID[$0] } + themes.filter { !seen.contains($0.id) }
        }
        let matching = query.isEmpty ? order : order.filter { $0.name.localizedCaseInsensitiveContains(query) }
        var rows = matching.map {
            ThemePickerRow(kind: .theme($0.id), title: $0.name, included: memberOf.contains($0.id),
                           suggested: query.isEmpty && seen.contains($0.id))
        }
        if !query.isEmpty, !themes.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
            rows.append(ThemePickerRow(kind: .create(query), title: "「\(query)」を新しいテーマとして作る", included: false))
        }
        return rows
    }
```

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemePickerTests` → PASS。

- [ ] **Step 3: `ThemePickerView`に取り込む**

追加する状態と変更点（`@FocusState`の下に状態を足し、`rows`、`.onAppear`の隣、キー処理、`run`、`rowView`を直す）。

```swift
    var suggestions: ThemeSuggestionModel? = nil
    @State private var suggestedIDs: [UUID] = []
    /// Once the person types, moves the highlight or acts, late suggestions no longer reorder the rows under them.
    @State private var interacted = false
```

```swift
    private var rows: [ThemePickerRow] {
        ThemePicker.rows(themes: store.themes.map { ($0.id, $0.name) }, memberOf: memberOf, query: query, suggested: suggestedIDs)
    }
```

`body`の最後の修飾子の並びに追加する（`.onChange(of: query)`の直後）。

```swift
        .onChange(of: query) { _, _ in interacted = true }
        .task(id: articleID) {
            guard let suggestions else { return }
            await suggestions.loadNearest(for: articleID)
            guard !Task.isCancelled, !interacted, suggestions.nearestArticleID == articleID else { return }
            suggestedIDs = suggestions.nearestThemes.map(\.themeID)
            highlighted = ThemePicker.defaultHighlight(rows: rows, query: query)
        }
```

↑↓と`run`で`interacted = true`を立てる。

```swift
                .onKeyPress(.upArrow) { interacted = true; highlighted = ThemePicker.move(highlighted, by: -1, count: rows.count); return .handled }
                .onKeyPress(.downArrow) { interacted = true; highlighted = ThemePicker.move(highlighted, by: 1, count: rows.count); return .handled }
```

`run(_:)`の先頭に`interacted = true`を足す。`rowView`の`HStack`の`Spacer()`の前に印を足し、読み上げも直す。

```swift
                Text(row.title).lineLimit(1)
                if row.suggested {
                    Text("近い").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Color.orange.opacity(0.15), in: Capsule())
                }
                Spacer()
```

```swift
        .accessibilityValue((row.included ? "入っています" : "入っていません") + (row.suggested ? "、近いテーマ" : ""))
```

- [ ] **Step 4: 「未整理のStar」の提案帯とポップオーバー**

`Sources/RSSReader/ClusterSuggestionsView.swift`を新規作成する。

```swift
import SwiftUI
import ReaderCore

/// The strip above "未整理のStar": how many groups the assistant found. Nothing happens until the person opens it.
struct ClusterSuggestionBar: View {
    @Bindable var store: ReaderStore
    @Bindable var model: ThemeSuggestionModel
    let onCreated: (String) -> Void
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(.orange)
                Text("まとまりの提案 \(model.clusters.groups.count)件")
                Spacer()
                if model.isFindingClusters { ProgressView().controlSize(.small) }
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle()).padding(.horizontal, 12).padding(.vertical, 8).background(.bar)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            ClusterSuggestionsView(store: store, model: model, onCreated: { message in presented = false; onCreated(message) })
        }
        .accessibilityLabel("まとまりの提案 \(model.clusters.groups.count)件")
    }
}

struct ClusterSuggestionsView: View {
    @Bindable var store: ReaderStore
    @Bindable var model: ThemeSuggestionModel
    let onCreated: (String) -> Void
    @State private var naming: Int?
    @State private var name = ""
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("まとまりの提案").font(.headline)
            Text("端末内で、近い内容の記事をまとめました。使うかどうかは自分で決めます。").font(.caption).foregroundStyle(.secondary)
            if model.clusters.usedCount < model.clusters.totalCount {
                Text("新しい\(model.clusters.usedCount)件から提案しています（未整理は\(model.clusters.totalCount)件）。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(model.clusters.groups.enumerated()), id: \.offset) { index, group in card(index, group) }
                }
            }.frame(maxHeight: 360)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(14).frame(width: 340)
    }

    private func card(_ index: Int, _ group: [UUID]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(group.prefix(4), id: \.self) { id in
                Text(store.article(id: id)?.title ?? "（記事が見つかりません）").lineLimit(1).font(.callout)
            }
            if group.count > 4 { Text("ほか\(group.count - 4)件").font(.caption).foregroundStyle(.secondary) }
            if naming == index {
                HStack {
                    TextField("テーマの名前", text: $name).focused($nameFocused)
                        .onSubmit { create(group) }.accessibilityLabel("テーマの名前")
                    Button("作成") { create(group) }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("やめる") { naming = nil; name = "" }
                }
            } else {
                Button("\(group.count)件でテーマにする…") { naming = index; name = ""; nameFocused = true }
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func create(_ group: [UUID]) {
        do {
            let theme = try store.createTheme(name: name, adding: group, at: .now)
            error = nil; naming = nil; name = ""
            onCreated("「\(theme.name)」に\(group.count)件を入れました")
            Task { await model.loadClusters() }
        } catch { self.error = error.localizedDescription }
    }
}
```

- [ ] **Step 5: Settingsの「端末内AI」タブと有効／無効の共有**

`ReaderSettingsView.swift`の末尾（`}`の外）に追加し、`TabView`へタブを足す。

```swift
/// One place for the switch's key and default, shared by Settings, the reader and the model.
enum OnDeviceAISetting {
    static let key = "onDeviceAIEnabled"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
}

struct OnDeviceAISettingsView: View {
    @Bindable var suggestions: ThemeSuggestionModel
    @AppStorage(OnDeviceAISetting.key) private var enabled = true

    var body: some View {
        Form {
            Toggle("端末内AIの提案を使う", isOn: $enabled)
            Text("近いテーマ（tキー）とまとまりの提案（未整理のStar）を、この Mac の中だけで計算します。外部へ送らず、アカウントも要りません。答えやいまの理解には何も書き込みません。")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("状態") { Text(statusText) }
            Text("言語の資産が端末に無い場合、アプリは自動で取得しません。提案が出ないだけで、ほかの操作は変わりません。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped).padding()
        .task(id: enabled) { await suggestions.refreshAvailability() }
    }
    private var statusText: String {
        guard enabled else { return "オフ" }
        switch suggestions.availability {
        case nil: "確認中…"
        case .available: "使えます"
        case .assetsMissing: "端末に言語の資産がありません"
        case .unsupported: "この環境では使えません"
        }
    }
}
```

```swift
    var suggestions: ThemeSuggestionModel? = nil     // ReaderSettingsViewのプロパティに追加
```

```swift
            if let suggestions {
                OnDeviceAISettingsView(suggestions: suggestions)
                    .tabItem { Label("端末内AI", systemImage: "sparkles") }
            }
```

（`frame(width: 520, height: 340)`は、説明文が収まらなければ高さを広げる。実機の見た目で確認する。）

- [ ] **Step 6: 配線（`RSSReaderApp`と`ReaderView`）**

`RSSReaderApp`: `@State private var suggestions: ThemeSuggestionModel?`を足し、`init`でストアの作成後に作る。

```swift
            _suggestions = State(initialValue: ThemeSuggestionModel(store: store, assistant: OnDeviceThemeAssistant(),
                                                                    isEnabled: { OnDeviceAISetting.isEnabled }))
```

`ReaderView(...)`の呼び出しと`ReaderSettingsView(store:, appearance:)`の呼び出しに`suggestions: suggestions`を渡す。

`ReaderView`: プロパティ`let suggestions: ThemeSuggestionModel?`と`@AppStorage(OnDeviceAISetting.key) private var aiEnabled = true`を足し、`init`に`suggestions: ThemeSuggestionModel? = nil`を足して代入する（既存の呼び出し・試験は壊れない）。`ThemePickerView(store:articleID:onMessage:)`の呼び出しに`suggestions: suggestions`を足す。

一覧の上部の`safeAreaInset(edge: .top)`を、次の形に直す。

```swift
        .safeAreaInset(edge: .top) {
            if case .theme(let id) = scope { ThemeFacePicker(face: faceBinding(id)) }
            else if scope == .unfiledStars, aiEnabled, let suggestions, !suggestions.clusters.groups.isEmpty {
                ClusterSuggestionBar(store: store, model: suggestions, onCreated: { themeMessage = $0 })
            }
        }
```

自動計算のトリガーを、`ReaderView`の`.task(id: selection)`の隣に足す。

```swift
        .task(id: ClusterTrigger(active: scope == .unfiledStars && aiEnabled, count: store.unfiledStarCount)) {
            guard let suggestions else { return }
            guard scope == .unfiledStars, aiEnabled else { suggestions.invalidateClusters(); return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await suggestions.loadClusters()
        }
        .onChange(of: aiEnabled) { _, on in if !on { suggestions?.invalidate() } }
```

```swift
private struct ClusterTrigger: Hashable { let active: Bool; let count: Int }
```

`scope`が`LibraryScope?`なので、比較は`scope == .unfiledStars`（`LibraryScope`は`Equatable`）。型が合わなければ`scope ?? .all`に直す。

- [ ] **Step 7: 通ることを確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build` → 全件PASS（既存の`ThemeReaderTests`は`suggestions`を渡さないので影響を受けない）。`bash scripts/build-app.sh release`と`git diff --check`も通す。`Binding`のsetterにメソッド参照を渡していないことを`grep -rn "set: [a-zA-Z]*)" Sources/RSSReader | grep -v "set: {"`で確認する。

- [ ] **Step 8: コミット**

```bash
git add Sources/ReaderCore/ThemePicker.swift Tests/ReaderCoreTests/ThemePickerTests.swift Sources/RSSReader
git commit -m "feat: tキーに近いテーマ、未整理のStarにまとまりの提案、Settingsに端末内AIのスイッチを追加する"
```

---

### Task 6: 文書・実機確認・独立レビュー・PR

**Files:**
- Modify: `docs/specification.md`（冒頭の「実装済み／未実装」、§5.1、PRD-06・13の合否欄があれば）、`README.md`、`docs/architecture.md`（§3.1の実装値）
- Create: `docs/decisions/0010-on-device-suggestion-defaults.md`、`docs/verification/2026-10-10-theme-ai-suggestions.md`

- [ ] **Step 1: 決定記録0010を書く**

形式は[0009](../../decisions/0009-on-device-ai-principles.md)に合わせる（状態: 有効（PR #nのマージでPdM承認）、日付、決定者、背景、決定、影響、未確認）。決定は「判断してほしい点」の7つ（近いテーマを先頭に並べる／まとまりは自動計算／中心化の背景40件／数値と上限／言語ごとの空間／既定は有効でSettingsに切り口／名前はこのPRでは提案しない）。未確認は、実データでの精度・閾値・速度、資産が無い環境の実機、IME・VoiceOver。`docs/decisions/README.md`の一覧にも足す。

- [ ] **Step 2: 仕様・README・Architectureを実装に合わせる**

- `specification.md`冒頭: 「実装済み」に「端末内AI（近いテーマ・まとまりの提案。Settingsで無効にできる）」を足し、「未実装」を「端末内AI（テーマ名の案・レンズの具体化）、テーマからのClaude連携」に直す。§5.1の3つの提案のうち、近いテーマ・まとまりに「実装済み」の注記を付ける。
- `README.md`: 冒頭の「端末内AI…は順次実装します」を直し、機能の節に、`t`で近いテーマが先頭に出ること、「未整理のStar」にまとまりの提案が出て、そこからテーマを作れること、Settingsで無効にできること、資産が無いときはアプリが取得しないことを書く。
- `architecture.md` §3.1: 背景40件での中心化、言語ごとの空間、上限と数値、`ThemeSuggestionModel`の要求ID検査を書き足す。

- [ ] **Step 3: 合成インスタンスでの実操作**

AGENTS.mdの手順に従う。本人の実Feeederに触れない（`/Applications/Feeeder.app`は操作・撮影しない）。リリースビルドを`/private/tmp`へコピーし、別Bundle IDにして署名し直し、`open -n`で`--data-directory /private/tmp/<一時> --seed-demo`を付けて起動する。`pgrep -fl RSSReader`で、引数に一時のデータディレクトリを含むプロセスだけを対象にし、computer-useの許可はその別Bundle IDにだけ求める。確認する項目と、背景入力の限界（キー入力・右クリック・ポップオーバー内の入力は届かない）:

1. Settingsの「端末内AI」タブ: 状態の表示（使えます）、トグルを切ると「オフ」。
2. 合成データのStarを数件付けて「未整理のStar」を開く: 提案帯が出る／出ない、ポップオーバーの内容、「テーマにする」で名前を入れて作成（入力が届かなければ未検証にする）。
3. テーマに記事を入れ、別の記事で`t`: 近いテーマに「近い」の印が出るか（デモの記事は少なく内容も一般的なので、質は判断しない。仕組みの確認）。
4. トグルを切った状態で、提案帯が消え、`t`が従来どおりであること。

終わったら、確認済みの一時プロセスだけを終了し、一時ディレクトリを削除し、`app_release`する。

- [ ] **Step 4: 検証記録を書く**

`docs/verification/2026-10-10-theme-ai-suggestions.md`に、環境（Mac14,2 / macOS 27.0.1 / Swift 6.4）、自動検証（全テスト・Releaseビルド・署名・`git diff --check`・`requestAssets`不使用の検査）、Task 4の任意スモークの出力（`CLUSTER`の行。合成の日本語文での観察で、実データの精度ではないと明記）、実操作の結果、独立レビューの結果と対応、**未検証**を書く。未検証に含める: 実際のStarでのまとまり・近いテーマの精度と閾値、数百件での速度とメモリ、英語・混在記事の質、資産が無い環境・Apple Intelligenceが無効な環境の実機、IME・VoiceOver・複数ウィンドウ、背景入力で届かなかった操作、macOS 26のCI（このPRのCIで確認する）。

- [ ] **Step 5: 最終確認と独立レビュー**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`、`bash scripts/build-app.sh release`、`codesign --verify --deep --strict .build/Feeeder.app`、`git diff --check`。

並行処理（要求ID・キャンセル・MainActor）を含み、保存の新しい経路もあるので、固定commitを`opus`の独立レビューに出す（読み取り専用、`docs/review-checklist.md`を使う）。レビューの焦点: 要求IDの検査・`defer`での`isFindingClusters`の戻し・キャンセル時の状態、無効のときに本当に呼ばないか、`ThemePickerView`のハイライトが動かないか、`createTheme(adding:[UUID])`の失敗注入、試験が実際に判別できるか（変異で落ちるか）、文書と挙動の一致。Critical・Importantは、失敗するテストを先に書いて直す。

- [ ] **Step 6: push・PR**

ブランチ`claude/theme-ai-suggestions`をpushし、確認を待たずにPRを作る（本人の標準指示）。PR本文に、含まないもの（テーマ名の案・レンズの具体化・Claude連携の付け替え・改名）、検証、未検証、判断してほしい点の7つへの参照を書く。CIが落ちたら、まずSwift 6.3.3のコンパイラクラッシュ（メソッド参照のsetterなど）を疑う。mergeはしない。

---

## 自己レビュー

**仕様の網羅**（§5.1の3提案のうち、このPR分）: 近いテーマ→Task 2・3・4・5。まとまり→Task 2・3・4・5、テーマへの変換→Task 1・5。設定での無効化と、無効時に呼ばないこと→Task 3・5。資産が無い・失敗・取消→Task 3・4。入力量の上限と使った件数の表示→Task 3・5。期限切れ全文を使わない→Task 3。資産を自動取得しない→Task 4（検査の試験）。名前・レンズの具体化はPR 7、Claude連携はPR 8（対象外）。

**型の整合**: `ThemeMatch`・`SuggestionTuning`・`EmbeddedItem`はTask 2で定義し、Task 3・4が使う。`SuggestionItem`・`ThemeCandidateInput`・`AssistantAvailability`・`ThemeAssistant`はTask 3で定義し、Task 4・5が使う。`EmbeddedVector`・`TextEmbedder`はTask 4。`ThemePickerRow.suggested`・`rows(…suggested:)`はTask 5で定義し、同じTaskの`ThemePickerView`が使う。`createTheme(name:adding:[UUID]at:)`はTask 1で定義し、Task 5の`ClusterSuggestionsView`が使う。

**プレースホルダー走査**: 「TBD」「あとで」の類は無い。Task 1・4・5で「型が合わなければ直す」と書いた箇所は、確認済みの範囲と未確認の範囲（`NLContextualEmbedding.languages`、`LibraryScope`の比較）を明記してある。試験コードは、`#expect`の中で`await`と`&&`を混ぜない書き方に直してある。

**コードの事前確認**（Swift 6.4、macOS 27.0.1）: Task 2（9件）・Task 3（11件）・Task 4（偽の埋め込みの5件）のコードと試験、Task 5の並び替えの2件は、計画の記述をそのまま一時的にリポジトリへ置き、すべて通ることを確認してから取り除いた（コンパイルエラー1件、`self`の明示を計画へ反映済み）。Task 1の試験と、Task 5・6の画面（`ThemePickerView`・`ClusterSuggestionsView`・Settings・`ReaderView`の配線）は、まだコンパイルしていない。実装時にコンパイルエラーが出たら、期待値ではなく型・APIを直す。

**実物の埋め込みの先行観察**（任意スモークをそのまま一度実行。合成の日本語12文＋背景4文）: 金利4文・睡眠4文は4文ずつ1塊に、AI4文は3文＋単独1に分かれ、分野の混在は無かった。合成の分かりやすい文での観察で、実データの精度の証拠ではない。

