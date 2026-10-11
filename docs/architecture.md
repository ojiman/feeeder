# Feeeder アーキテクチャとエージェント実行ハーネス

更新日: 2026-10-10

## 1. 位置づけ

製品要件は[PRD](specification.md)を正とする。本書は現行ベータの実装構成と、変更時に守る技術上の契約を定める。決定の理由は[決定記録](decisions/README.md)、承認履歴はPR、実行結果は検証記録（Git履歴）、今後の作業順は[ロードマップ](roadmap.md)で追う（過去の計画・記録はGit履歴）。検証記録はcommit・環境ごとの証拠であり、本書の記載や過去のPASSを現在の合格証拠に代えない。

## 2. V1の技術構成と保存

| 領域 | 構成 |
|---|---|
| UI | SwiftUIの共通`NavigationSplitView`、記事一覧はAppKitの`NSTableView`、読書本文は`NSTextView`、原文閲覧は`WKWebView` |
| Core | `Sources/ReaderCore`。SwiftDataのモデル・ReaderStore、XMLParserによるRSS/Atom解析、保持・ノート・端末内AI・Claudeハンドオフ |
| 通信・抽出 | URLSessionで端末から取得。SwiftSoup 2.13.9をexact固定し、`article`、次に`main`の段落を抽出。best effortでRSS要約へfallbackする |
| 保存先 | `Application Support/Feeeder/Reader.store`。通常起動でデモを挿入せず、合成デモは明示的な`--data-directory`と`--seed-demo`で起動 |

Backend・アカウント・AI proxyは置かない。入力URLのscheme・redirect先を検証し、XML外部entityを拒否する。抽出HTMLは実行せず読書用データへ変換する。本文抽出のHTTP redirectは追わず、未検査の転送先へ取得を進めない。ログイン・robots・購読制限を回避しない。記事本文とツール出力は未信頼データとして扱う。

### 2.1 保存モデル

保存モデルは、現行ベータの10モデルから次の8モデルへ置き換える（決定0008（Git履歴））。置き換えは完了し、`DailyNote`・`NoteScrap`・`WeeklyPeriod`・`WeeklyNote`・`NoteSource`は削除した。

`ReaderStore.schema`は`Feed`、`Article`、`ContentSnapshot`、`FeedMembership`、`ReaderSettings`、`Note`、`NoteArticle`の7モデル。

**S1の削除と改名（決定0019）。** 学習ゴール・問い（`ThemeQuestion`）・「いまの理解」・起動時の移行は、S1aでモデルとコードから消えた。S1bで保存するエンティティ`Theme`・`ThemeArticle`は`Note`・`NoteArticle`になった。以前のライブラリは新しいスキーマで開き、購読・記事・既読・Starは残るが、以前のテーマ（名前・ノート・記事の記録）は引き継がない（エンティティ名が変わるため。決定0019の10。テストデータなので許容）。`PreNoteStoreUpgradeTests`が、`52429b4`（決定0019の前）とS1a直後（`ae8aa78`）で作った合成ストアで確かめる（opt-in。`scripts/prepare-v1-store-fixture.sh`と`FEEEDER_PRE0019_FIXTURE_DIR`）。

- 記事の同一性・初回受信／既読・Star・購読所属を、期限付き本文snapshot・RSS要約と分ける。`FeedMembership`で複数購読の同一記事を集約する。`Feed.folder`は1階層の文字列で、空フォルダモデルは作らない。
- `Article.starredAt`の非nilを現在のStar状態とし、付与／再付与は現在時刻、解除はnil。受信・本文削除で上書きせず、関心の全操作履歴を記録するイベント基盤は持たない。
- `Note`は本文`text`（既定は空。1つのMarkdownのプレーンテキストで、入力のたびに`saveNote(noteID:text:at:)`が入力したままを保存する。長さの上限なし。存在しないノートへの保存は`missingNote`で断り、黙って捨てない）・作成／更新日時を持つ。別の名前は持たず、タイトルは本文の最初の空でない行（`NoteTitle.make`。先頭の`#`と空白を除く。空なら「新規ノート」）。`createNote(text:at:)`は空のノートを作る。`updatedAt`は、ノートの中の変更（記事の追加・取り外し、本文）のたびに更新する。サイドバーの並び（`notesNewestEditFirst`）は更新が新しい順で、同じ時刻はIDで固定する。
- `NoteArticle`はノートIDと記事IDの組で一意（多対多）。追加日時と、追加時点のタイトル・原文URL・保持していたRSS要約を所有する（`NoteScrap`と同じ。再取得で元記事のタイトルやURLが変わっても、ノートの記録は変わらない）。要約は読書表示と同じテキスト化を使い、抽出全文で置換しない。再追加は既存の記録を返し、日時・内容を変えない。元記事の本文期限で`Article.summary`が消えても、購読を解除しても、記録は残る。
- 端末内AIの有効／無効は`AppStorage`で持ち、スキーマを増やさない。AIの中間結果は保存しない。

新規ライブラリは空で開始し、プロトタイプ移行は行わない。ベータ間の互換は保証せず、同じ版の保存・再openは保持する。配布済みのbeta.2・beta.3と、置き換え直前のmainの合成ストアは、旧5モデルを外した新スキーマで開けて、購読・記事・既読・Starを保持し、書き込みと再openもできる（検証記録はGit履歴）。このとき旧ノートのデータは、新スキーマで開いた時点でテーブルごと削除され（元に戻せない）、CoreDataが「削除されたモデルのため永続履歴を切り詰める」というログを`error:`として出すが、動作には影響しない。開けない場合は、実DBを自動削除・再作成せず、本人に相談する。1.0からの互換とCI出荷条件は[PRD §7.1](specification.md#71-10の出荷条件)、理由は[決定0003](decisions/0003-beta-data-compatibility.md)を参照する。open失敗で実DBを自動削除・再作成しない。

### 2.2 変更と失敗からの復旧

保存失敗時は同じModelContainerの新しいModelContextで保存済みデータを読み直す。失敗したcontextの値を表示へ持ち越さず、古いモデル参照を渡されてもIDから現在のモデルを解決する。`needsReload`が立っている間は`reloadIfNeeded()`に成功するまで変更・保存をエラーで止める。ノートの作成と記事の追加など一回の操作を部分確定せず、依頼された変更の失敗を成功扱いにしない。既読・購読・Star・ノート・問い・答え・本文保持を含む変更経路は、保存／再読み込みの失敗注入で検証し、新しい変更経路にも同じ試験を足す。

記事・購読・未読・Star・フォルダの索引を`ReaderStore`で持ち、一覧はモデル全件のgetterを毎描画登録せずID配列を使う。変更成功後に索引と表示を更新する。選択後の遅延取得・描画はIDとgenerationで検査し、別記事や既読状態を変えない。同じ記事も利用者の操作後は本文を自動差替えせず、更新の適用を選べるようにする。

### 2.3 保持と本文書式

本文・RSS要約は初期30日、選択肢7 / 30 / 90 / 365日。未読は初回受信、既読は初回既読を起算点とし、再受信・再表示で延長しない。読取・AIレビュー・起動前に期限を検査し、起動／復帰・稼働中30分ごとに物理削除する。短縮／延長時は旧・新の両方の期限を検査し、期限切れや明示削除済み本文・画像を再受信で復活させない。ノート所有の要約と元記事の期限は分離する。

RSS HTML・Atom XHTML・抽出本文は共通の`ArticleMarkup`で段落テキスト、UTF-16リンク範囲とHTTP(S)リンク先、引用深さへ変換する。fragmentはリンク先では保持し、記事同一性用URLでは除去する。`ContentSnapshot.bodyFormatData`はJSONの任意属性で、保存textと一致する場合だけ使う。情報なし／不一致ならtextへfallbackし、リンク先を推測しない。本文削除ではsnapshotと書式も削除する。ノート・AI入力はテキストとカバー範囲を使う。

## 3. AI（端末内の提案とClaudeハンドオフ）

### 3.1 端末内AI

`TextGenerator`プロトコル（ReaderCore、非同期・`Sendable`。`generationAvailability()`と`generate(_: TextRequest)`）が、端末内のモデルへのプレーンテキストの依頼を表す。実物はアプリ側の`FoundationModelsGenerator`（`LanguageModelSession`のプレーンテキストと`maximumResponseTokens`。資産の取得要求を起こさない）で、テストは偽の実装（`FakeGenerator`）で行う。実物の出力の質は環境つきの検証記録で扱い、CIでは検証しない。原則は[決定0009](decisions/0009-on-device-ai-principles.md)、実測は[端末内AIの実測](verification/on-device-ai-findings.md)に従う。

- **記事の要約（段階S2で画面につなぐ）**: `ArticleSummaryPrompt`が、記事の保持中の本文の先頭3,000文字（`Character`単位で切り、絵文字や結合文字を割らない。約2,200トークン）とタイトルから、3文以内の要約を求める固定の指示と、出力上限400トークンの依頼を作る。`ArticleSummaryModel`（`@MainActor`）は`TextGenerator`を使い、押されたときだけ1件を要求する。AI設定が切れていれば呼ばず、依頼時と応答時の両方で設定を読み直す。20秒の期限（`withDeadline`）、取消、要求トークンによる古い応答の破棄を持ち、失敗・空・時間切れは`failed`、本文なしは`unavailable(.noText)`。ストアには何も書かない。`NoteInsertion.adopted`（純粋なテキスト規則）は、要約を出典行つきで独立した段落としてノートの文字列へ入れる。S1aでは、これらはまだ画面から呼ばれない。
- **入力量**: コンテキスト窓は4096トークン（入出力の合計）。要約は先頭を切り詰める。
- **利用可否**: `SystemLanguageModel.default.availability`を検査する。資産が無い場合に、アプリが自動で取得要求（通信）を起こさない。利用不可・ガードレールの誤検知・上限超過・取消は「テキストなし」として扱い、操作を止めない。
- **設定**: 端末内AIの有効／無効を持つ（Settingsの「端末内AI」。状態の表示つき）。既定は有効。無効のときはモデルを呼ばない。

### 3.2 Claudeハンドオフ

ノートからのレビューで、ノートに記録した要約（`noteArticle`）と保持中の記事（`article`）を`AIInputSelection`で区別して選び、ノートを含めるかも選ぶ。同じ記事の両方を無言で重複入力せず、実際に選択した内容・出典URL・カバー範囲・保存日時・出力言語・依頼文を不変のパッケージとSHA-256へまとめる。入口はノート画面のツールバーのボタン。N2以降、ノートの問い・答えはない。N6から、ノートも本人が選べば渡せる。決定0019でゴールは無くなった（下記）。

**Note content (PR 8, reworked by N6).** A package can carry an `AINoteContext` (the note's id and text when the person includes it; nil when not included. There is no title line: the title is the first line of the text). It appears in the text between `BEGIN_NOTE` and `END_NOTE` under the label `Note (written by the user):`. When the note is included the package header is the review request (the note itself, quoting the note for what is achieved, naming a gap only from what the note does not say, the sources' weak support and opposing views, and what to read or write next); otherwise it is the request for the sources. `AINoteRequest(noteID:includeNote:)` says what is included, and `ReaderStore.aiNoteContext` builds the context (empty text counts as not included, and nil is returned when nothing is included). The person's words and article text are data: marker-like lines inside them are kept as they are. A package needs an article source unless it carries the note; one without sources expires after 24 hours (`AIPackageReview` and `HandoffFiles.reconcile` use the package's own expiry when there is no article expiry). `AIPackageReview.reconcile` rebuilds the context from the store and marks the review `changed` if it is not equal to the one that was reviewed (so editing the included note invalidates it; editing something that was not included does not). A managed copy's metadata records `noteID` for every package made from a note (`questionIDs` is only read for copies written before notes replaced questions, and is never written now). The copy is deleted when the note or an included source article is gone or no longer in the note; the cleanup is started through `onContentPolicyChanged` even if the reload after a deletion fails, but it reads the current sources, so while the reload keeps failing the copy stays and the maintenance error is shown. It is removed once a reload succeeds or at its 24 hours (this part predates N6). Editing the note does not delete a copy: it is a snapshot, and its 24-hour limit still applies. The review screen's switches come from `HandoffDefaults` (a pure rule: the toolbar entry leaves the note off, the note panel's button switches the note on, an empty one is off and disabled). Decision 0018 (Git history), [0012](decisions/0012-claude-handoff-from-themes.md).

`ClaudeLink`は[公式案内](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link)にある`claude://cowork/new`の`q`へ短い依頼文、`file`へ生成TXTの絶対パスをURLエンコードして渡す。本文はUTF-8 TXT内に置き、起動URLへ詰め込まない（`q`は約14,000文字で切り詰められる）。通常Chatが利用者の希望だが、自動添付は未検証のため現行経路はCowork。通常Chat用の起動リンクに未文書化のファイル添付パラメータがあるとは仮定せず、推測したパラメータを実装しない。起動処理とパッケージ生成は分離する。

- `HandoffFiles`は操作UUIDごとの専用フォルダ（0700）にTXT・管理metadata（0600）だけを置く。起動前に存在・通常ファイル・読取り・期限・レビュー済みbytesとの一致を検査し、不在／改変ファイルで起動しない。
- 管理コピーは生成24時間と、含む記事本文の最早期限の小さい方で失効する。ノートに記録した要約だけなら生成24時間。保持短縮・本文削除・次のコピー期限・起動／復帰で同期し、期限を延長しない。
- 起動成功で即削除しない。起動後にClaudeが読むため、起動／カード表示だけで添付・読取り成功としない。失敗・取消後は同じレビュー済み内容で再試行できる。
- 全文コピー・TXT書き出し・UTF-8の全bytesを保つ1MiB/part以下の分割を提供する。分割値はClaudeの公称上限ではない。本人の書き出し先とClaude側の内容は削除同期の対象外。
- Attach・送信・必要な親フォルダ許可は本人が操作する。フォルダ許可は読取り・変更を可能にし、cloudで使われる内容は端末を離れる旨を案内する。リンク由来の警告が出る場合がある。APIキー・自動送信・返答の自動書込みは使わない。

検証対象はClaude Desktop 2.19675.0 / Pro / Cowork。起動・添付・読取りの条件と結果は[技術probe](verification/2026-10-04-claude-desktop-handoff.md)と本体受入（Git履歴）で区別する。通常Chat自動添付、他版・他プラン、大容量TXTのClaude側読取りを確認済みと扱わない。

## 4. AIエージェントによる開発

通常は実装者1名の対話型開発。作業開始・再開、コマンド、完了条件は[AGENTS.md](../AGENTS.md)、固定commitのレビューは[チェックリスト](review-checklist.md)に従う。方針の理由は[決定0002](decisions/0002-single-supervised-writer.md)。以下の4軸は指示・観察の契約であり、指示文だけでOSの隔離を保証しない。

### 4.1 パーミッション

リポジトリ内編集、合成fixtureでのテスト／ビルド、生成した一時ファイルの削除、ローカルcommitは追加確認なしで行う。認証情報の読取、破壊的reset／clean、sudo・sandbox解除、任意の外部script実行、main直接push、未許可の公開・配布は禁止。依存・外部URL・データ移行／削除・push／PR・署名／配布は具体的な対象と差分を確認し、依頼済みの操作は同じ許可を取り直さない。

### 4.2 実行境界

作業はリポジトリと非秘密の専用一時領域、開発ツールの読取りを使う。本人の読書DB・Documents・Downloads・ブラウザprofile・SSH鍵・他repoを入力にしない。`/private/tmp`は共有領域であり隔離境界ではない。プラットフォームのsandboxと承認UIを使い、個人ファイル／Keychain IPCへのOSレベルの到達不能を主張しない。無人worker・常駐broker・VM群・権限サーバーはV1で作らず、Keychain probeも再開しない。

### 4.3 クレデンシャル

テストは合成RSS／HTML・一時DBを使い、許可された公開fixtureにもCookie・Authorization・個人識別queryを含めない。Claudeは本人の確認・送信でAPIキー不要。GitHubは依頼の範囲でホストの認証済みツールを使い、token・SSH鍵を直読み・コピー・引数／環境変数で受け渡ししない。Apple ID・証明書・秘密鍵はエージェントに渡さない。

### 4.4 オーケストレーション

同時writerは1名、サブエージェントを常用しない。保存モデル・並行処理・外部書込みなど危険な変更は固定commitの独立レビューを行う。同じ作業コピーを編集できるレビュー者を「隔離された読取専用検証」と呼ばず、子エージェントに全会話・本人データ・認証情報を渡さない。PdMの実機受入はコードレビューと別に行う。

### 4.5 ハーネスの受け入れ条件

製品受入とは別に、対象commit、コマンドと終了コード、差分、fixture、実行環境に結び付けて`PASS / FAIL / NOT_RUN / BLOCKED`を記録する。必要な証拠がなければNOT_RUN。

| ID | 軸 | 合格条件 |
|---|---|---|
| H-P01 | パーミッション | diff check成功、差分pathが対象内。外部書込みは依頼された宛先・操作と一致し、main直接pushなし |
| H-B01 | 実行境界 | 実効profileの書込root・通信設定を記録し、生成物は作業コピー／専用一時領域内。包括的sandbox解除・無人worker起動なし。profileを読めなければNOT_RUN |
| H-C01 | クレデンシャル | 入力は合成／許可済み公開fixture。credentialの直読み・受渡し・Keychain probeなし。OSレベルの到達不能を証明したとはしない |
| H-O01 | オーケストレーション | 同時writerは1名以下。テスト対象commit／作業tree hashがレビュー対象と一致し、変更後に古い結果を採用しない。成功または未実行理由を記録 |

将来BYOK／無人実行を採用する際は、鍵の保管・代理実行・隔離環境とファイル／通信／Keychain境界の否定試験を別途設計する。この対話型ハーネスを隔離の証明に流用せず、将来用の基盤づくりでV1を止めない。

### 4.6 CI

[Feeeder CI](../.github/workflows/ci.yml)はPR・mainマージ・手動実行を対象に、macOS 26 / Xcode 26.6 / Swift 6.3.3で`regression`と`release`を並列実行する（`release`の条件は下記）。`release`は最も時間がかかるため、PRでは`Package.swift`・`Package.resolved`・`ThirdPartyNotices.md`・`scripts/build-app.sh`・`.github/workflows/*`を変えたときだけ走らせる（mainへのpushと手動実行では毎回走る）。常に走る`check`ジョブが、mainのルールが必須とする唯一のステータスで、文書だけ（`docs/**`・`*.md`）のPRではmacOSのジョブを飛ばして成功し、それ以外では走るべきジョブがすべて成功したときだけ成功する（`scripts/ci-gate.sh`、試験は`scripts/test-ci-gate.sh`）。macOS 27のランナーがまだ無いため、CIが検証するのはビルド下限（26.6）で、サポート下限（27.0）の挙動はローカルのmacOS 27だけで確認する（[決定0007](decisions/0007-support-floor-macos-27.md)）。docs／Markdownのみは自動実行を省略し、Draftのコード変更は実行する。同一PRの旧実行は取消し、main／手動実行は相互に取消さない。必須チェック化する際はdocsのみのPendingを防ぐようpath filterを見直す。

`regression`はCore/UI、同じ版の保存／再open、保存／再読み込み失敗と復旧を検証する。`release`はad hoc署名したアプリを組立て、ZIP再圧縮・展開後に署名を検証する。Developer ID署名・公証・自動Release公開はしない。checkout commit（PRは合成merge commit）・PR head・環境・所要時間・失敗ログをartifactへ7日間保存する。CIに修正Agentは置かない。

ベータ間の保持試験は`FEEEDER_V1_FIXTURE_DIR`を指定する手動opt-inで、未指定時だけスキップ、不正fixtureは失敗する。1.0では[PRD §7.1](specification.md#71-10の出荷条件)どおりbaseline・期待値を更新して必須化する。CI成功は実機UX・最終PdM受入の代わりではない。

## 5. 検証の参照先

| 記録 | 用途 |
|---|---|
| [Claude技術probe](verification/2026-10-04-claude-desktop-handoff.md) | 合成TXT・許可操作・経路の制約 |
| 初回V1受入（Git履歴） | 本体ハンドオフ・保持・性能の当時の測定と未検証 |
| Dogfooding受入（Git履歴） | Star・日次／週・画像・保存の改修結果 |
| 読書UI追加受入（Git履歴） | リンク／引用・各カラム・CI障害対応・原文復帰の追加結果 |
| [端末内AIの実測](verification/on-device-ai-findings.md) | 利用可否・サイズ・時間・要約の質・失敗（合成データのみ。英語） |

実サイトの抽出品質、IME・VoiceOver・OSのReduce Motion、原文復帰の絶対差1行以内、MainActor停止の原因、画像付き1万記事の再計測、短い間隔の連打・通信中操作、長時間の期限／復帰、30日の保持でノートの咀嚼に足りるか、本人の実際のStarでのまとまりの精度と閾値、数百件での提案の速度、Apple Intelligenceが無効な環境での挙動、レンズを具体化した問いの質、保存容量、最終PdM比較は、対象commitと環境の証拠で個別に判定する。未確認を本書の整理でPASSへ変えない。

## 6. 読書UI・画像の実装契約

### 6.1 3カラムと入力・遷移

`NavigationSplitView`を共通枠とし、Feeds／ノートの選択・スクロール記憶を分けて復元し、ノートごとに最後に開いた面（記事／ノート）も復元する。中央は280〜640pt（初期希望400pt）、読書ペインは最低360pt。一覧は行高96pt、上段に購読元・公開日時、下段に2行タイトル・要約・52pt画像。`publishedAt`をMacのロケール／タイムゾーンで表示し、`.distantPast`は「—」、詳細日時はtooltip。既読の文字・画像を抑え、選択時はシステムの選択文字色を使う。画像なしでは本文へ幅を戻す。

左カラムはFeeds（すべての記事・未読・Star）／ノート（各ノート）／購読元（フォルダ・購読）の順で、購読元の区画は畳める。左のHide Sidebarは`toolbar(removing: .sidebarToggle)`で除去。追加・更新を`NSTitlebarAccessoryViewController`のleftへ置き、sidebar右端に追随させる。sidebarの非表示・view取り外し時にaccessoryも外すが、**原文開閉ではcolumnVisibilityを変更せず、装着・列幅を維持する。** 購読のフォルダ指定は`importFeed`で記事と同じ保存に含め、通常更新は所属を保持する。フォルダ切替等で新mountした一覧はwindow接続時にフォーカスを得る。

`OriginalPageState.selectionChanged`は別IDの選択で原文を閉じ、クリック／キーで同じ選択処理と一覧フォーカス復元を使う。原文は記事ID・URLで識別し、マウント時にそのwindowの入力先を原文へ移す。独立したWKContentWorldからのコマンドは実キー入力、入力要素、IME、修飾キー、現在の原文／選択記事を検査する。読み込み表示は原文ヘッダ内に置いてviewport高さを保つ。`Esc`は読書位置へ戻し、Star／ノートへの追加では原文の位置・フォーカスを保つ。ノート／問いのview識別子も選択IDに合わせ、編集・作成先を古いノートや問いに残さない。

上下遷移は再利用するネイティブviewportのlayerへ64pt・0.22秒・ease-outと控えめな透明度変化を`CAAnimationGroup`で適用する。次／前の方向は一覧ID順から求める。同記事の本文更新・画像到着では再生せず、Reduce Motionでは`article-motion`を除去する。原文開閉も上下・0.22秒。読書ツールバーはStar／ノート／外部ブラウザ、AIの入口はノート、外観はSettingsで`AppStorage("appearance")`を共有する。

ノートを選んでも、中央は購読元・フォルダと同じ`NSTableView`の一覧のままで、読書面は右にある。ノートは右の読書面の`.inspector`（`NotePanel`。幅は`inspectorColumnWidth`の最小300・最大640pt、希望は前回の幅`NotePanelWidth`（`UserDefaults`。初回は380。保存時と読み出し時に300〜640へ丸め、壊れた値は380へ戻す）。幅の変化は`onGeometryChange`で測り、0.6秒落ち着いたら1回保存する）として開き、ツールバーのボタン（常に置き、ノートの外では押せない。高さが変わらない）と`⌥⌘I`で開閉する。開閉は`ReaderWorkspaceState.isNoteOpen(of:)`で、**ノートを選ぶと初めから開き**、本人が閉じたノートだけがアプリを開いている間は閉じたままになる（メモリ上）。パネルを開いてもキーボードの入力先は取らない（エディタをクリックしたときだけ）。読書の状態（選んだ記事・スクロール記憶）はノートごとに1つで、開閉の影響を受けない。サイドバーは`NoteLayout`（純粋な値）が決める。パネルを開くとき、ウィンドウの幅が`foldBelow`（1,300pt。実機の1,240pt幅で、サイドバー約217・一覧約393・読書約361を取り、パネルが約270に縮んだ測定から決めた仮の値）より狭いときだけ畳み、閉じると戻す。開いている間は、リサイズで同じ規則に従って畳み・戻し、本人が手で切り替えたら、その選択をパネルを閉じるまで保つ。`SidebarColumns`を`NavigationSplitViewVisibility`へ写す。戻すボタンは記事一覧の上の細い帯の左（ノートが開いている間だけ。ツールバーではない）。`NotePanel`は、上から、「Claudeでレビューを頼む」・前後の記事のボタン（`⌥⌘↑`・`⌥⌘↓`のキー等価。変換中とノート選択中は動かさない。端の規則は`NoteArticleSwitcher`）、エディタ（`NoteEditor`）を置く（ノートの名前は無いので、パネルにタイトルの行は無い）。ボタンは`.borderless`で、AppKitのボタンとして押せる。キーの規則は`ReaderKeyboardCommands`が、編集できる`NSTextView`と`NSTextField`だけを文字入力とし、IME変換中と、シート・原文表示中は効かせない。`t`とツールバーのアイコンは同じ選択ポップオーバー（既存ノート・新しいノート。S2まで残る。新しいノートは、入力した名前を最初の行の見出し`# 名前`にして作る）を開き、テキスト入力・IME変換・修飾キーを優先する既存の規則に従う。サイドバーの「新しいノート」は、空のノートを作ってすぐ選ぶ。ドラッグ&ドロップは候補で必須ではない。

`NSTextView`はリンク属性・引用の字下げと縦線、末尾一箇所のカバー範囲を描く。クリック時にもURLを検証する。再取得は明示操作で、失敗時も保存本文を保ち結果を示す。

### 6.2 画像

RSS/Atomのenclosure・media・本文画像から選ぶ。`hatena:imageurl`はnamespace URIと位置を検査して優先し、HTMLでは`entry-image`を優先する。`cite`内・favicon・はてブ件数／追加ボタン・明示的に小さい画像は候補から除く。完全な意味分類・原文からの画像探索は保証せず、第三者favicon APIへ購読URLを送らない。

取得・検査・ImageIO縮小・ディスクI/Oはactorで行い、MainActorを塞がない。scheme・redirect検査を使い、表示対象を優先する。購読アイコンも同じactor／キャッシュを使う。

| 制約 | 値 |
|---|---|
| レスポンス／復号前pixels／縮小後最大辺 | 4MiB / 20,000,000 / 1,200px |
| ディスクキャッシュ／成功TTL／失敗TTL／同時取得 | 64MiB / 7日 / 10分 / 4件 |
| 固定表示枠 | favicon 18pt、記事一覧52pt、読書画像領域180pt |

完了時はID・URL一致とキャンセルを検査する。画像の後着・失敗・オフラインで行高・選択・読書位置を変えない。本文内NSHostingViewは固定frameとし、intrinsic-sizeによる周囲の組版変更を無効にする。ノート所有の永久画像にはしない。
