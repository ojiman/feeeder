# Theme Screens Implementation Plan (PR 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する（[決定0002](../../decisions/0002-single-supervised-writer.md)）。

**Goal:** 日次・週ノート・スクラップ（`n`）を、サイドバーのテーマ区画・`t`キーのテーマ選択・テーマの[記事｜問い]画面に置き換える。この段階の「問い」面は「いまの理解」の編集だけで、問いの行はPR 5で足す。

**Architecture:** 保存層（PR 3）はそのまま使う。ワークスペース状態にテーマの対象と面を足し、`ReaderView`にテーマの区画・画面・選択ポップオーバーを足す。**コンパイルを常に通すため、追加を先に行い、旧ノートの削除は最後のTaskで1回にまとめる。** AI入力の`scrap`/`noteSource`は`themeArticle`に置き換えるが、Claude連携の入口はPR 8まで無い。

**Tech Stack:** Swift 6、SwiftUI、AppKit、SwiftData、WebKit、Swift Testing。外部依存の追加なし。

**Spec:** [PRD](../../specification.md)第3.1〜3.3節・第5.2節・第7節（PRD-01・04・09・10）、[Architecture](../../architecture.md)第2.1節・第6.1節、[決定0008](../../decisions/0008-theme-centered-notes.md)。ロードマップ: [テーマ中心のノート実装計画](2026-10-10-theme-notes.md)のPR 4。前提: PR 3（[#23](https://github.com/ojiman/feeeder/pull/23)、`main` `215b901`）。本計画はこのPRのマージで承認される。

## この計画で決めること（マージで承認される判断）

1. **問い面の範囲**: PR 4の「問い」面は、先頭の「いまの理解」の行と、その編集面だけ。問いの行・レンズ・答え・根拠はPR 5。ロードマップ（PR 4が「理解の編集」を含み、PR 5が問い一覧を含む）の食い違いを、この形で解消する。
2. **一覧のマーカー**: 現在「今日スクラップした記事」を示す`▣`を、「いずれかのテーマに入っている記事」の印に置き換える（仕様に明記は無いが、Star一覧で整理済みかを見分けるため）。
3. **`AIInputSelection`**: `.scrap`/`.noteSource`を`.themeArticle(String)`（`ThemeArticle.key`）に置き換える。`AIReviewView`は残すが、入口はPR 8まで無い（どこからも開けない）。
4. **原子的な作成**: `createTheme(name:adding:at:)`で、テーマの作成と最初の記事の追加を1回の保存で行う。
5. **一覧の保持**: テーマの記事一覧は`themeArticleIDs(themeID:keeping:)`で、テーマから外した直後の選択中の記事を次の移動まで残す（Starの付け外しと同じ扱い）。
6. **`DemoLibrary`のデータは変えない**（既存テストが「Starなし」を前提にしている）。文言だけ直す。
7. **面の記憶はセッション内のみ**（起動をまたいで保存しない）。
8. **検証用フィクスチャの基準commit**に、配布済みbeta.3（`1007dce5…`）と現行main（`215b901f…`）を追加する。

## Global Constraints

- サポート下限はmacOS 27.0、ビルド下限（`Package.swift`・CI）はmacOS 26.6のまま。macOS 27 SDK専用のAPIを使わない（[決定0007](../../decisions/0007-support-floor-macos-27.md)）。
- 外部依存・Backend・アカウント・同期・AI通信を追加しない。単独writerで進める。
- Starとテーマは独立する。`t`は既読日時・Starを変えない。Star・テーマへの追加は現在の記事・読書位置を保ち、結果を示す。
- テキスト入力・IME変換・修飾キー付き操作では、文字入力と標準操作を優先する（`t`もこの規則に従う）。原文中も`j/k/s/t`を使える。
- 新しい変更経路は先頭で`reloadIfNeeded()`を呼び、保存／再読み込みの失敗注入試験（`failedRecoveryBlocksChangesUntilReloadSucceeds`と、ThemeTestsの失敗注入）に追加する。UIはモデルの参照ではなくIDを持つ。
- 旧ストアが新スキーマで開けない場合は、**実DBを自動削除・再作成せず、止まって本人に相談する**（[決定0003](../../decisions/0003-beta-data-compatibility.md)）。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・Keychain・ブラウザprofileを使わない。
- 1PR1テーマ。失敗するテストを先に書き、失敗を確認してから実装する。**破壊試験（実装を壊して試験が落ちるか確認する）の前に必ずコミットし、元に戻すときは該当の変更だけを戻す（ファイル全体の`git checkout`は使わない）。**
- コミット／PRの末尾にはセッションが指定する共著表記を付ける。GitHubへのpush・PR作成は本人の許可を得る。署名・配布・新Tag／Release、`main`への直接pushをしない。

## Review Focus

1. 現行ベータのストアを、旧モデル5つを外した新スキーマで開く（購読・記事・既読・Starが残る。旧ノートは消える）。開けない場合は自動削除せず止まる → Task 1・Task 8。
2. `t`キーの安全性: 入力欄・IME変換中・修飾キー・シート／ポップオーバー表示中・記事未選択のときに、テーマ選択が開かない／文字入力を奪わない → Task 5。
3. 選択と位置の保持: テーマの[記事｜問い]を切り替えても、記事の選択・読書位置が戻る。選択中の記事をテーマから外しても次の移動まで残る → Task 2・4・5。
4. 削除・名前変更: 表示中のテーマを削除したら「すべての記事」へ戻る。名前変更で選択を失わない。削除の確認は記事とStarが消えないことを示す → Task 4。
5. 空の状態: テーマが0件、テーマに記事が0件、未整理のStarが0件、記事未選択で`t`を押す、のそれぞれで壊れず案内が出る → Task 4・5。

---

### Task 1: SwiftDataが「モデルを外したストア」を開けるかの先行調査（使い捨て）

**目的**: 最大の不確実性を、アプリのコードに触れる前に確かめる。結果は製品コードに残さず、報告だけを残す。

**Files:**
- Create（スクラッチ領域、コミットしない）: `$SCRATCH/dropspike/old.swift`、`new.swift`

**Interfaces:** なし（調査）。

- [ ] **Step 1: 旧スキーマ（3モデル）でストアを作る**

`$SCRATCH`はセッションのスクラッチディレクトリ。`old.swift`:

```swift
import Foundation
import SwiftData

@Model final class Keep { var name: String; init(name: String) { self.name = name } }
@Model final class DropA { var text: String; init(text: String) { self.text = text } }
@Model final class DropB { var count: Int; init(count: Int) { self.count = count } }

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let schema = Schema([Keep.self, DropA.self, DropB.self])
let container = try ModelContainer(for: schema, configurations: [
    ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)])
let context = ModelContext(container)
context.insert(Keep(name: "残る")); context.insert(DropA(text: "消える")); context.insert(DropB(count: 1))
try context.save()
print("wrote kept=1 dropped=2")
```

Run: `cd $SCRATCH/dropspike && mkdir -p data && swiftc old.swift -o old && ./old $PWD/data/Reader.store`
Expected: `wrote kept=1 dropped=2`

- [ ] **Step 2: 新スキーマ（1モデル）で開き、読み、書き、再openする**

`new.swift`:

```swift
import Foundation
import SwiftData

@Model final class Keep { var name: String; init(name: String) { self.name = name } }

let url = URL(fileURLWithPath: CommandLine.arguments[1])
func open() throws -> ModelContainer {
    let schema = Schema([Keep.self])
    return try ModelContainer(for: schema, configurations: [
        ModelConfiguration("Reader", schema: schema, url: url, cloudKitDatabase: .none)])
}
do {
    let first = ModelContext(try open())
    print("opened; kept =", try first.fetchCount(FetchDescriptor<Keep>()))
    first.insert(Keep(name: "追加")); try first.save()
    let second = ModelContext(try open())
    print("reopened; kept =", try second.fetchCount(FetchDescriptor<Keep>()))
} catch { print("FAILED:", error) }
```

Run: `swiftc new.swift -o new && ./new $PWD/data/Reader.store`
Expected: `opened; kept = 1` と `reopened; kept = 2`。

- [ ] **Step 3: 結果で分岐する**

- 期待どおりなら、結果（macOS・Swift・出力）を台帳に記録して先へ進む。
- `FAILED:`が出る、または`kept`が合わない場合は、**ここで止まり、本人に報告して相談する**（旧モデルを一時的にスキーマに残す案、移行の案を提示する。ストアを自動削除しない）。以降のTaskには進まない。

スクラッチは削除する（`rm -rf $SCRATCH/dropspike`）。このTaskにコミットは無い。

---

### Task 2: ワークスペース状態とストアの補助（追加のみ）

**Files:**
- Modify: `Sources/ReaderCore/ReaderWorkspaceState.swift`、`Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ReaderWorkspaceTests.swift`、`Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: PR 3の`ReaderStore`（`themeMembers`、`articleThemeIDs`、`themeArticles`、`createTheme`、`addArticle`、`removeArticle`）。
- Produces:
  - `ReaderWorkspaceScope`に`.unfiledStars`と`.theme(UUID)`（旧`.dailyNotes`/`.weeklyNotes`はTask 7まで残す）
  - `ThemeFace: String, Sendable`（`.articles`/`.questions`）
  - `ReaderWorkspaceState.face(of:) -> ThemeFace`、`isReading(_:) -> Bool`、`switchFace(of:to:rememberingReader:)`
  - `ReaderStore.themeArticleIDs(themeID:keeping:) -> [UUID]`（`keeping`の既定値は`nil`。PR 3の呼び出しは変わらない）
  - `ReaderStore.isInAnyTheme(articleID:) -> Bool`
  - `ReaderStore.toggleTheme(_:for:at:) throws -> ThemeMembershipChange`（`ThemeMembershipChange`は`.added(themeName:)`/`.removed(themeName:)`）
  - `ReaderStore.createTheme(name:adding:at:) throws -> Theme`（作成と最初の記事の追加を1回の保存で行う）

- [ ] **Step 1: ワークスペースの失敗するテストを書く**

`ReaderWorkspaceTests`の末尾（最後の`}`の前）に追加する。

```swift
    @Test func themeFacesGateReadingAndKeepTheSavedReader() {
        var workspace = ReaderWorkspaceState()
        let themeID = UUID(), other = UUID()
        #expect(workspace.face(of: themeID) == .articles && workspace.isReading(.theme(themeID)))
        #expect(workspace.isReading(.unfiledStars) && workspace.isReading(.all))
        let article = UUID()
        var reader = ReaderSelectionState(); reader.select(article)
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: reader)
        #expect(workspace.face(of: themeID) == .questions && !workspace.isReading(.theme(themeID)))
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == article)
        #expect(workspace.face(of: other) == .articles)
        var later = ReaderSelectionState(); later.select(UUID())
        workspace.switchFace(of: themeID, to: .articles, rememberingReader: later)
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == article)
        #expect(workspace.isReading(.theme(themeID)))
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: later)
        var third = ReaderSelectionState(); third.select(UUID())
        workspace.rememberReader(third, in: .theme(themeID))
        #expect(workspace.reader(in: .theme(themeID)).selectedArticleID == later.selectedArticleID)
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ReaderWorkspaceTests`
Expected: FAIL（コンパイルエラー: `unfiledStars`・`face(of:)`などが未定義）

- [ ] **Step 3: ワークスペースを実装する**

`Sources/ReaderCore/ReaderWorkspaceState.swift`を次のように変更する。

```swift
import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), unfiledStars, theme(UUID), dailyNotes, weeklyNotes
    public var isReading: Bool {
        switch self { case .dailyNotes, .weeklyNotes: false; default: true }
    }
}

/// Which face of a theme is showing in the center and right columns.
public enum ThemeFace: String, Sendable { case articles, questions }

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    public var dailyNoteID: UUID?
    public var dailyOpened = false
    public var weeklyNoteID: UUID?
    public var weekKey: String
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var themeFaces: [UUID: ThemeFace] = [:]
    public init(at: Date = .now, timeZone: TimeZone = .current) {
        let current = WeekCalendar.range(containing: at, timeZone: timeZone)
        weekKey = WeekCalendar.range(containing: current.start.addingTimeInterval(-1), timeZone: timeZone).startDay
    }
    public func face(of themeID: UUID) -> ThemeFace { themeFaces[themeID] ?? .articles }
    /// A theme's questions face is not a reading surface: j/k, the article list and scroll memory do not apply.
    public func isReading(_ scope: ReaderWorkspaceScope) -> Bool {
        if case .theme(let id) = scope { return face(of: id) == .articles }
        return scope.isReading
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        guard isReading(scope) else { return }
        readers[scope] = state
    }
    /// Leaving the articles face saves the reader first; leaving the questions face never overwrites it.
    public mutating func switchFace(of themeID: UUID, to face: ThemeFace, rememberingReader state: ReaderSelectionState) {
        if self.face(of: themeID) == .articles { readers[.theme(themeID)] = state }
        themeFaces[themeID] = face
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
```

- [ ] **Step 4: 成功を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ReaderWorkspaceTests`
Expected: PASS（2件）。

`ReaderWorkspaceScope`に`case`を足すと、`ReaderView.swift`の2つの`switch`が網羅的でなくなり、パッケージ全体のビルドが通らなくなる。次の2行を一時的に足す（Task 4で本来の中身に置き換える）。`visibleArticleIDs`の`case .dailyNotes, .weeklyNotes: []`の直後に`case .unfiledStars, .theme: []`、`scopeTitle`の`case .weeklyNotes: "週ノート"`の直後に`case .unfiledStars, .theme: "テーマ"`。

- [ ] **Step 5: ストアの補助の失敗するテストを書く**

`ThemeTests`の末尾に追加する。

```swift
    @Test func themeListKeepsTheSelectedArticleUntilItMoves() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[2], toTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[0], ids[2]])
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: ids[0]) == [ids[0], ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id, keeping: nil) == [ids[2]])
        #expect(store.themeArticleIDs(themeID: theme.id) == [ids[2]])
    }

    @Test func isInAnyThemeFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        #expect(!store.isInAnyTheme(articleID: id))
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        #expect(store.isInAnyTheme(articleID: id))
        try store.removeArticle(id, fromTheme: theme.id, at: at)
        #expect(!store.isInAnyTheme(articleID: id))
    }

    @Test func toggleAddsThenRemovesAndNamesTheTheme() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let id = store.articles[0].id
        let theme = try store.createTheme(name: "金利", at: at)
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .added(themeName: "金利"))
        #expect(store.isInAnyTheme(articleID: id))
        #expect(try store.toggleTheme(theme.id, for: id, at: at) == .removed(themeName: "金利"))
        #expect(!store.isInAnyTheme(articleID: id))
        #expect(throws: ThemeError.self) { try store.toggleTheme(UUID(), for: id, at: at) }
    }

    @Test func creatingWithAnArticleIsOneAtomicSave() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let id = store.articles[0].id
        let expectedSummary = store.articles[0].summary.trimmingCharacters(in: .whitespacesAndNewlines)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", adding: id, at: at) }
        #expect(store.themes.isEmpty && store.themeArticles.isEmpty)
        let theme = try store.createTheme(name: "  成功  ", adding: id, at: at)
        #expect(theme.name == "成功" && store.themeIDs(containing: id) == [theme.id])
        #expect(!expectedSummary.isEmpty && store.themeArticles.first?.summary == expectedSummary)
        #expect(throws: ThemeError.self) { try store.createTheme(name: " ", adding: id, at: at) }
        #expect(throws: ThemeError.self) { try store.createTheme(name: "存在しない", adding: UUID(), at: at) }
        #expect(store.themes.count == 1)
    }
```

- [ ] **Step 6: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: FAIL（コンパイルエラー: `keeping:`・`isInAnyTheme`・`toggleTheme`・`createTheme(name:adding:at:)`が未定義）

- [ ] **Step 7: ストアの補助を実装する**

`Sources/ReaderCore/Themes.swift`の`extension ReaderStore`内で、`themeArticleIDs(themeID:)`を次の形に置き換え、`addArticle`の要約の計算を共有し、残りを追加する。

```swift
    public func themeArticleIDs(themeID: UUID, keeping: UUID? = nil) -> [UUID] {
        _ = themeArticles
        let members = themeMembers[themeID] ?? []
        guard !members.isEmpty || keeping != nil else { return [] }
        return articleIDs.filter { members.contains($0) || $0 == keeping }
    }
    public func isInAnyTheme(articleID: UUID) -> Bool {
        _ = themeArticles
        return articleThemeIDs[articleID] != nil
    }
    @discardableResult public func toggleTheme(_ themeID: UUID, for articleID: UUID, at: Date) throws -> ThemeMembershipChange {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        let name = theme.name
        if themeMembers[themeID]?.contains(articleID) == true {
            try removeArticle(articleID, fromTheme: themeID, at: at)
            return .removed(themeName: name)
        }
        try addArticle(articleID, toTheme: themeID, at: at)
        return .added(themeName: name)
    }
    /// Creates the theme and its first article in one save, so a failure never leaves an empty new theme behind.
    @discardableResult public func createTheme(name: String, adding articleID: UUID, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        guard let article = article(id: articleID) else { throw ThemeError.missingArticle }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        context.insert(ThemeArticle(themeID: theme.id, article: article, summary: recordedSummary(of: article, at: at), at: at))
        try save(); try reload()
        return theme
    }
    private func recordedSummary(of article: Article, at: Date) -> String {
        isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
```

`addArticle`内の`let summary = isContentAvailable(...) ? ... : ""`の1行を`let summary = recordedSummary(of: article, at: at)`に置き換える。ファイル末尾（`extension`の外）に追加する。

```swift
public enum ThemeMembershipChange: Equatable, Sendable {
    case added(themeName: String)
    case removed(themeName: String)
}
```

`ThemeTests`の`gatedStore`と`SaveGate`は同じstruct内の`private`なので、Step 5のテストからそのまま使える。

- [ ] **Step 8: 成功を確認し、全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS（ReaderCore 130＋新規5、ReaderUI 25）

```bash
git add Sources/ReaderCore Tests/ReaderCoreTests
git commit -m "feat: テーマの対象・面と、テーマ選択のためのストア補助を追加する"
```

---

### Task 3: AI入力に`themeArticle`を追加する（追加のみ）

**Files:**
- Modify: `Sources/ReaderCore/AIPackage.swift`、`Sources/RSSReader/AIReviewView.swift`
- Test: `Tests/ReaderCoreTests/AIPackageTests.swift`

**Interfaces:**
- Consumes: PR 3の`ThemeArticle`（`key`・`articleID`・`title`・`url`・`summary`・`addedAt`）。既存の`savedSource(selection:id:title:url:summary:savedAt:)`。
- Produces: `AIInputSelection.themeArticle(String)`。`aiSources(selections:)`は、記録した要約が空白だけなら`nil`（スクラップと同じ）。保存済み要約として扱うため、有効期限は元記事の期限と無関係に生成から24時間。

- [ ] **Step 1: 失敗するテストを書く**

`AIPackageTests`に追加する（`savedSummaryIgnoresOriginalExpiry`の直後）。

```swift
    @Test func themeSummaryIgnoresOriginalExpiryAndFollowsMembership() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, later = at.addingTimeInterval(31 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "記録した合成要約"
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
        let emptyArticle = store.articles[1]; emptyArticle.summary = ""
        let empty = try store.addArticle(emptyArticle.id, toTheme: theme.id, at: at)
        try store.purgeExpired(at: later)
        let review = AIPackageReview(store: store, now: { later })
        try review.build(selections: [.themeArticle(link.key)], language: "日本語", at: later)
        let saved = try #require(review.package)
        #expect(saved.expiresAt == later.addingTimeInterval(86_400))
        #expect(saved.sources[0].savedAt == at && saved.sources[0].content.coverage == .summaryOnly)
        #expect(saved.sources[0].title == article.title && saved.text.contains("Saved RSS snapshot"))
        #expect(try store.aiSources(selections: [.themeArticle(empty.key)], at: later).isEmpty)
        #expect(throws: (any Error).self) { try review.build(selections: [.themeArticle(empty.key)], language: "日本語", at: later) }
        try review.build(selections: [.themeArticle(link.key)], language: "日本語", at: later)
        try store.removeArticle(article.id, fromTheme: theme.id, at: later)
        #expect(throws: (any Error).self) { try review.validated(at: later) }
    }

    @Test func themeSummaryAndTheArticleItselfCannotBeMixed() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(a.id, toTheme: theme.id, at: at)
        let review = AIPackageReview(store: store, now: { at })
        #expect(throws: (any Error).self) { try review.build(selections: [.article(a.id), .themeArticle(link.key)], language: "日本語", at: at) }
        try review.build(selections: [.article(b.id), .themeArticle(link.key)], language: "日本語", at: at)
        #expect(review.package?.sources.count == 2)
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter AIPackageTests`
Expected: FAIL（コンパイルエラー: `.themeArticle`が未定義）

- [ ] **Step 3: 実装する**

`AIPackage.swift`の`AIInputSelection`を変更する。

```swift
public enum AIInputSelection: Hashable, Codable, Sendable {
    case article(UUID), scrap(String), noteSource(String), themeArticle(String)
}
```

`aiSources(selections:)`の`switch`に追加する（`case .noteSource`の後）。

```swift
            case .themeArticle(let key):
                guard let link = themeArticles.first(where: { $0.key == key }) else { return nil }
                return savedSource(selection: selection, id: link.articleID, title: link.title, url: link.url, summary: link.summary, savedAt: link.addedAt)
```

`AIReviewView.swift`の`refreshOptions()`の`switch selection`に追加する（`case .noteSource`の後）。

```swift
            case .themeArticle(let key):
                guard let saved = store.themeArticles.first(where: { $0.key == key }) else { return nil }
                return Option(id: selection, articleID: saved.articleID, title: saved.title, coverage: "テーマに記録したRSS要約 · " + saved.addedAt.formatted() + (source == nil ? " · 要約なし" : ""), available: source != nil)
```

- [ ] **Step 4: 成功を確認し、全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS

```bash
git add Sources Tests
git commit -m "feat: AI入力にテーマに記録した要約（themeArticle）を追加する"
```

---

### Task 4: サイドバーのテーマ区画と、テーマの[記事｜問い]画面

**Files:**
- Modify: `Sources/RSSReader/ReaderView.swift`
- Create: `Sources/RSSReader/ThemeViews.swift`（`ThemeFacePicker`、`ThemeQuestionsPane`、`UnderstandingEditor`）
- Test: `Tests/ReaderUITests/ThemeReaderTests.swift`（新規）

**Interfaces:**
- Consumes: Task 2の`ReaderWorkspaceScope.unfiledStars/.theme`、`ThemeFace`、`ReaderWorkspaceState.face/isReading/switchFace`、`store.themeArticleIDs(themeID:keeping:)`、`store.unfiledStarredArticleIDs(keeping:)`、`store.createTheme(name:at:)`、`renameTheme`、`deleteTheme`、`saveUnderstanding`。
- Produces: `ReaderView.init(..., initialScope: ReaderWorkspaceScope = .all, initialThemeFace: ThemeFace = .articles)`（試験用の入口。本番は既定値）。`ThemeFacePicker(face: Binding<ThemeFace>)`、`ThemeQuestionsPane(store:themeID:face:)`、`UnderstandingEditor(store:themeID:)`。

- [ ] **Step 1: 失敗する統合テストを書く**

`Tests/ReaderUITests/ThemeReaderTests.swift`を新規作成する（`ReaderLayoutTests`のヘルパーと同じ形を、この試験用に複製する）。

```swift
import AppKit
import SwiftUI
import ReaderCore
import Testing
@testable import RSSReader

@Suite(.serialized) @MainActor struct ThemeReaderTests {
    private struct NoLauncher: ClaudeLaunching {
        func open(_ url: URL) async throws { throw HandoffError.launchFailed }
    }
    private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let result = view as? T { return result }
        return view.subviews.lazy.compactMap { find(type, in: $0) }.first
    }
    private func settle(_ host: NSView, until ready: () -> Bool) async throws {
        for _ in 0..<100 {
            host.layoutSubtreeIfNeeded()
            if ready() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(ready(), "Synthetic reader did not reach the expected state")
    }
    private struct Harness {
        let store: ReaderStore
        let host: NSHostingView<ReaderView>
        let window: NSWindow
        let directory: URL
    }
    private func harness(scope: (ReaderStore) throws -> ReaderWorkspaceScope, face: ThemeFace = .articles,
                         prepare: (ReaderStore) throws -> Void) throws -> Harness {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try ReaderStore(url: directory.appendingPathComponent("Reader.store"))
        let entries = (0..<4).map { index in
            ParsedEntry(sourceID: "synthetic-\(index)", title: "合成記事 \(index)", url: URL(string: "http://127.0.0.1:1/article/\(index)"), summary: "合成要約", body: "合成本文", coverage: .feedProvided, publishedAt: .now.addingTimeInterval(Double(-index)))
        }
        _ = try store.importFeed(ParsedFeed(title: "合成購読", sourceURL: URL(string: "http://127.0.0.1:1/feed")!, entries: entries, skippedEntries: 0), receivedAt: .now)
        try prepare(store)
        let review = AIPackageReview(store: store)
        let reader = ReaderView(store: store, refresh: FeedRefreshController(store: store), aiReview: review,
            handoff: ClaudeHandoffController(directory: directory.appendingPathComponent("Handoff"), review: review, launcher: NoLauncher()),
            imageLoader: ReaderImageLoader(directory: directory.appendingPathComponent("Images")),
            initialScope: try scope(store), initialThemeFace: face)
        let host = NSHostingView(rootView: reader)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 800), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.toolbar = NSToolbar(identifier: "synthetic-theme-reader")
        window.contentView = host
        return Harness(store: store, host: host, window: window, directory: directory)
    }
    private func finish(_ harness: Harness) {
        harness.window.close(); try? FileManager.default.removeItem(at: harness.directory)
    }

    @Test func unfiledStarsListsOnlyStarredArticlesInNoTheme() async throws {
        let h = try harness(scope: { _ in .unfiledStars }) { store in
            let ids = store.articles.map(\.id)
            for id in ids.prefix(3) { try store.setStar(articleID: id, isStarred: true, at: .now) }
            _ = try store.createTheme(name: "A", adding: ids[0], at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 2 }
    }

    @Test func themeArticlesFaceListsOnlyTheThemesArticles() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            for id in store.articles.map(\.id).prefix(3) { try store.addArticle(id, toTheme: theme.id, at: .now) }
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 3 }
    }

    @Test func questionsFaceShowsTheUnderstandingEditorInsteadOfTheArticleList() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }, face: .questions) { store in
            let theme = try store.createTheme(name: "A", at: .now)
            try store.saveUnderstanding(themeID: theme.id, text: "既存のいまの理解", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host) == nil }
        try await settle(h.host) {
            var found = false
            func visit(_ view: NSView) {
                if let text = view as? NSTextView, text.string == "既存のいまの理解" { found = true }
                view.subviews.forEach(visit)
            }
            visit(h.host)
            return found
        }
    }

    @Test func emptyThemeAndEmptyInboxShowGuidanceWithoutRows() async throws {
        let h = try harness(scope: { store in .theme(store.themes[0].id) }) { store in
            _ = try store.createTheme(name: "空", at: .now)
        }
        defer { finish(h) }
        try await settle(h.host) { find(NativeArticleList.Table.self, in: h.host)?.numberOfRows == 0 }
        let inbox = try harness(scope: { _ in .unfiledStars }) { _ in }
        defer { finish(inbox) }
        try await settle(inbox.host) { find(NativeArticleList.Table.self, in: inbox.host)?.numberOfRows == 0 }
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeReaderTests`
Expected: FAIL（コンパイルエラー: `ReaderView`に`initialScope`・`initialThemeFace`が無い）

- [ ] **Step 3: `ThemeViews.swift`を作る**

`Sources/RSSReader/ThemeViews.swift`:

```swift
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

/// PR 4 shows only the "いまの理解" row; question rows arrive with PR 5.
struct ThemeQuestionsPane: View {
    @Bindable var store: ReaderStore
    let themeID: UUID
    @Binding var face: ThemeFace
    private var preview: String {
        let text = store.theme(id: themeID)?.understanding.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "まだ書かれていません" : text
    }
    var body: some View {
        List {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("いまの理解").font(.headline)
                    Text(preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } icon: { Image(systemName: "text.alignleft") }
                .padding(.vertical, 4)
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
```

- [ ] **Step 4: `ReaderView.swift`を変更する**

以下を順に適用する。**old**は現在の文字列、**new**は置き換え後。

(a) 状態の追加。old: `@State private var renamingFolder: String?\n    @State private var folderName = ""` → new:

```swift
    @State private var renamingFolder: String?
    @State private var folderName = ""
    @State private var creatingTheme = false
    @State private var newThemeName = ""
    @State private var renamingTheme: UUID?
    @State private var themeName = ""
    @State private var deletingTheme: UUID?
```

(b) 初期化。old の`init(...)`全体を次に置き換える。

```swift
    init(store: ReaderStore, refresh: FeedRefreshController, aiReview: AIPackageReview, handoff: ClaudeHandoffController, imageLoader: ReaderImageLoader,
         initialScope: ReaderWorkspaceScope = .all, initialThemeFace: ThemeFace = .articles) {
        self.store = store; self.refresh = refresh; self.aiReview = aiReview; self.handoff = handoff
        self.imageLoader = imageLoader
        _loading = State(initialValue: ArticleLoadingController(store: store))
        _scope = State(initialValue: initialScope)
        var workspace = ReaderWorkspaceState()
        if case .theme(let id) = initialScope, initialThemeFace != .articles {
            workspace.switchFace(of: id, to: initialThemeFace, rememberingReader: ReaderSelectionState())
        }
        _workspace = State(initialValue: workspace)
    }
```

(c) 一覧のID。`visibleArticleIDs`の`switch`に、`case .dailyNotes, .weeklyNotes: []`の直後へ追加する。

```swift
        case .unfiledStars: store.unfiledStarredArticleIDs(keeping: selection)
        case .theme(let id): store.themeArticleIDs(themeID: id, keeping: selection)
```

(d) タイトル。`scopeTitle`の`switch`に追加する。

```swift
        case .unfiledStars: "未整理のStar"
        case .theme(let id): store.theme(id: id)?.name ?? "テーマ"
```

(e) 対象の切り替え。`body`の`.onChange(of: scope) { old, new in ... }`全体を次に置き換える。

```swift
        .onChange(of: scope) { old, new in
            if let old, workspace.isReading(old) {
                scrollMemory.state.select(selection)
                workspace.rememberReader(scrollMemory.state, in: old)
            }
            workspace.scope = new ?? .all
            enterScope()
        }
```

(f) 詳細カラム。`reader`の`detail:`内の`} else { ZStack(alignment: .trailing) {`を次に置き換える（`else if`を1つ足す）。

```swift
            } else if case .theme(let id) = scope, workspace.face(of: id) == .questions {
                UnderstandingEditor(store: store, themeID: id).id(id)
            } else { ZStack(alignment: .trailing) {
```

(g) ツールバーと`shortcutsEnabled`の`isReading`。`(scope ?? .all).isReading`を`workspace.isReading(scope ?? .all)`に置き換える（2か所: ツールバーの`if`と`shortcutsEnabled`）。

(h) サイドバー。`Section("Notes") { ... }`のブロック全体（日次ノート・週の振り返りの2行）を次に置き換える。

```swift
            Section("テーマ") {
                sidebarRow("未整理のStar", symbol: "tray.full", count: store.unfiledStarCount).tag(LibraryScope.unfiledStars)
                ForEach(store.themes) { theme in
                    sidebarRow(theme.name, symbol: "square.stack", count: store.themeArticleCount(themeID: theme.id))
                        .tag(LibraryScope.theme(theme.id))
                        .contextMenu {
                            Button("名前を変更…") { themeName = theme.name; renamingTheme = theme.id }
                            Button("削除…", role: .destructive) { deletingTheme = theme.id }
                        }
                }
                Button { newThemeName = ""; creatingTheme = true } label: { Label("新しいテーマ", systemImage: "plus") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.vertical, 4)
                    .accessibilityLabel("新しいテーマを作る")
            }
```

(i) 一覧の空状態と上部の切り替え。`articleList`の`.overlay { if visibleArticleIDs.isEmpty { ... } }`を次に置き換え、その直後に`.safeAreaInset(edge: .top)`を足す。

```swift
        .overlay {
            if visibleArticleIDs.isEmpty {
                switch scope ?? .all {
                case .theme: ContentUnavailableView("記事が入っていません", systemImage: "square.stack",
                    description: Text("記事を選んで t キーを押すと、このテーマに入れられます。"))
                case .unfiledStars: ContentUnavailableView("未整理のStarはありません", systemImage: "tray.full",
                    description: Text("Starを付けた記事のうち、テーマに入っていないものがここに並びます。"))
                default: ContentUnavailableView("記事はありません", systemImage: "tray",
                    description: Text("購読を追加するか、ほかの一覧を選んでください。"))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if case .theme(let id) = scope { ThemeFacePicker(face: faceBinding(id)) }
        }
```

(j) 中央カラムの振り分け。`workspaceList`の`else { articleList.id(scope) }`を次に置き換える。

```swift
        else if case .theme(let id) = scope, workspace.face(of: id) == .questions {
            ThemeQuestionsPane(store: store, themeID: id, face: faceBinding(id)).id(id)
        }
        else { articleList.id(scope) }
```

(k) 新しい操作の関数。`private func move(_ offset: Int)`の直前に追加する。

```swift
    private func faceBinding(_ themeID: UUID) -> Binding<ThemeFace> {
        Binding(get: { workspace.face(of: themeID) }, set: { setFace($0, of: themeID) })
    }
    private func setFace(_ face: ThemeFace, of themeID: UUID) {
        guard workspace.face(of: themeID) != face else { return }
        scrollMemory.state.select(selection)
        workspace.switchFace(of: themeID, to: face, rememberingReader: scrollMemory.state)
        enterScope()
    }
    private func enterScope() {
        if workspace.isReading(workspace.scope) {
            let restored = workspace.reader(in: workspace.scope)
            scrollMemory.state = restored; selectArticle(restored.selectedArticleID); listFocused = true
        } else {
            if originalPage.url != nil { closeOriginal() }
            columnVisibility = .all; listFocused = false
            if workspace.scope == .dailyNotes, !workspace.dailyOpened {
                workspace.dailyNoteID = store.dailyNote(containing: .now)?.id
                workspace.dailyOpened = true
            }
        }
    }
```

(l) テーマの作成・名前変更・削除。`.alert("フォルダ名を変更", ...)`ブロックの直後（`reader`のmodifier列の末尾）に追加する。

```swift
        .alert("新しいテーマ", isPresented: $creatingTheme) {
            TextField("テーマの名前", text: $newThemeName)
            Button("作成") {
                let name = newThemeName
                perform { let theme = try store.createTheme(name: name, at: .now); scope = .theme(theme.id) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("関心のあるテーマの名前を入力します。記事は t キーで入れられます。") }
        .alert("テーマ名を変更", isPresented: Binding(get: { renamingTheme != nil }, set: { if !$0 { renamingTheme = nil } })) {
            TextField("テーマの名前", text: $themeName)
            Button("保存") {
                guard let id = renamingTheme else { return }
                let name = themeName
                perform { try store.renameTheme(id: id, to: name, at: .now) }
                renamingTheme = nil
            }
            Button("キャンセル", role: .cancel) { renamingTheme = nil }
        }
        .confirmationDialog("このテーマを削除しますか？", isPresented: Binding(get: { deletingTheme != nil }, set: { if !$0 { deletingTheme = nil } })) {
            Button("テーマを削除", role: .destructive) {
                guard let id = deletingTheme else { return }
                perform { try store.deleteTheme(id: id); if scope == .theme(id) { scope = .all } }
                deletingTheme = nil
            }
        } message: { Text("記事とStarは消えません。このテーマの問い・答え・いまの理解は消えます。") }
```

(m) `shortcutsEnabled`の`sheet:`引数を`addingSubscription || editingFeed != nil || renamingFolder != nil || creatingTheme || renamingTheme != nil`にする。

- [ ] **Step 5: 成功を確認し、全体を通してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS（ReaderUI 25＋新規4）。失敗する場合は、`ReaderView`の編集漏れ（特に`switch`の網羅性と`isReading`の置き換え）を直す。

```bash
git add Sources/RSSReader Tests/ReaderUITests
git commit -m "feat: サイドバーのテーマ区画と、テーマの[記事|問い]画面を追加する"
```

---

### Task 5: `t`キーとテーマ選択（`n`・スクラップの置き換え）

**Files:**
- Modify: `Sources/RSSReader/ReaderKeyboardCommands.swift`、`OriginalKeyboardBridge.swift`、`OriginalPageView.swift`、`NativeArticleList.swift`、`ReaderView.swift`
- Create: `Sources/RSSReader/ThemePickerView.swift`
- Test: `Tests/ReaderUITests/OriginalKeyboardTests.swift`、`NativeArticleListTests.swift`

**Interfaces:**
- Consumes: Task 2の`toggleTheme`・`createTheme(name:adding:at:)`・`isInAnyTheme`・`ThemeMembershipChange`。
- Produces: `ReaderCommand.themePicker`（`"t"`。`.scrap`は削除）、`ThemePickerView(store:articleID:onMessage:)`、`NativeArticleList.themed`・`Cell.configure(..., themed:)`（`scrapped`は削除）。

- [ ] **Step 1: 失敗するテストを書く（キー経路の置き換え）**

`OriginalKeyboardTests.swift`の次の2行を置き換える。

```swift
        errorPane.keyDown(with: try event("s")); errorPane.keyDown(with: try event("t"))
```

```swift
        #expect(commands == [.next, .previous, .toggleStar, .themePicker, .closeOriginal])
```

`NativeArticleListTests.swift`の`scrapped:`を`themed:`に置換する（3か所: `cell.configure(first, ... scrapped: false)`、`second ... scrapped: true`の2か所）。

同ファイルに、一覧のキー経路を確かめる試験を足す（`starKeyRoutesWithoutConsumingModifiedInput`の直後。既存の同名試験の書き方に合わせる）。まず既存のその試験を読み、同じ`Table`・`event`ヘルパーを使って、`t`が`keyHandler`に渡り、`n`は渡らないことを確かめる。

```swift
    @Test func themeKeyRoutesAndTheOldScrapKeyDoesNot() throws {
        let table = NativeArticleList.Table()
        var handled: [String] = []
        table.keyHandler = { handled.append($0); return true }
        func press(_ key: String, keyCode: UInt16, flags: NSEvent.ModifierFlags = []) throws {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                timestamp: 0, windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: keyCode))
            table.keyDown(with: event)
        }
        try press("t", keyCode: 17)
        try press("n", keyCode: 45)
        try press("t", keyCode: 17, flags: .command)
        #expect(handled == ["t"])
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter "OriginalKeyboardTests|NativeArticleListTests"`
Expected: FAIL（コンパイルエラー: `.themePicker`・`themed:`が未定義）

- [ ] **Step 3: キー経路を置き換える**

`ReaderKeyboardCommands.swift`:

```swift
enum ReaderCommand: String {
    case next = "j", previous = "k", toggleStar = "s", themePicker = "t", closeOriginal = "Escape"
}
```

`OriginalKeyboardBridge.swift`: `allowsScrap`を`allowsThemePicker`に改名し、JSの集合の`'n'`を`'t'`に、`command != .scrap`を`command != .themePicker`にする。

```swift
    private let allowsThemePicker: Bool
    init(allowsThemePicker: Bool = false, onCommand: @escaping (ReaderCommand) -> Void) {
        self.allowsThemePicker = allowsThemePicker; self.onCommand = onCommand
    }
```

```swift
          const keys = new Set(\(allowsThemePicker ? "['j','k','s','t','Escape']" : "['j','k','s','Escape']"));
```

```swift
              allowsThemePicker || command != .themePicker else { return }
```

`OriginalPageView.swift`: `OriginalKeyboardBridge(allowsScrap: true, onCommand: onCommand)`を`OriginalKeyboardBridge(allowsThemePicker: true, onCommand: onCommand)`にする。

`NativeArticleList.swift`:
- `var scrapped: (UUID) -> Bool = { _ in false }`を`var themed: (UUID) -> Bool = { _ in false }`に。
- キー集合`["j", "k", "m", "b", "v", "s", "n"]`を`["j", "k", "m", "b", "v", "s", "t"]`に。
- `cell.configure(..., scrapped: parent.scrapped(article.id))`を`themed: parent.themed(article.id)`に。
- `configure(... scrapped: Bool = false)`を`themed: Bool = false`に、本体の`(scrapped ? "▣ " : "")`を`(themed ? "▣ " : "")`に。

- [ ] **Step 4: テーマ選択ポップオーバーを作る**

`Sources/RSSReader/ThemePickerView.swift`:

```swift
import SwiftUI
import ReaderCore

/// Opened by `t` and by the toolbar icon. Checking a theme adds the article; unchecking removes it.
struct ThemePickerView: View {
    @Bindable var store: ReaderStore
    let articleID: UUID
    let onMessage: (String) -> Void
    @State private var newName = ""
    @State private var error: String?

    private var memberOf: Set<UUID> { Set(store.themeIDs(containing: articleID)) }
    private var canCreate: Bool { !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("テーマに入れる").font(.headline)
            if store.themes.isEmpty {
                Text("まだテーマがありません。下で作成すると、この記事が入ります。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(store.themes) { theme in
                            let included = memberOf.contains(theme.id)
                            Button { toggle(theme.id) } label: {
                                HStack {
                                    Image(systemName: included ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(included ? Color.orange : Color.secondary)
                                    Text(theme.name).lineLimit(1)
                                    Spacer()
                                }.contentShape(Rectangle()).padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(theme.name)
                            .accessibilityValue(included ? "入っています" : "入っていません")
                        }
                    }
                }.frame(maxHeight: 220)
            }
            Divider()
            HStack {
                TextField("新しいテーマの名前", text: $newName).onSubmit(create)
                Button("作成して入れる", action: create).disabled(!canCreate)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(14).frame(width: 300)
    }

    private func toggle(_ themeID: UUID) {
        do {
            switch try store.toggleTheme(themeID, for: articleID, at: .now) {
            case .added(let name): onMessage("「\(name)」に入れました")
            case .removed(let name): onMessage("「\(name)」から外しました")
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func create() {
        guard canCreate else { return }
        do {
            let theme = try store.createTheme(name: newName, adding: articleID, at: .now)
            onMessage("「\(theme.name)」に入れました")
            newName = ""; error = nil
        } catch { self.error = error.localizedDescription }
    }
}
```

- [ ] **Step 5: `ReaderView.swift`を変更する**

(a) 状態。`@State private var scrapMessage: String?`を次に置き換える。

```swift
    @State private var themeMessage: String?
    @State private var pickingTheme = false
    @State private var pickerRestoresListFocus = true
```

(b) メッセージの表示。`scrapMessage`を`themeMessage`にすべて置換する（`.overlay`・`.task(id:)`の3か所）。

(c) ツールバー。Starのボタンとglobeのボタンの間に追加する。

```swift
                    Button { perform(.themePicker) } label: {
                        Image(systemName: store.isInAnyTheme(articleID: article.id) ? "square.stack.fill" : "square.stack")
                    }
                    .help("テーマに入れる (t)").accessibilityLabel("テーマに入れる")
                    .popover(isPresented: $pickingTheme, arrowEdge: .bottom) {
                        ThemePickerView(store: store, articleID: article.id, onMessage: { themeMessage = $0 })
                    }
```

ポップオーバーがツールバーの項目に固定されず表示されない場合は、`.popover`をツールバーの`Button`から`reader`の`detail`側のビューへ移し、`attachmentAnchor: .rect(.bounds)`と`arrowEdge: .top`で右上に出す。この変更は台帳に判断として記録する。

(d) キー。`.onKeyPress("n") { ... perform(.scrap) ... }`を次に置き換える。

```swift
        .onKeyPress("t") { guard shortcutsEnabled else { return .ignored }; perform(.themePicker); return .handled }
```

(e) 選択を閉じたときの焦点。`.onChange(of: selection)`の直後に追加する。

```swift
        .onChange(of: pickingTheme) { _, open in
            if !open, originalPage.url == nil { listFocused = pickerRestoresListFocus }
        }
```

(f) 一覧のキー。`articleList`の`onKey`内の`case "n": perform(.scrap)`を`case "t": perform(.themePicker)`にする。`scrapped: { todayScrappedIDs.contains($0) }`を`themed: { store.isInAnyTheme(articleID: $0) }`にする。下部の案内`Text("n 保存")`を`Text("t テーマ")`にする。

(g) コマンド。`perform(_ command: ReaderCommand)`の`case .scrap:`のブロック全体を次に置き換える。

```swift
        case .themePicker:
            guard selectedArticle != nil, !pickingTheme else { return }
            pickerRestoresListFocus = ReaderKeyboardCommands.listHasFocus(declared: listFocused, responder: NSApp.keyWindow?.firstResponder)
            pickingTheme = true
```

(h) `todayScrappedIDs`のプロパティ（`private var todayScrappedIDs: Set<UUID> { ... }`）を削除する。

(i) `shortcutsEnabled`の`sheet:`引数に`|| pickingTheme`を足す。

- [ ] **Step 6: 成功を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS。`store.scrap`はまだ`Sources`に残る（Task 7で削除）。UIからは呼ばれない。

- [ ] **Step 7: コミットする**

```bash
git add Sources/RSSReader Tests/ReaderUITests
git commit -m "feat: tキーとツールバーでテーマに入れる選択を追加し、nキーのスクラップを置き換える"
```

---

### Task 6: 文言の整理と合成インスタンスでの確認

**Files:**
- Modify: `Sources/ReaderCore/DemoLibrary.swift`（文言のみ）、`Sources/RSSReader/ReaderSettingsView.swift`、`Sources/ReaderCore/AIPackage.swift`（依頼文）、`Sources/RSSReader/AIReviewView.swift`（注記）
- Test: 既存のテストで文言に依存するもの（`grep`で確認）

- [ ] **Step 1: 文言が試験に依存していないか確認する**

Run: `grep -rn "週ノート\|ノートへ採用\|ノートと出典\|ノートへ貼り付け" Tests Sources --include='*.swift'`
Expected: `DemoLibrary.swift`・`ReaderSettingsView.swift`・`AIPackage.swift`・`AIReviewView.swift`以外に、**試験側のヒットが無い**こと。試験側にヒットがあれば、その文言の期待値も同時に更新する。

- [ ] **Step 2: 文言を直す**

`DemoLibrary.swift`: 「週ノートで、その週に読んだ内容を自分の言葉で振り返ります。」を「Starで拾った記事は、テーマにまとめて、自分の言葉で理解を深められます。」に。「週ノートは、そんな記憶の入口になります。思い出したことを、自分の言葉で残してみてください。」を「テーマは、そんな記憶の入口になります。思い出したことを、自分の言葉で残してみてください。」に。

`ReaderSettingsView.swift`: 「ノートと出典は残ります。」を「テーマの記録は残ります。」に。「ノートと採用済み出典タイトル・リンクは自動削除しません。」を「テーマの記録（記事のタイトル・リンク・記録した要約、問い・答え・いまの理解）は自動削除しません。」に。

`AIPackage.swift`の依頼文: 「結果は本人が確認してノートへ採用します。ノートへの自動書込みはしないでください。」を「結果は本人が確認して自分の答えへ採用します。答えやいまの理解への自動書込みはしないでください。」に。`AIReviewView.swift`の注記: 「ノートへ貼り付け・編集してください」を「自分の答えとして貼り付け・編集してください」に。

- [ ] **Step 3: 全体を通す**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS

- [ ] **Step 4: 合成インスタンスで操作して確認する（UI変更の完了条件）**

合成の別インスタンスで、実際の画面を操作する。**本人のライブラリを使わない**（`--data-directory`は専用の一時ディレクトリ）。

```bash
bash scripts/build-app.sh release
open -n .build/Feeeder.app --args --data-directory /private/tmp/feeeder-theme-demo --seed-demo
pgrep -fl RSSReader
```

`pgrep`の出力に`--data-directory /private/tmp/feeeder-theme-demo`が含まれ、ウィンドウに合成購読（開発ノート・テクノロジー・週末の読み物）が見えることを確認してから操作する。確認する操作と期待:

1. 記事を3件選んで`s`でStar。左の「未整理のStar」が3になる。
2. 記事で`t`。ポップオーバーが開き、「まだテーマがありません」と作成欄が出る。名前を入れて「作成して入れる」→ メッセージが出て、左にテーマが現れ、アイコンが塗りつぶし、一覧の行に`▣`が付き、「未整理のStar」が2になる。
3. 別の記事で`t` → 既存テーマにチェックして入れる／外す。選択中の記事を外しても、一覧に次の移動まで残る。
4. 左のテーマを選ぶ。中央の上部に[記事｜問い]。「問い」に切り替えると、「いまの理解」だけの一覧になり、右にエディタが出る。入力して別のテーマ→戻ると残っている。アプリを終了して同じコマンドで再起動しても残る。
5. 記事面へ戻すと、直前に選んでいた記事と読書位置が戻る。
6. `t`をポップオーバーの入力欄に入力しても、記事の操作が起きない。IME変換中に`t`が奪われない（日本語入力で確認）。シート表示中・記事未選択の`t`は何も起こさない。
7. テーマの右クリックで名前変更と削除。表示中のテーマを削除すると「すべての記事」へ戻る。削除の確認に「記事とStarは消えません」と出る。
8. `v`で原文を開いた状態で`t`が使える。Escで戻る。
9. 左のNotes区画（日次・週）が無くなっている。

結果をスクリーンショットかAX値で記録し、確認できなかったものは未検証として残す。確認後、検証用アプリを終了し（`pkill -f 'feeeder-theme-demo'`）、`/private/tmp/feeeder-theme-demo`を削除する。

- [ ] **Step 5: コミットする**

```bash
git add Sources
git commit -m "chore: ノートの文言をテーマの文言に直す"
```

---

### Task 7: 旧ノートの削除

**Files:**
- Delete: `Sources/ReaderCore/DailyNotes.swift`、`Sources/ReaderCore/WeeklyNotes.swift`、`Sources/RSSReader/DailyNotesView.swift`、`Sources/RSSReader/WeeklyNotesView.swift`、`Tests/ReaderCoreTests/DailyNotesTests.swift`、`Tests/ReaderCoreTests/WeeklyNotesTests.swift`
- Modify: `Sources/ReaderCore/ReaderStore.swift`、`ReaderWorkspaceState.swift`、`AIPackage.swift`、`Sources/RSSReader/ReaderView.swift`、`AIReviewView.swift`、`Tests/ReaderCoreTests/{AIPackageTests,ClaudeHandoffTests,ContentRetentionTests,FeedClientTests,FolderTests,ReaderStoreTests,ReaderWorkspaceTests,V1StoreUpgradeTests}.swift`

**Interfaces:**
- Consumes: Task 2〜5までの成果物。
- Produces: スキーマが8モデル（`Feed`/`Article`/`ContentSnapshot`/`FeedMembership`/`ReaderSettings`/`Theme`/`ThemeArticle`/`ThemeQuestion`）になる。

- [ ] **Step 1: 削除前に、参照の一覧を取る**

Run: `grep -rn "DailyNote\|NoteScrap\|WeeklyPeriod\|WeeklyNote\|NoteSource\|dailyNotes\|\.scraps\|noteSources\|\.scrap(\|createNote\|adoptSources\|adoptScraps\|\.weeks\b\|\.notes\b\|WeekCalendar\|WeekRange\|\.dailyNotes\|\.weeklyNotes\|dailyOpened\|NotePane" Sources Tests --include='*.swift' | cut -d: -f1 | sort | uniq -c`
Expected: 削除対象のファイルと、上の「Modify」に挙げたファイルだけが出る。他のファイルが出たら、そのファイルも同じ方針で直す。

- [ ] **Step 2: 旧ファイルを削除する**

```bash
git rm Sources/ReaderCore/DailyNotes.swift Sources/ReaderCore/WeeklyNotes.swift \
  Sources/RSSReader/DailyNotesView.swift Sources/RSSReader/WeeklyNotesView.swift \
  Tests/ReaderCoreTests/DailyNotesTests.swift Tests/ReaderCoreTests/WeeklyNotesTests.swift
```

- [ ] **Step 3: コアの参照を外す**

`ReaderStore.swift`:
- プロパティ`weeks`・`notes`・`noteSources`・`dailyNotes`・`scraps`を削除する。
- `schema`を次にする。

```swift
    public static var schema: Schema {
        Schema([Feed.self, Article.self, ContentSnapshot.self, FeedMembership.self, ReaderSettings.self,
                Theme.self, ThemeArticle.self, ThemeQuestion.self])
    }
```

- `reload()`から`weeks`・`notes`・`noteSources`・`dailyNotes`・`scraps`の`fetch`を削除する。

`ReaderWorkspaceState.swift`を次にする（`WeekCalendar`依存と旧フィールドを削除）。

```swift
import Foundation

public enum ReaderWorkspaceScope: Hashable, Sendable {
    case all, unread, starred, feed(UUID), folder(String), unfiledStars, theme(UUID)
}

/// Which face of a theme is showing in the center and right columns.
public enum ThemeFace: String, Sendable { case articles, questions }

public struct ReaderWorkspaceState {
    public var scope: ReaderWorkspaceScope = .all
    private var readers: [ReaderWorkspaceScope: ReaderSelectionState] = [:]
    private var themeFaces: [UUID: ThemeFace] = [:]
    public init() {}
    public func face(of themeID: UUID) -> ThemeFace { themeFaces[themeID] ?? .articles }
    /// A theme's questions face is not a reading surface: j/k, the article list and scroll memory do not apply.
    public func isReading(_ scope: ReaderWorkspaceScope) -> Bool {
        if case .theme(let id) = scope { return face(of: id) == .articles }
        return true
    }
    public mutating func rememberReader(_ state: ReaderSelectionState, in scope: ReaderWorkspaceScope) {
        guard isReading(scope) else { return }
        readers[scope] = state
    }
    /// Leaving the articles face saves the reader first; leaving the questions face never overwrites it.
    public mutating func switchFace(of themeID: UUID, to face: ThemeFace, rememberingReader state: ReaderSelectionState) {
        if self.face(of: themeID) == .articles { readers[.theme(themeID)] = state }
        themeFaces[themeID] = face
    }
    public func reader(in scope: ReaderWorkspaceScope) -> ReaderSelectionState { readers[scope] ?? ReaderSelectionState() }
}
```

`AIPackage.swift`: `AIInputSelection`を`case article(UUID), themeArticle(String)`にし、`aiSources`の`.scrap`・`.noteSource`の`case`を削除する。

- [ ] **Step 4: UIの参照を外す**

`ReaderView.swift`:
- `visibleArticleIDs`・`scopeTitle`の`.dailyNotes, .weeklyNotes`の`case`を削除する。
- `body`の`.onChange(of: scope)`は変更不要。`enterScope()`の`if workspace.scope == .dailyNotes, ...`ブロックを削除する。
- `reader`の`detail:`の`if scope == .dailyNotes { ... } else if scope == .weeklyNotes { ... } else if case .theme ...`から、先頭2つの分岐を削除し、`if case .theme(let id) = scope, workspace.face(of: id) == .questions { ... } else { ZStack ... }`にする。
- `workspaceList`の`if scope == .dailyNotes ... else if scope == .weeklyNotes ...`を削除する。
- `aiReview`・`handoff`は`ReaderView`の中で使われなくなるが、プロパティと`RSSReaderApp`からの受け渡しは**残す**（PR 8で再び使う）。

`AIReviewView.swift`: `refreshOptions()`の`case .scrap`・`case .noteSource`を削除する。

- [ ] **Step 5: 旧ノートを使っていたテストを置き換える**

`ReaderStoreTests.swift`の`failedRecoveryBlocksChangesUntilReloadSucceeds`から、旧ノートの準備と変更経路を削除する。

- 準備: `let range = WeekCalendar...`、`let note = try store.createNote(...)`、`try store.saveNote(...)`、`let scrap = try store.scrap(...)`の4行を削除。
- 変更経路の配列から、`createNote`・`saveNote`・`adoptSources`・`adoptScraps`・`deleteNote`・`scrap`・`saveDailyNote`・`saveScrapMemo`・`removeScrap`・`deleteDailyNote`の10行を削除。
- 既存の`try store.addArticle(article.id, toTheme: theme.id, at: at)`（`createTheme`の直後の行）を`let link = try store.addArticle(article.id, toTheme: theme.id, at: at)`に変える。`#expect(throws: (any Error).self) { _ = try store.aiSources(selections: [.scrap(scrap.key)], at: at) }`は、`.themeArticle(link.key)`を使う形に置き換える。

- 再試行後の確認から、`reopened.notes`・`dailyNotes`・`scraps`の行を削除し、テーマの行（`reopened.theme(id: theme.id)?.understanding == "再試行した理解"`）を残す。
- `try store.saveNote(id: note.id, text: "再試行した本文", at: at)`を削除する。

`ReaderWorkspaceTests.swift`の旧試験`notesRoundTripRestoresReader`を、次に置き換える（`ReaderWorkspaceState()`の引数が無くなる）。

```swift
    @Test func themeRoundTripRestoresReader() {
        var workspace = ReaderWorkspaceState()
        let article = UUID(), top = UUID(), themeID = UUID()
        var reader = ReaderSelectionState(); reader.select(article); reader.listScrollAnchor = top
        reader.recordScroll(articleID: article, anchor: "paragraph-9", offset: 521)
        workspace.rememberReader(reader, in: .unread)
        workspace.scope = .theme(themeID)
        workspace.switchFace(of: themeID, to: .questions, rememberingReader: ReaderSelectionState())
        workspace.scope = .unfiledStars
        workspace.scope = .unread
        let restored = workspace.reader(in: .unread)
        #expect(restored.selectedArticleID == article && restored.listScrollAnchor == top)
        #expect(restored.scrollOffsets[article] == 521 && restored.scrollAnchors[article] == "paragraph-9")
        #expect(workspace.face(of: themeID) == .questions)
        #expect(workspace.reader(in: .all).selectedArticleID == nil)
    }
```

`AIPackageTests.swift`: 旧`savedSummaryIgnoresOriginalExpiry`と`mixedSourcesUseEarliestExpiryAndRejectDuplicateArticles`を削除する（Task 3で`themeSummaryIgnoresOriginalExpiryAndFollowsMembership`・`themeSummaryAndTheArticleItselfCannotBeMixed`が同じ性質を確認している）。ただし**期限の混在**を確かめていた後者の`expiresAt == received + 7日`の性質は、次の試験で引き継ぐ。

```swift
    @Test func mixedSourcesUseTheEarliestExpiry() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let at = Date.now, received = at.addingTimeInterval(-6.5 * 86_400)
        let store = try ReaderStore(url: library.url, seedDemo: true, now: received)
        try store.applyRetention(days: 7, at: at)
        let a = store.articles[0], b = store.articles[1]
        let theme = try store.createTheme(name: "A", at: received)
        let link = try store.addArticle(a.id, toTheme: theme.id, at: received)
        let review = AIPackageReview(store: store, now: { at })
        try review.build(selections: [.article(b.id), .themeArticle(link.key)], language: "日本語", at: at)
        #expect(review.package?.expiresAt == received.addingTimeInterval(7 * 86_400))
        try review.build(selections: [.themeArticle(link.key)], language: "日本語", at: at)
        try store.deleteContent(articleIDs: [a.id], at: at)
        #expect(review.package != nil)
    }
```

`ClaudeHandoffTests.swift`の`savedSourcesAndOldMetadataReconcile`: `let scrap = try store.scrap(articleID: id, at: at, timeZone: .current)`を次に、`.scrap(scrap.key)`を`.themeArticle(link.key)`に置き換える。

```swift
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(id, toTheme: theme.id, at: at)
```

`ContentRetentionTests.swift`の`deletionProtectsNotesAndSourcesAcrossReopen`を次に置き換える。

```swift
    @Test func deletionProtectsThemeRecordsAcrossReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let themeID = try autoreleasepool {
            let store = try ReaderStore(url: library.url, now: start)
            let feed = try store.importFeed(parsed(), receivedAt: start)
            let article = try #require(store.articles.first)
            try store.markDisplayed(articleID: article.id, at: start)
            let theme = try store.createTheme(name: "記録", at: start)
            try store.saveUnderstanding(themeID: theme.id, text: "残す理解", at: start)
            try store.addArticle(article.id, toTheme: theme.id, at: start)
            try store.deleteContent(articleIDs: [article.id], at: start)
            try store.unsubscribe(feed)
            #expect(article.firstReadAt == start && article.firstReceivedAt == start)
            _ = try store.importFeed(parsed(), receivedAt: start.addingTimeInterval(day))
            #expect(try store.content(articleID: article.id, at: start) == nil)
            return theme.id
        }
        let reopened = try ReaderStore(url: library.url, now: start.addingTimeInterval(90 * day))
        #expect(reopened.theme(id: themeID)?.understanding == "残す理解")
        #expect(reopened.themeArticles.first?.url == "https://publisher.example/posts/1")
        #expect(reopened.articles.count == 1 && reopened.articles.first?.summary == "")
    }
```

`FeedClientTests.swift`の`failuresAndNotModifiedPreserveSavedReadingData`: `let note = try store.createNote(...)`と`try store.saveNote(...)`の2行を次にし、`#expect(store.notes.first?.text == "消えない")`を`#expect(store.theme(id: themeID)?.understanding == "消えない")`にする。

```swift
        let themeID = try store.createTheme(name: "保存テーマ", at: now).id
        try store.saveUnderstanding(themeID: themeID, text: "消えない", at: now)
```

`FolderTests.swift`の`movingAndRenamingRetainsSelection`: `let scrap = try store.scrap(...)`を次にし、末尾の`#expect(store.scraps.first { $0.key == scrap.key }?.summary == scrap.summary)`を`#expect(store.themeArticles.first?.summary == link.summary)`にする。

```swift
        let theme = try store.createTheme(name: "A", at: at)
        let link = try store.addArticle(article.id, toTheme: theme.id, at: at)
```

- [ ] **Step 6: 保存データの検証（opt-in）を新しいスキーマに合わせる**

`V1StoreUpgradeTests.swift`:
- 許可する基準commitの配列に、beta.3（`1007dce`のフルハッシュ）と現行main（`215b901ffc3863b3e1afd1e17a76b18101fc0cb6`）を足す。`1007dce`のフルハッシュは`git rev-parse 1007dce`で取得して書く。
- 旧ノートの検証（`store.weeks`・`store.notes`・`store.noteSources`・`store.dailyNotes`・`store.scraps`を使う行、`if let dailyID = expected.dailyNoteID ... else {...}`ブロック）を削除する。購読・記事・既読・期限・本文・Star（`article.starredAt`）の行は残す。
- 新スキーマでの書き込みを確認する。`for _ in 0..<2`を`for round in 0..<2`にし、各回の最後に次を足す。

```swift
                if round == 0 {
                    let theme = try store.createTheme(name: "移行後のテーマ", at: at)
                    try store.addArticle(article.id, toTheme: theme.id, at: at)
                } else {
                    #expect(store.themes.map(\.name) == ["移行後のテーマ"] && store.themeArticles.count == 1)
                }
```

`scripts/prepare-v1-store-fixture.sh`: 許可する基準commitの`case`にbeta.3と現行mainを足し、`if sys.argv[2] == 'f9db83b49a82947a7031ddf874bc94fcb91ef89d':`（Star・スクラップを足す分岐）を、それら3つのcommitのいずれかの場合に実行する条件にする。現行main（`215b901`）の`ReaderStore`でも、生成コードが使うAPI（`importFeed`・`markDisplayed`・`createNote`・`adoptSources`・`setStar`・`scrap`）が存在することは、Step 1の時点で確認済み（それらはこのTaskで削除されるが、フィクスチャは**基準commitのソース**をビルドして作るため影響しない）。

- [ ] **Step 7: 全体を通す**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS。件数は、削除した試験の分だけ減る（`DailyNotesTests`・`WeeklyNotesTests`・`AIPackageTests`の2件を置き換え）。減った件数と理由を台帳に記録する。

- [ ] **Step 8: 破壊しないことの確認とコミット**

Run: `git grep -n "DailyNote\|NoteScrap\|WeeklyPeriod\|WeeklyNote\|NoteSource\|WeekCalendar" -- Sources Tests`
Expected: 出力なし。

```bash
git add -A Sources Tests scripts
git commit -m "refactor: 日次ノート・週ノート・スクラップを削除し、スキーマを8モデルにする"
```

---

### Task 8: 旧ストアの再open・文書・検証記録・レビュー依頼

**Files:**
- Modify: `README.md`、`docs/specification.md`（冒頭の「改訂中」注記）、`docs/architecture.md`（§2.1・§3.2・§6.1の状態）、`docs/decisions/0004-…md`・`0008-…md`・`0009-…md`・`docs/decisions/README.md`（状態）、`docs/superpowers/plans/2026-10-10-theme-notes.md`（ロードマップのPR 4の記述）
- Create: `docs/verification/YYYY-MM-DD-theme-screens.md`（YYYY-MM-DDは実行日）

- [ ] **Step 1: 現行ベータ（日次・週ノート・スクラップを含む）のストアを、新スキーマで開く**

3つの基準commitのそれぞれで、合成ストアを作り、新スキーマで2回openする。fixtureは存在しない専用ディレクトリに作る。

```bash
bash scripts/prepare-v1-store-fixture.sh /private/tmp/feeeder-fixture-beta2-pr4 f9db83b49a82947a7031ddf874bc94fcb91ef89d
bash scripts/prepare-v1-store-fixture.sh /private/tmp/feeeder-fixture-beta3-pr4 $(git rev-parse 1007dce)
bash scripts/prepare-v1-store-fixture.sh /private/tmp/feeeder-fixture-main-pr4 215b901ffc3863b3e1afd1e17a76b18101fc0cb6
for d in beta2 beta3 main; do
  FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-fixture-$d-pr4 swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter V1StoreUpgradeTests
done
```

Expected: 3回ともPASS（購読・記事・既読・期限・本文・Starが残り、新スキーマでテーマの書き込みと再openができる）。**1つでも失敗した場合は、原因を記録して止まり、本人に相談する**（実DBを自動削除・再作成しない。旧モデルを一時的にスキーマへ残す案を提示する）。

- [ ] **Step 2: Releaseビルドと全体の検査**

```bash
bash scripts/build-app.sh release
swift test --scratch-path /private/tmp/feeeder-dogfooding-build
git diff --check origin/main
```

Expected: すべて成功。

- [ ] **Step 3: 文書を更新する**

- `README.md`: 機能の説明（Star・日次スクラップ・週ノート）をテーマに合わせて書き換える。`n`の説明を`t`に、「日次ノート」「週の振り返り」の段落を「テーマ」の段落に、左カラムの説明を「Feeds／テーマ／購読元」に、AI入力の入口の説明を「テーマからのClaude連携はPR 8まで無い」に、保存データの説明（ノート→テーマ）を直す。現行の挙動だけを書く（まだ無い問いは書かない）。
- `docs/specification.md`冒頭の「改訂中の範囲」: 「実装は段階的に進め、現行ベータは日次ノート・週の振り返り・スクラップ（`n`）のまま」を、「実装済み: テーマの区画・[記事｜問い]（問いの面は「いまの理解」のみ）・`t`・未整理のStar。未実装: 問いとレンズ（PR 5）、端末内AI（PR 6・7）、テーマからのClaude連携（PR 8、それまで入口が無い）」に直す。
- `docs/architecture.md`§2.1: 「実装は段階的で、…旧5モデルが残り13モデル」を、現在の8モデルに合わせて直す。§3.2の「置き換えの間は入口が無く…」はPR 8まで有効なので維持する。
- 決定記録: [0008](../../decisions/0008-theme-centered-notes.md)・[0009](../../decisions/0009-on-device-ai-principles.md)の状態を「有効（PR #21のマージで承認）」に、[0004](../../decisions/0004-dogfooding-keys-and-scrap.md)の状態を「一部置換済み: 日次・週ノート、スクラップ、週候補は0008」に、`docs/decisions/README.md`の状態列を同じにする。
- ロードマップ（`2026-10-10-theme-notes.md`）のPR 4の行に、「問いの面は『いまの理解』のみ」を足す。

- [ ] **Step 4: 検証記録を書く**

`docs/verification/YYYY-MM-DD-theme-screens.md`に、対象commit、環境（OS・Swift・機種）、コマンドと結果（PASS／FAIL／NOT_RUN）、テスト件数（削除した試験の件数と理由を含む）、Task 1の先行調査の結果、3つの基準commitのストア再openの結果、Task 6 Step 4で確認した操作と結果（スクリーンショットまたはAX値）、**未検証**（IME変換、VoiceOver、Reduce Motion、数千件規模の表示速度、macOS 26のCI、`t`の複数ウィンドウ時の挙動、ドラッグ&ドロップ）を書く。

- [ ] **Step 5: 独立レビューを依頼する**

保存データの扱い・キー入力・削除を含む変更なので、`AGENTS.md`の完了条件8に従い、**固定commit**に対して`docs/review-checklist.md`の観点で独立レビューを依頼する（`superpowers:requesting-code-review`）。レビュー担当は読み取り専用で、アプリの起動・実機試験は行わない。指摘は、効果で再評価し、Critical・Importantは失敗するテストを先に書いて直す。

- [ ] **Step 6: コミットし、PRの準備をする**

```bash
git add README.md docs
git commit -m "docs: テーマ画面の実装状況と検証記録を反映する"
```

PR本文は`.github/pull_request_template.md`に従う。**含めないもの**: 問い・レンズ・答え（PR 5）、端末内AI（PR 6・7）、Claude連携の入口（PR 8）、ドラッグ&ドロップ。**未検証**: Step 4の一覧。**リスク**: 旧ノートのデータは新モデルへ移行されず、新スキーマで開くと見えなくなる（ベータ間の互換は保証しない。決定0003）。pushとPR作成は本人の許可を得てから行う。
