# Dogfooding Reader Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する。

**Goal:** 気持ちよく記事を読み、Starで関心を示し、日次スクラップから週の振り返りへつなげる3カラムを作る。

> 2026-10-07の方針変更: 本計画は当時の実装・検証の履歴として残す。以後のベータ間のデータ互換性は保証せず、保持試験は任意の手動実行にする。同じ版の保存・再起動による保持は維持し、1.0以降の保証とCI復帰は現行[PRD](../../specification.md)を正とする。

**Architecture:** SwiftDataに任意属性と日次ノートを追加し、配布済みV1のデータを保持する。既存のNavigationSplitView・NSTableView・NSTextViewとClaudeハンドオフを拡張し、保存済みスクラップの寿命を元記事から分離する。画像は取得・縮小を読書描画から分離して容量制限付きで保存する。

**Tech Stack:** Swift 6、SwiftUI、AppKit、SwiftData、WebKit、Foundation／URLSession、ImageIO、既存のSwiftSoup 2.13.9、Swift Testing。外部依存の追加なし。

**Spec:** [PRD](../../specification.md)第3・5・7節、[Architecture](../../architecture.md)第6節。仕様承認: [PR #6](https://github.com/ojiman/feeeder/pull/6)、main `728877d9bb684160238026d9f242a89c56d8d24c`。本計画は[PR #7](https://github.com/ojiman/feeeder/pull/7)のマージで承認済み。実装・検証結果は[今回の受入記録](../../verification/2026-10-07-dogfooding-acceptance.md)へ記録し、計画承認を最終製品受入とは扱わない。

## Global Constraints

- macOS 26.6以降。Backend、アカウント、同期、無人workerを追加しない。単独writerで進める。
- `j/k`＝次／前記事、`s`＝Star付け外し、`n`＝当日の既定ノートへのスクラップ、`b/v`＝外部／アプリ内原文、`Esc`＝現在の記事の読書位置へ復帰。既存の`m`＝既読切替も維持する。
- 入力欄・IME変換・修飾キーを使う標準操作を優先する。原文中の移動は原文表示を維持し、URLなしなら当該記事の読書表示へ戻る。
- スクラップはタイトル・URL・保持中のRSS要約・編集可能な本人のメモ。全文や推測要約は複製しない。同日の再保存で重複・上書きをしない。
- 記事本文・RSS要約の初期保持期間は30日、既存設定7／30／90／365日を維持。Starとスクラップは記事の期限を延長しない。ノート・保存済みスクラップ要約は自動削除しない。
- 日・週は初回作成時の期間・タイムゾーンを保存し、タイムゾーン変更だけで過去の期間・採用済み出典を変更しない。
- 実際のV1保存データを保持する。プロトタイプ移行・互換モデル・データの初期化による復帰を実装しない。
- Claude連携は検証済みCowork経路。利用者の送信前確認・専用一時フォルダ・内容一致検査・再試行を維持する。
- Share、任意期間へのスクラップ、通常Chat添付調査、署名・Release公開は今回の実装範囲に含めない。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・ブラウザprofileを使わない。

## Review Focus

1. ベータのファイルDBを更新後に開く: 購読・同一性・既読・期限・週・ノート・出典を保持する（Task 1）。
2. フォルダ／Star一覧の選択中に所属・状態が変わる: 次の移動まで記事を保ち、重複計上しない（Task 1・7）。
3. 原文の入力欄・iframe・IMEと、古い描画callback: 誤操作・誤既読・本文の取り違えを起こさない（Task 2）。
4. 日付／タイムゾーン変更と保存失敗: スクラップ先を固定期間で選び、部分保存・重複・メモ上書きを避ける（Task 3）。
5. 期限後の保存済み要約と遅延画像: AI入力の由来を正しく示し、画像の失敗や到着で読書位置を動かさない（Task 5・6・7）。

## File Structure and Execution

| Task | 作成・変更するファイル | 責務と検証 |
|---|---|---|
| 1 | `Models.swift`, `ReaderStore.swift`, `WeeklyNotes.swift`; 新規`DailyNotes.swift`, `Stars.swift` | 追加スキーマ、既存V1の保持、Star操作。新規`V1StoreUpgradeTests.swift`, `StarTests.swift`, `scripts/prepare-v1-store-fixture.sh` |
| 2 | `ReaderView.swift`, `ReaderKeyboardCommands.swift`, `OriginalPageView.swift`, `ReaderSelectionState.swift`, `OriginalPageState.swift` | 原文と読書の共通コマンド。`ReaderSelectionTests.swift`, `OriginalPageTests.swift`; 新規UI `OriginalKeyboardTests.swift` |
| 3 | `DailyNotes.swift`, `ReaderStore.swift` | 日次スクラップの保存・編集・削除。新規`DailyNotesTests.swift` |
| 4 | `WeeklyNotes.swift`, `ReaderView.swift`, `WeeklyNotesView.swift`; 新規UI `DailyNotesView.swift`, `ReaderWorkspaceState.swift` | 週候補・独立した採用済み要約・共通3カラム。`WeeklyNotesTests.swift`; 新規UI `ReaderWorkspaceTests.swift` |
| 5 | `AIPackage.swift`, `HandoffFiles.swift`, `ClaudeHandoffController.swift`, UI `AIReviewView.swift`, 日次／週ノート | 保存済み要約と記事の選択・寿命の分離。`AIPackageTests.swift`, `ClaudeHandoffTests.swift` |
| 6 | `FeedParser.swift`, `ReaderStore.swift`; 新規Core `ReaderImages.swift`, `ImageMetadata.swift` | 画像URLの取込み、取得・縮小・容量制限。`FeedParserTests.swift`; 新規`ReaderImageTests.swift` |
| 7 | `ReaderStore.swift`, `ReaderView.swift`, `NativeArticleList.swift`, `ArticleDetailView.swift`, `SubscriptionSheet.swift`; 新規Core `Folders.swift`, UI `ArticleImageView.swift` | フォルダ操作・画像のUI統合。新規`FolderTests.swift`; `NativeArticleListTests.swift` |
| 8 | `README.md`, `docs/architecture.md`; 新規`docs/verification/2026-10-07-dogfooding-acceptance.md` | 全体確認・保存／性能／実機受入と残る確認の記録 |

Coreの相対パスは`Sources/ReaderCore/`、UIは`Sources/RSSReader/`。Coreテストは`Tests/ReaderCoreTests/`、UIテストは`Tests/ReaderUITests/`。既存ファイル全体の再編は行わず、表に示した責務だけを切り出す。

順序は1→2→3→4→5→6→7→8。1・2でStarと原文移動を使用可能にし、3〜5で日次・週・AIをつなぎ、6・7でフォルダと画像を加える。単独実装のため並列writerを使わない。

共通のテストコマンドは`swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter <SuiteName>`。各Taskの赤→緑を記録し、commit前に対象テストと`git diff --check`を実行する。スキーマ変更時とTask 8は全`FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-v1-store-fixture swift test --scratch-path /private/tmp/feeeder-dogfooding-build`を実行する。UI変更時は`bash scripts/build-app.sh debug`でビルドする。期待値は終了コード0・失敗0件で、GUI確認をテストだけでPASSにしない。

## Task 1: V1保存データの保持とStar

**Interfaces:** `ReaderStore.setStar(articleID: UUID, isStarred: Bool, at: Date) throws`、`starredArticleIDs(keeping: UUID?) -> [UUID]`。後続が使うモデルは`DailyNote`と`NoteScrap`、`ReaderStore.dailyNotes: [DailyNote]`、`scraps: [NoteScrap]`。

- [ ] **赤の準備:** `scripts/prepare-v1-store-fixture.sh <destination>`を作る。配布版commit `53102cc42ea665b3379ad2a23d842c3186ad9c3e`のソースを`git archive`で一時領域に取り出し、そこでだけ小さなfixture生成用実行targetを追加する。元の8モデルの`ReaderStore`で購読・記事・本文・既読・週ノート・出典を作り、プロセス終了後のDBファイル群と期待値JSONを出力する。プロダクトに旧モデルを持ち込まず、生成時のcommit・Swift版・ファイルhashを記録する。
- [ ] **赤のテスト:** `V1StoreUpgradeTests.preservesReleasedV1Store()`で旧版ファイルをコピーしてfixtureの固定時刻を`now`へ渡した新`ReaderStore`で開き、全ID・日時・設定・本文・週期間・ノート本文・出典タイトルURLが期待値と一致すると検証する。再openでも同じで、新属性はnil／新ノートは0件。環境変数`FEEEDER_V1_FIXTURE_DIR`で専用fixtureディレクトリを指定し、未生成は明示的なテスト失敗とする。
- [ ] **Starの赤:** `StarTests.togglePreservesReadDatesAndExpiry()`で付与→解除→再付与の日時、既読日時・期限の不変、再受信／期限削除／再open後のStarを検証する。`keepsUnstarredSelectionUntilMove()`は解除した選択IDを`keeping`ありでは含み、なしでは含まない。別の未Star記事を誤って含めない。
- [ ] **赤の確認:** fixture生成後、`FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-v1-store-fixture swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter 'V1StoreUpgradeTests|StarTests'`。新属性・API未定義または新仕様のassertでFAILすることを確認する。

```swift
#expect(store.articles.map(\.id) == expected.articleIDs)
#expect(store.articles.allSatisfy { $0.starredAt == nil })
#expect(store.dailyNotes.isEmpty && store.scraps.isEmpty)
#expect(reopened.notes.map(\.text) == expected.noteTexts)
```
- [ ] **実装:** `Article.starredAt: Date?`、画像用の`Article.imageURL: String?`・`Feed.siteURL: String?`・`iconURL: String?`を追加する。`NoteSource`に`summary: String?`・`coverageRaw: String?`・`savedAt: Date?`を追加する。`DailyNote`はID、start/end、timeZoneID、day、title/text、createdAt/updatedAtを持つ。`NoteScrap`はkey（ノートID＋記事ID）、noteID/articleID、title/url、summary、coverageRaw、savedAt、memoを持つ。モデルとStoreのSchema／reloadに追加し、Star索引は全描画ごとのSwiftData全件getter登録を避ける。
- [ ] **緑とcommit:** 全テストをfixture指定付きで実行する。追加スキーマの自動更新で保持できなければ、失敗証拠に基づいて実際のV1スキーマ間だけの明示移行を実装・再検証し、その方式と差分を実装PRに記録する。初期化で通さない。`git commit -m "feat: preserve V1 data and add article stars"`。

## Task 2: 原文でも途切れない記事操作

**Interfaces:** UIの`ReaderCommand`は`.next/.previous/.toggleStar/.scrap/.closeOriginal`。`ReaderKeyboardCommands.command(for: NSEvent) -> ReaderCommand?`で文字／修飾キーを判定し、ReaderViewの`perform(_ command: ReaderCommand)`へ集約する。このTaskでは`.scrap`の実行はTask 3接続後に提供し、未接続のボタン・キーを公開しない。

- [ ] **赤:** `OriginalPageTests.movingOriginalTracksSelectedArticle()`でAの原文→Bの原文→URLなしCの読書表示、旧Aの完了callbackが選択B/Cに影響しないことを検証する。`OriginalKeyboardTests.editableFieldsKeepTyping()`は合成HTMLのinput・textarea・select・contenteditable・iframe・IME変換・修飾キーで読書コマンド0件、通常bodyの`j/k/s`で各1件を検証する。
- [ ] **赤の確認:** `--filter 'OriginalPageTests|ReaderSelectionTests|OriginalKeyboardTests'`で新しい原文移動／キーのassertがFAILすることを確認する。trustedなキーの試験は合成ページを表示するテストwindowへのnativeイベントで行い、`dispatchEvent`を成功経路の代用にしない。GUIを動かせない場合は当該実機確認をNOT_RUNと記録する。

```swift
#expect(original.articleID == articleB.id && original.url == urlB)
#expect(commandsInEditableElements.isEmpty)
#expect(commandsFromPageSyntheticEvents.isEmpty)
#expect(commandsFromBodyKeys == [.next, .previous, .toggleStar])
```
- [ ] **実装:** 原文中の選択変更で一律`closeOriginal()`する既存処理を変更し、移動先のURLに追従する。WebKitの独立したcontent worldでkeydownを扱い、trustedな実キー・入力外・変換外だけをコマンドへ渡す。script／handlerは同じ独立worldへ登録し、サイトのscriptや合成イベントからStar・スクラップを呼べないようにする。`OriginalKeyboardTests.pageCannotSendCommands()`でサイトworldからの偽メッセージと合成keydownを送り、実行0件を検証する。通常・iframeの編集判定は各frame内で行い、未知の入力状態は消費しない。native側も対象window・生存中のwebview・選択記事の一致を検査する。
- [ ] **描画の確認:** `onDisplayed`は現在選択・原文非表示・表示内容のarticleID一致の場合だけ既読を記録する。隠れたNSTextViewの遅延callbackを実行しても未読を保つテストを追加する。`s`はTask 1を呼び、原文をreloadせずfocusと位置を保つ。Escと既存`m/b/v`を回帰確認する。
- [ ] **緑とcommit:** 対象テスト・UIビルド。合成ページで原文の`j/k/s/Esc`、文字入力、日本語変換、URLなしfallbackを確認し、`git commit -m "feat: keep reader commands available in original pages"`。

## Task 3: 当日のノートへスクラップ

**Interfaces:** Storeに`scrap(articleID: UUID, at: Date, timeZone: TimeZone) throws -> NoteScrap`、`dailyNote(containing: Date) -> DailyNote?`、`saveDailyNote(id: UUID, text: String, at: Date) throws`、`saveScrapMemo(key: String, memo: String, at: Date) throws`、`deleteDailyNote(id: UUID) throws`、`removeScrap(key: String) throws`を追加する。

- [ ] **赤:** `DailyNotesTests.repeatDoesNotOverwriteMemo()`で同記事を同日に2回保存してkey一致・1件・初回summary/savedAt/memo不変を検証する。`missingOrExpiredSummaryStoresLinksOnly()`で保持期限後／要約なしの記事は空summary＋正しい欠如表示を保存し、抽出本文を代用しない。
- [ ] **境界の赤:** JSTの23:59→翌00:00は別noteID、保存済み期間中のtimezone変更は同noteID、複数の該当期間ではcreatedAtの新しいnoteを選ぶ。`failureLeavesNoPartialNote()`はテスト用の一回だけ失敗する保存フックで新ノート・スクラップの0件と再試行成功を検証する。フックは内部initializerの注入に限り、公開失敗設定を追加しない。
- [ ] **赤の確認:** `--filter DailyNotesTests`で未実装APIまたは境界のassertがFAILすることを確認する。

```swift
#expect(first.key == repeated.key && store.scraps.count == 1)
#expect(repeated.summary == "合成RSS要約" && repeated.memo == "本人のメモ")
#expect(tomorrow.noteID != first.noteID)
#expect(storeAfterFailedSave.dailyNotes.isEmpty && storeAfterFailedSave.scraps.isEmpty)
```
- [ ] **実装:** 現在時刻を含む既存noteを優先し、なければGregorian暦のその日の開始／終了を作る。RSSの保持可否を保存直前に検査し、取得本文を使わず`Article.summary`を独立コピーする。新noteとscrapは一回のsaveで確定し、失敗はrollbackする。削除は当該ノートのscrapだけを削除し、週の採用済み出典へ連鎖させない。
- [ ] **緑とcommit:** 再open・記事期限削除・購読解除後にも保存内容を保持するテストを追加して通す。ReaderViewの`.scrap`に接続し、読書表示／原文で`n`後に記事・focus・位置を維持して完了／失敗を表示する。`git commit -m "feat: collect daily scraps without interrupting reading"`。

## Task 4: 共通3カラムと週の候補

**Interfaces:** `WeeklyCandidate`は`articleID: UUID`、`starredAt: Date?`、`scraps: [NoteScrap]`を持つ。`ReaderStore.weeklyCandidates(in: WeekRange) -> [WeeklyCandidate]`、`adoptScraps(noteID: UUID, scrapKeys: [String]) throws`を追加し、既存`candidates(in:)`は初回既読の履歴として使う。UI `ReaderWorkspaceState`はscope、記事・日次・週ノートの選択とscope別のscroll状態を持つ。

- [ ] **赤:** `WeeklyNotesTests.intentCandidatesUseSavedWeek()`で先週既読・今週Starは今週候補、解除で未採用候補から除外、同記事のStar＋複数scrapは1候補、scrapsはsavedAt昇順で先頭を初期選択。週のstartは含みendは含まない。既読のみは履歴表示に残る。
- [ ] **採用の赤:** `adoptedSummaryOutlivesDailyNote()`は週ノートにsummary/title/url/savedAtをコピーし、日次削除・期限削除・Star解除後も一致する。本人のメモと日次本文は自動コピーしない。同じ記事への再採用で既存出典を上書きしない。`ReaderWorkspaceTests.notesRoundTripRestoresReader()`で選択・scope・一覧top・本文offsetの一致と、日次／週初期選択を検証する。
- [ ] **赤の確認:** `--filter 'WeeklyNotesTests|ReaderWorkspaceTests'`で新候補・往復のassertがFAILすることを確認する。

```swift
#expect(store.weeklyCandidates(in: thisWeek).map(\.articleID) == [article.id])
#expect(candidate.scraps.first?.key == firstScrap.key)
#expect(sourceAfterDailyDeletion.summary == "合成RSS要約")
#expect(restoredSelection == originalSelection && restoredOffset == originalOffset)
```
- [ ] **実装:** 既存週の期間固定と複数週ノートを維持し、availableWeeksにStar／scrapの日時を加える。DailyNotesViewはノート編集／scrapメモ・明示削除を担う。WeeklyNotesViewを中央のノート選択＋右の編集へ分け、week pickerは中央上部へ置く。ReaderViewのNavigationSplitViewを一つだけ残し、左のFeeds／Notes、左上の追加・更新、右上の記事操作を配置する。初回日次は当日（未作成なら空状態）、初回週は前週、以後は選択を記憶する。
- [ ] **緑とcommit:** 対象テスト・UIビルド。日次の編集・削除確認、週への出典採用、別scrapの選択、Notes往復、オフライン再起動を合成DBで確認し、`git commit -m "feat: connect daily scraps to weekly notes in three columns"`。

## Task 5: 保存済み要約を使うAIレビュー

**Interfaces:** Coreに`AIInputSelection: Hashable, Codable, Sendable`の`.article(UUID)/.scrap(String)/.noteSource(String)`を追加する。AISourceへselectionと任意のsavedAtを追加し、既存initializerはarticleを既定値とする。`ReaderStore.aiSources(selections: [AIInputSelection], at: Date) throws -> [AISource]`、`availableInputExpiries(selections: [AIInputSelection], at: Date) throws -> [AIInputSelection: Date]`、`AIPackageReview.build(selections: [AIInputSelection], language: String, at: Date) throws`を追加する。既存articleIDs版はarticle selectionへの変換で維持する。

- [ ] **赤:** `AIPackageTests.savedSummaryIgnoresOriginalExpiry()`は元記事期限後のscrap要約を含めて作成でき、savedAt／RSS snapshotのCoverage／URLを含み、expiresAtが生成＋86,400秒になることを検証する。要約なしscrapは選べる出典として表示しつつ本文なしを明示し、生成対象へ入れない。同記事のarticle＋scrap同時選択はエラーとし、UIで一方だけを選ぶ。
- [ ] **寿命の赤:** articleと保存済み要約の混合では記事の最早期限が上限。元記事削除はscrap-onlyを無効にしないが、参照中scrap自体の削除・変更はレビューを無効にする。採用済みNoteSourceは元scrap削除後も使える。`ClaudeHandoffTests.savedSourcesAndOldMetadataReconcile()`で旧articleIDsだけの一時metadataも従来どおり検査し、新しいsaved sourceは元記事の期限で削除されず24時間で削除される。
- [ ] **赤の確認:** `--filter 'AIPackageTests|ClaudeHandoffTests'`で由来・期限のassertがFAILすることを確認する。

```swift
#expect(savedOnly.expiresAt == at.addingTimeInterval(86_400))
#expect(savedOnly.sources[0].content.coverage == .summaryOnly)
#expect(savedOnly.sources[0].savedAt == scrap.savedAt)
#expect(mixed.expiresAt == articleExpiry)
```
- [ ] **実装:** package内に選択内容の由来・保存日時を出力し、同articleIDの無言重複を防ぐ。HandoffFilesのmetadataに任意のselectionsを追加し、旧metadataはarticleIDsから復元する。`sourceSelections(directory:) throws -> [AIInputSelection]`と`reconcile(directory:validInputExpiries:at:) throws`を追加し、Controllerの清掃は新expiry mapを使う。saved sourceの存在・内容一致とarticle availabilityを区別し、reconcileで期限を延長しない。UIは出典ごとに保存済み要約／保持中記事を選び、全文preview・除外・言語・再生成・コピー・書出し・再試行を維持する。
- [ ] **緑とcommit:** 対象テスト・UIビルド。合成ノートから元記事削除後のTXT・hash・24時間期限を確認する。Claudeの本人送信・アクセス許可は自動化せず、今回の合成連携に必要な範囲だけを確認する。`git commit -m "feat: review saved note sources with independent retention"`。

## Task 6: RSS画像の取込みと容量制限

**Interfaces:** `ParsedFeed`へ任意siteURL/iconURL、`ParsedEntry`へ任意imageURLを既定nilで追加する。Coreの`ReaderImageLoader`はactor、`init(directory: URL, client: any HTTPFetching)`と`image(url: URL, at: Date) async throws -> Data?`を持ち、縮小済みPNG Dataを返す。UIから元URLを直接fetchしない。

- [ ] **赤:** FeedParserTestsでRSS画像enclosure、Media RSSのcontent／thumbnail、Atom画像enclosure、RSS/AtomのHTML本文imgと相対URL／xml:baseを検証する。優先順は画像enclosure→media content→media thumbnail→本文の最初の有効img。feedのsiteURL・Atom icon/logo・RSS channel imageも取り込む。非HTTP(S)・認証情報付きURL・壊れたXMLを拒否し、本文のテキスト抽出を変えない。
- [ ] **取得の赤:** `ReaderImageTests.boundedImagesFailWithoutBlockingText()`で4MiB超レスポンス、20,000,000 pixel超画像、壊れた画像、禁止redirect、キャンセルを扱い、通常画像は最大辺1,200 pixel以下のPNGになることを検証する。ImageIOでdecode前の寸法を検査し、SVG等未対応形式は表示を諦める。
- [ ] **キャッシュの赤:** `diskCacheEvictsAndExpires()`でディスク64MiB、成功cache7日、失敗cache10分、同時取得最大4件と同URLの共有を検証する。LRUで容量を守り、期限／容量超過は取得時と起動時に清掃する。端末内のCacheディレクトリに置き、ノート所有データに含めない。ネットワークはStubURLProtocolによる合成応答だけを使う。
- [ ] **赤の確認:** `--filter 'FeedParserTests|ReaderImageTests'`でmetadata・上限・cacheのassertがFAILすることを確認する。

```swift
#expect(parsed.entries[0].imageURL == URL(string: "https://synthetic.example/image.jpg"))
#expect(max(decodedWidth, decodedHeight) <= 1_200)
#expect(diskBytesAfterCleanup <= 64 * 1_024 * 1_024)
#expect(maximumObservedRequests <= 4)
```
- [ ] **実装:** HTMLの画像URLはPlainFeedText変換前に抽出し、Atom XHTMLのimg属性もXMLのノード情報から取得する。ImageMetadataでURL選択と検査、ReaderImagesでHTTPClientの既存scheme／redirect検査・20秒timeout・byte上限、ImageIO縮小、容量制限を扱う。復号・縮小・ディスクI/OはMainActor外。Storeは利用可能な記事画像metadataを更新し、再受信で期限削除済みの画像を永久保存しない。Faviconはfeed内icon、なければsiteURL（なければfeedのhost）の`/favicon.ico`を候補とし、第三者APIやページ全体の巡回を追加しない。
- [ ] **緑とcommit:** 対象テストとTask 1の保存データ保持テストを通し、`git commit -m "feat: load feed images with bounded local caching"`。

## Task 7: フォルダと画像の読書UI

**Interfaces:** Storeに`folderArticleIDs(folder: String, keeping: UUID?) -> [UUID]`、`folderUnreadCount(folder: String) -> Int`、`moveFeed(id: UUID, toFolder: String) throws`、`renameFolder(from: String, to: String) throws`を追加する。UIのArticleImageViewはloader／URL／表示サイズを受け取り、articleIDまたはURL変更で旧取得をキャンセルする。

- [ ] **赤:** `FolderTests.sharedArticleCountsOnce()`で2購読に属する同記事はフォルダのID・未読数に1回だけ現れる。`movingAndRenamingRetainsSelection()`で移動・同名への変更・最後の購読を移した空フォルダの消滅、購読解除後のノート保持を検証する。名前はtrimし、空は未分類、既存名への改名は統合する。
- [ ] **表示の赤:** NativeArticleListTestsへ遅延Favicon／thumbnail完了・行再利用後の古い画像完了・更新中の並び替えを追加する。rowHeight=96、選択ID・先頭記事と行内offsetが不変で、古い画像が別記事の行へ出ないことを検証する。本文画像の遅延完了でも同記事の記憶位置を動かさない。
- [ ] **赤の確認:** `--filter 'FolderTests|NativeArticleListTests'`で集約・画像後着のassertがFAILすることを確認する。

```swift
#expect(store.folderArticleIDs(folder: "技術", keeping: nil) == [sharedArticle.id])
#expect(store.folderUnreadCount(folder: "技術") == 1)
#expect(table.rowHeight == 96 && selected == selectedBeforeImage)
#expect(abs(offsetAfterImage - offsetBeforeImage) < 1)
```
- [ ] **実装:** 左のフォルダを選択可能にして配下記事を集約し、購読の移動とフォルダ名変更をメニューから提供する。中央はFavicon 18pt、サムネイル56×56ptの固定領域、画像URLなしならサムネイル領域を作らない。URLありで未取得／失敗でも同じ領域を保つ。行を再利用するときは旧画像を消し、完了時にID／URL一致を確認する。
- [ ] **本文の実装:** 右の本文上に利用可能な記事画像の固定領域（高さ180pt）を置く。画像の到着で領域の高さを変えず、画像URLなしなら領域を持たない。Star／スクラップの状態を右上と一覧で一致させ、取得中・失敗・オフラインでもテキスト・キー操作を使えるようにする。画像表示はVoiceOverラベルとReduce Motionを妨げない。
- [ ] **緑とcommit:** 対象テスト・UIビルド。フォルダ整理、画像冷／温cache・失敗・オフラインの実機操作で位置を確認し、`git commit -m "feat: organize feeds and enrich reading with stable images"`。

## Task 8: 統合とDogfooding引継ぎ

**Interfaces:** PRD-01〜11を新しい受入記録へ対応付ける。元の`2026-10-05-v1-acceptance.md`は履歴として保存する。

- [ ] **統合テスト:** fixture生成を再実行し、`FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-v1-store-fixture swift test --scratch-path /private/tmp/feeeder-dogfooding-build`と`git diff --check`。`bash scripts/build-app.sh release`でビルドする。全て終了コード0・失敗0件を確認する。
- [ ] **合成実機:** `.build/Feeeder.app/Contents/MacOS/RSSReader --data-directory /private/tmp/feeeder-dogfooding-demo-20261007 --seed-demo`の専用DBで、`j/k/s/n/v/Esc`・原文入力欄・IME・ノート編集・日次→週・期限後の要約・フォルダ・画像・Notes往復を通す。通常起動による本人DBへのアクセスを行わない。
- [ ] **性能:** 同じrelease条件・合成10,000記事／100購読で100切替×3と30秒スクロールを実行する。画像冷／温cacheを分け、更新開始p95の目標100ms以下と元の78.06／80.62／76.72msを比較する。入力数と統合後の表示標本数を別記し、画像・DB処理による100ms以上のMainActor停止を調べる。未計測を0回と記載しない。
- [ ] **受入記録:** 実行commit、fixture hash、環境、コマンド・終了コード、PRDごとのPASS／FAIL／NOT_RUN／BLOCKEDを記録する。原文復帰位置の絶対差1行以内、VoiceOver、Reduce Motion、参考動画との操作感比較、最低macOS 26.6、実サイト品質、長時間timerなど残る実機項目は実際に確認できたものだけ更新する。本人の最終PdM受入はPR上で記録する。
- [ ] **引継ぎとcommit:** READMEの操作・日次と週の使い方を更新し、Architectureへ実装方式・V1保存データ保持の証拠・画像上限・未検証項目を記録する。実装PRを作成する。`git commit -m "docs: record dogfooding reader acceptance and remaining checks"`。新Releaseの公開は本人の指示を受けて行う。

## Approval and Stop Condition

この計画PRの本人による明示承認またはマージ後に、上記の単独実装へ進む。実装中のAPIの細部はテストで確認し、製品の保存契約・対象範囲を変える必要が出た場合だけ当該差分をPR上でレビューする。

完了は、対象の実装・合成自動テスト・実機記録が揃い、実装PRがレビュー可能な状態になった時点。実機未確認と最終PdM受入を区別し、今回の計画承認を製品受入や配布指示として扱わない。
