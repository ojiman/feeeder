# Unagi Reader アーキテクチャとエージェント実行ハーネス

更新日: 2026-10-10

## 1. 位置づけ

製品要件は[PRD](specification.md)を正とする。本書は現行ベータの実装構成と、変更時に守る技術上の契約を定める。決定の理由は[決定記録](decisions/README.md)、承認履歴はPR、実行結果は検証記録（Git履歴）、今後の作業順は[ロードマップ](roadmap.md)で追う（過去の計画・記録はGit履歴）。検証記録はcommit・環境ごとの証拠であり、本書の記載や過去のPASSを現在の合格証拠に代えない。

## 2. V1の技術構成と保存

| 領域 | 構成 |
|---|---|
| UI | SwiftUIの共通`NavigationSplitView`、記事一覧はAppKitの`NSTableView`、読書本文は`NSTextView`、原文閲覧は`WKWebView` |
| Core | `Sources/ReaderCore`。SwiftDataのモデル・ReaderStore、XMLParserによるRSS/Atom解析、保持・ノート |
| 通信・抽出 | URLSessionで端末から取得。SwiftSoup 2.13.9をexact固定し、`article`、次に`main`の段落を抽出する（`ExtractionQuality`: 短い断片が過半の「ページの部品」は本文としない）。記事を開いたときは取得せず、フィードの本文を出す（決定0033）。抽出は「全文を取得」を押したときと、短いフィード本文の記事を要約へ送るときのAI入力だけ |
| 保存先 | `Application Support/UnagiReader/Reader.store`。通常起動でデモを挿入せず、合成デモは明示的な`--data-directory`と`--seed-demo`で起動 |

OPMLの取り込みは、`OPMLParser`（5MB・2,000件・64階層まで、`<!ENTITY`は拒否）が読み、`ReaderStore.importSubscriptions`が一度の保存で追加し、`OPMLImportFlow`が選択・結果・記事の取得をつなぐ。決定0041。

購読追加は、入力中のURLを`FeedChecker`が確認する（0.8秒の間を置き、編集のたびに前の確認を取り消し、古い答えは使わない。ホストが完成して見えないURLは入力中は送らない）。決定0036。

Backend・アカウント・AI proxyは置かない。入力URLのscheme・redirect先を検証し、XML外部entityを拒否する。抽出HTMLは実行せず読書用データへ変換する。本文抽出のHTTP redirectは追わず、未検査の転送先へ取得を進めない。ログイン・robots・購読制限を回避しない。記事本文とツール出力は未信頼データとして扱う。

### 2.1 保存モデル

保存モデルは、プロトタイプの10モデルから置き換えた（決定0008（Git履歴））。`DailyNote`・`NoteScrap`・`WeeklyPeriod`・`WeeklyNote`・`NoteSource`は削除した。

`ReaderStore.schema`は`Feed`、`Article`、`ContentSnapshot`、`FeedMembership`、`ReaderSettings`、`Note`の6モデル。

**S1の削除と改名（決定0019）。** 学習ゴール・問い（`ThemeQuestion`）・「いまの理解」・起動時の移行は、S1aでモデルとコードから消えた。S1bで保存するエンティティ`Theme`・`ThemeArticle`は`Note`・`NoteArticle`になった（`NoteArticle`は決定0049で削除した）。以前のライブラリは新しいスキーマで開き、購読・記事・既読・Starは残るが、以前のテーマ（名前・ノート・記事の記録）は引き継がない（エンティティ名が変わるため。決定0019の10。テストデータなので許容）。`PreNoteStoreUpgradeTests`が、`52429b4`（決定0019の前）とS1a直後（`ae8aa78`）で作った合成ストアで確かめる（opt-in。`scripts/prepare-v1-store-fixture.sh`と`UNAGI_READER_PRE0019_FIXTURE_DIR`）。

- 記事の同一性・初回受信／既読・Star・購読所属を、期限付き本文snapshot・RSS要約と分ける。`FeedMembership`で複数購読の同一記事を集約する。`Feed.folder`は1階層の文字列で、空フォルダモデルは作らない。
- `Article.starredAt`の非nilを現在のStar状態とし、付与／再付与は現在時刻、解除はnil。受信・本文削除で上書きせず、関心の全操作履歴を記録するイベント基盤は持たない。
- `Note`は本文`text`（既定は空。1つのMarkdownのプレーンテキストで、入力のたびに`saveNote(text:at:)`が入力したままを保存する。長さの上限なし。ノートが無いときの保存は`missingNote`で断り、黙って捨てない）・作成／更新日時を持つ。**アプリのノートは1つ**（決定0049）。`ReaderStore.note`がそれを返し、名前・タイトル・一覧・作成・改名・削除・削除の取り消しは無い。
- **ストアを開くとき（`keepOnlyOneNote(at:)`）**、ノートが複数あれば最後に編集した1つ（`updatedAt`が新しいほう。同時刻ならIDが小さいほう）を残して、ほかを削除する。1つもなければ空のノートを作る。ちょうど1つなら何もしない。保存に失敗したら、開く処理が失敗する（黙って続けない）。記事とノートを結ぶエンティティ`NoteArticle`は、モデルから削除した（記事の記録・「ノートに入っている」印・ノートごとの記事一覧は無い）。旧ストアの`NoteArticle`のテーブルは、新スキーマで開いた時点で消える。

新規ライブラリは空で開始し、プロトタイプ移行は行わない。ベータ間の互換は保証せず、同じ版の保存・再openは保持する。配布済みのbeta.2・beta.3と、置き換え直前のmainの合成ストアは、旧5モデルを外した新スキーマで開けて、購読・記事・既読・Starを保持し、書き込みと再openもできる（検証記録はGit履歴）。このとき旧ノートのデータは、新スキーマで開いた時点でテーブルごと削除され（元に戻せない）、CoreDataが「削除されたモデルのため永続履歴を切り詰める」というログを`error:`として出すが、動作には影響しない。決定0049の前のビルド（`60da7df`。ノート3つと記事の記録3件）の合成ストアも同じで、開くと最後に編集した1つのノートだけが残り、購読・記事・既読・Starは残る（`OneNoteStoreUpgradeTests`。opt-in。`UNAGI_READER_PRE0049_FIXTURE_DIR`。検証記録は[0049-one-note-store](verification/0049-one-note-store.md)）。開けない場合は、実DBを自動削除・再作成せず、本人に相談する。1.0からの互換とCI出荷条件は[PRD §7.1](specification.md#71-10の出荷条件)、理由は[決定0003](decisions/0003-beta-data-compatibility.md)を参照する。open失敗で実DBを自動削除・再作成しない。

### 2.2 変更と失敗からの復旧

保存失敗時は同じModelContainerの新しいModelContextで保存済みデータを読み直す。失敗したcontextの値を表示へ持ち越さず、古いモデル参照を渡されてもIDから現在のモデルを解決する。`needsReload`が立っている間は`reloadIfNeeded()`に成功するまで変更・保存をエラーで止める。ノートの作成と記事の追加など一回の操作を部分確定せず、依頼された変更の失敗を成功扱いにしない。既読・購読・Star・ノート・問い・答え・本文保持を含む変更経路は、保存／再読み込みの失敗注入で検証し、新しい変更経路にも同じ試験を足す。

記事・購読・未読・Star・フォルダの索引を`ReaderStore`で持ち、一覧はモデル全件のgetterを毎描画登録せずID配列を使う。変更成功後に索引と表示を更新する。選択後の遅延取得・描画はIDとgenerationで検査し、別記事や既読状態を変えない。同じ記事も利用者の操作後は本文を自動差替えせず、更新の適用を選べるようにする。

### 2.3 保持と本文書式

本文・RSS要約は初期30日、選択肢7 / 30 / 90 / 365日。未読は初回受信、既読は初回既読を起算点とし、再受信・再表示で延長しない。読取・AIレビュー・起動前に期限を検査し、起動／復帰・稼働中30分ごとに物理削除する。短縮／延長時は旧・新の両方の期限を検査し、期限切れや明示削除済み本文・画像を再受信で復活させない。ノート所有の要約と元記事の期限は分離する。

RSS HTML・Atom XHTML・抽出本文は共通の`ArticleMarkup`で段落テキスト、UTF-16リンク範囲とHTTP(S)リンク先、引用深さへ変換する。fragmentはリンク先では保持し、記事同一性用URLでは除去する。`ContentSnapshot.bodyFormatData`はJSONの任意属性で、保存textと一致する場合だけ使う。情報なし／不一致ならtextへfallbackし、リンク先を推測しない。本文削除ではsnapshotと書式も削除する。ノート・AI入力はテキストとカバー範囲を使う。

## 3. AI（アプリは自前のAIを持たない）

アプリは、AIによる要約・提案・ノートへの書き込み・外部サービスへの送信をしない（決定0049）。ノートのエディタは標準のテキスト欄なので、Apple Intelligenceが使えるMacでは、システムのWriting Toolsが、本人が文字を選んだときだけ働く。アプリは何も足さず、`writingToolsBehavior`も変えない。以前あった端末内の要約（Foundation Models）とClaudeへの受け渡しは、履歴にだけ残る。

### 3.1 Markdownをコピー

ノートを外へ出す入口は、ノートのパネルのヘッダーの「Markdownをコピー」だけである（決定0049）。空白だけのノートでは無効。`ReaderView.copyNote`が、保存済みのノート本文を、整えずに、そのまま`NSPasteboardItem`の文字列として書く（失敗は成功と示さず、エラーを出す）。ファイルを作らず、ほかのアプリを起動せず、通信しない。以前の版がライブラリのフォルダに作った`Handoffs`（ノートのコピー）は、起動時に`LegacyHandoffFolder`が削除する（リンクだった場合は、リンクだけを消す。失敗はアラートで知らせる）。

## 4. AIエージェントによる開発

通常は実装者1名の対話型開発。作業開始・再開、コマンド、完了条件は[AGENTS.md](../AGENTS.md)、固定commitのレビューは[チェックリスト](review-checklist.md)に従う。方針の理由は[決定0002](decisions/0002-single-supervised-writer.md)。以下の4軸は指示・観察の契約であり、指示文だけでOSの隔離を保証しない。

### 4.1 パーミッション

リポジトリ内編集、合成fixtureでのテスト／ビルド、生成した一時ファイルの削除、ローカルcommitは追加確認なしで行う。認証情報の読取、破壊的reset／clean、sudo・sandbox解除、任意の外部script実行、main直接push、未許可の公開・配布は禁止。依存・外部URL・データ移行／削除・push／PR・署名／配布は具体的な対象と差分を確認し、依頼済みの操作は同じ許可を取り直さない。

### 4.2 実行境界

作業はリポジトリと非秘密の専用一時領域、開発ツールの読取りを使う。本人の読書DB・Documents・Downloads・ブラウザprofile・SSH鍵・他repoを入力にしない。`/private/tmp`は共有領域であり隔離境界ではない。プラットフォームのsandboxと承認UIを使い、個人ファイル／Keychain IPCへのOSレベルの到達不能を主張しない。無人worker・常駐broker・VM群・権限サーバーはV1で作らず、Keychain probeも再開しない。

### 4.3 クレデンシャル

テストは合成RSS／HTML・一時DBを使い、許可された公開fixtureにもCookie・Authorization・個人識別queryを含めない。GitHubは依頼の範囲でホストの認証済みツールを使い、token・SSH鍵を直読み・コピー・引数／環境変数で受け渡ししない。Apple ID・証明書・秘密鍵はエージェントに渡さない。

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

[Unagi Reader CI](../.github/workflows/ci.yml)はPR・mainマージ・手動実行を対象に、macOS 26 / Xcode 26.6 / Swift 6.3.3で`regression`と`release`を並列実行する（`release`の条件は下記）。`release`は最も時間がかかるため、PRでは`Package.swift`・`Package.resolved`・`ThirdPartyNotices.md`・`scripts/build-app.sh`・`.github/workflows/*`を変えたときだけ走らせる（mainへのpushと手動実行では毎回走る）。常に走る`check`ジョブが、mainのルールが必須とする唯一のステータスで、文書だけ（`docs/**`・`*.md`）のPRではmacOSのジョブを飛ばして成功し、それ以外では走るべきジョブがすべて成功したときだけ成功する（`scripts/ci-gate.sh`、試験は`scripts/test-ci-gate.sh`）。macOS 27のランナーがまだ無いため、CIが検証するのはビルド下限（26.6）で、サポート下限（27.0）の挙動はローカルのmacOS 27だけで確認する（[決定0007](decisions/0007-support-floor-macos-27.md)）。docs／Markdownのみは自動実行を省略し、Draftのコード変更は実行する。同一PRの旧実行は取消し、main／手動実行は相互に取消さない。必須チェック化する際はdocsのみのPendingを防ぐようpath filterを見直す。

`regression`はCore/UI、同じ版の保存／再open、保存／再読み込み失敗と復旧を検証する。`release`はad hoc署名したアプリを組立て、ZIP再圧縮・展開後に署名を検証する。Developer ID署名・公証・自動Release公開はしない。checkout commit（PRは合成merge commit）・PR head・環境・所要時間・失敗ログをartifactへ7日間保存する。CIに修正Agentは置かない。

ベータ間の保持試験は`UNAGI_READER_V1_FIXTURE_DIR`を指定する手動opt-inで、未指定時だけスキップ、不正fixtureは失敗する。1.0では[PRD §7.1](specification.md#71-10の出荷条件)どおりbaseline・期待値を更新して必須化する。CI成功は実機UX・最終PdM受入の代わりではない。

## 5. 検証の参照先

| 記録 | 用途 |
|---|---|
| Claude技術probe (Git history) | 合成TXT・許可操作・経路の制約（決定0049で削除した機能の記録） |
| 初回V1受入（Git履歴） | 本体ハンドオフ・保持・性能の当時の測定と未検証 |
| Dogfooding受入（Git履歴） | Star・日次／週・画像・保存の改修結果 |
| 読書UI追加受入（Git履歴） | リンク／引用・各カラム・CI障害対応・原文復帰の追加結果 |
| 端末内AIの実測 (Git history) | 利用可否・サイズ・時間・要約の質・失敗（合成データのみ。英語。決定0049で削除した機能の記録） |

実サイトの抽出品質、IME・VoiceOver・OSのReduce Motion、原文復帰の絶対差1行以内、MainActor停止の原因、画像付き1万記事の再計測、短い間隔の連打・通信中操作、長時間の期限／復帰、30日の保持でノートの咀嚼に足りるか、本人の実際のStarでのまとまりの精度と閾値、数百件での提案の速度、Apple Intelligenceが無効な環境での挙動、レンズを具体化した問いの質、保存容量、最終PdM比較は、対象commitと環境の証拠で個別に判定する。未確認を本書の整理でPASSへ変えない。

## 6. 読書UI・画像の実装契約

### 6.1 画面の構成と入力・遷移

`NavigationSplitView`を共通枠とし、Feeds／ノートの選択・スクロール記憶を分けて復元し、ノートごとに最後に開いた面（記事／ノート）も復元する。中央は280〜640pt（初期希望400pt）、読書ペインは最低360pt。一覧は行高108pt（上下の余白14pt、購読元行とタイトルの間6pt、タイトルと要約の間4pt。文字は見出し14pt（semibold）、要約11pt、購読元・公開日時10pt。`NativeArticleList.Metrics`）、上段に購読元・公開日時、下段に2行タイトル・要約・52pt画像。`publishedAt`をMacのロケール／タイムゾーンで表示し、`.distantPast`は「—」、詳細日時はtooltip。既読の文字・画像を抑え、選択時はシステムの選択文字色を使う。画像なしでは本文へ幅を戻す。

左カラムはFeeds（すべての記事・未読・Star）／購読元（フォルダ・購読）の順で、購読元の区画は畳める。左のHide Sidebarは`toolbar(removing: .sidebarToggle)`で除去。追加・更新を`NSTitlebarAccessoryViewController`のleftへ置き、sidebar右端に追随させる。sidebarの非表示・view取り外し時にaccessoryも外す。**原文を開くと、`SidebarFold`（`ReaderCore`の純粋な規則）が決めて`columnVisibility`を`.doubleColumn`にし（ウィンドウ幅によらない）、閉じると（どの閉じ方でも）戻す。原文のすべりと畳みは同じ`withAnimation`（`SidebarFold.motionDuration`＝0.3秒）で動かし、Reduce Motionでは動かさない。畳んでいる間、一覧の見出しは信号機ボタンの右から始める（`ListHeader.leadingInset`）。原文の上部の「×」が閉じる（決定0046・0047）。** 購読のフォルダ指定は`importFeed`で記事と同じ保存に含め、通常更新は所属を保持する。フォルダ切替等で新mountした一覧はwindow接続時にフォーカスを得る。

`OriginalPageState.selectionChanged`は別IDの選択で原文を閉じ、クリック／キーで同じ選択処理と一覧フォーカス復元を使う。原文は記事ID・URLで識別し、マウント時にそのwindowの入力先を原文へ移す。独立したWKContentWorldからのコマンドは実キー入力、入力要素、IME、修飾キー、現在の原文／選択記事を検査する。読み込み表示は原文ヘッダ内に置いてviewport高さを保つ。`Esc`は読書位置へ戻し、Starでは原文の位置・フォーカスを保つ。

上下遷移は再利用するネイティブviewportのlayerへ64pt・0.22秒・ease-outと控えめな透明度変化を`CAAnimationGroup`で適用する。次／前の方向は一覧ID順から求める。同記事の本文更新・画像到着では再生せず、Reduce Motionでは`article-motion`を除去する。原文開閉も上下・0.22秒。読書ツールバーはノート／Star／外部ブラウザ、外観はSettingsで`AppStorage("appearance")`を共有する。

ノートは1つで、記事の一覧のある画面（Feeds・Star・フォルダ・購読元）のどれでも同じノートを開ける（決定0049）。中央は購読元・フォルダと同じ`NSTableView`の一覧のままで、読書面は右にある。ノートは右の読書面の`.inspector`（`NotePanel`。幅は、パネルの内容側に付けた`inspectorColumnWidth`（インスペクタ自身に付けると効かなかった）の最小300・最大640pt、希望は前回の幅`NotePanelWidth`（`UserDefaults`。初回は380。保存時と読み出し時に300〜640へ丸め、壊れた値は380へ戻す）。幅の変化は`NotePanelWidthMemory`が`onGeometryChange`で測り、0.6秒落ち着いたら1回保存する。幅を`ReaderView`の状態にしないのは、ドラッグの1コマごとに画面全体が再描画されて固まったため）として開き、ツールバーのボタン（常に置き、どの画面でも押せる。高さが変わらない）、`⌥⌘I`、`n`キー（編集できる欄に入力していないとき。原文の表示中も）で開閉する。境界のドラッグで畳まれても、次のターンに開き直す（`noteOpenBinding`）。開閉は`ReaderWorkspaceState.noteOpen`で、初めは閉じていて、画面を移っても本人が選んだままになる（メモリ上）。パネルを開いてもキーボードの入力先は取らない（エディタをクリックしたときだけ）。読書の状態（選んだ記事・スクロール記憶）は画面ごとに1つで、開閉の影響を受けない。開閉は`toggleNote`が、`withAnimation`（`SidebarFold.motionDuration`＝0.3秒。Reduce Motionでは動かさない）の中で`noteOpen`と`columnVisibility`を変え、原文と同じ1つの動きにする。サイドバーは`SidebarFold.folded(pageOpen:noteOpen:)`で、原文かノートが開いている間畳む（ノートが開いている間に原文を閉じても戻らない）。一覧は、ノートが開いていて、かつ「一覧」ボタンで出していないとき（`SidebarFold.listFolded(noteOpen:listShown:)`）に畳む。SwiftUIの`NavigationSplitView`は中央の列を畳めない（`detailOnly`でも残り、`canCollapse`はfalse）ので、一覧の列は`ListColumnCollapse`（一覧の背景に置くNSViewRepresentable）が、AppKitの`NSSplitViewItem`を探して`canCollapse`を一時的にtrueにし、同じ0.3秒の`NSAnimationContext`の中で`isCollapsed`を変える。畳む前の一覧の幅を覚え、戻したあとに元の幅へ直す（戻す最初のコマではノートのパネルがまだあり、一覧が最小幅まで狭められるため。50msごとに最大2秒、幅が戻るまで試す）。畳み終えたら、入力先を記事の本文（なければウィンドウの本体）へ移し、`j`/`k`が効くままにして、ノートのエディタに入力先を取らせない。戻し終えたら入力先を一覧へ戻す（ノートに入力中でなければ）。「一覧」ボタンは記事の列の左上（原文の「×」と同じ高さ）に、ノートが開いていて原文が開いていないときだけ出る（`ReaderWorkspaceState.noteListShown`。初めは隠し、アプリを開いている間は選んだまま）。分割ビューの畳みを調べるテストは、ウィンドウが2つ同時に畳むと互いに邪魔をする（片方でサイドバーが畳まれないままになる）ため、`SplitViewFoldTests`の下で順番に実行する。`NotePanel`は、右上にコピーのボタン（Markdownをコピー）、その左に前後の記事ボタン、下に`NoteEditor`を置く（ノートの名前は無いので、パネルにタイトルの行は無い）。コピーのボタンは空白だけのノートでは無効にする。ボタンは`.borderless`で、AppKitのボタンとして押せる。キーの規則は`ReaderKeyboardCommands`が、編集できる`NSTextView`と`NSTextField`だけを文字入力とし、IME変換中と、シート・原文表示中は効かせない。

`NSTextView`はリンク属性・引用の字下げと縦線、末尾一箇所のカバー範囲を描く。クリック時にもURLを検証する。再取得は明示操作で、失敗時も保存本文を保ち結果を示す。

記事一覧（`NativeArticleList`）は、更新で新しい記事が先頭に届いたとき（`ListInsertion.leadingCount`: 新しい並びが「新しい記事＋古い並び」そのもので、20件以下）、一覧が先頭にあり、Reduce Motionでなく、選択が変わっていなければ、`insertRows(withAnimation: [.slideDown, .effectFade])`で入れる。それ以外（初回、削除、並べ替え、途中への挿入、21件以上、スクロール済み）は従来どおり`reloadData`し、見ていた記事の位置を保つ。更新ボタンは`symbolEffect(.rotate)`で矢印を回し、更新中も無効にしない（`FeedRefreshController.refresh`が二重実行を断る）。

色は`AppPalette`（`UnagiReader`）に集める。読む面は`AppPalette.surface`（ダーク#1E1E1E、ライト白。固定値。`textBackgroundColor`はスプリットビューの列の中で振動表現（vibrant）として解決され、少し明るい青みの灰色になるため使わない）の1色で、記事一覧（`NativeArticleList.applySurface`）、記事本文、ノートのエディタとその上部、一覧の上下の帯、ウィンドウ（`containerBackground(for: .window)`）をそろえ、ツールバーの背景は隠す（`toolbarBackgroundVisibility(.hidden)`）。`accent`はライト／ダークで値を持つ落ち着いたオレンジ（ダーク約#E6A366、ライト約#C26624。`systemOrange`は彩度が高く、暗い面で眩しかった）で、`.tint`、未読の点、ノートのリスト記号、空の読書面のアイコンに使う。`selection`は中立の灰色（ダーク白13%、ライト黒9%）。記事一覧は`SoftRow`（`NSTableRowView`）で選択を描き、`isEmphasized`を常にfalseにしてシステムの青（と白抜き文字）に切り替えない。選択行は`interiorBackgroundStyle = .raised`をセルへ伝え、既読でも文字を弱めない。サイドバーの項目はアイコンを`.secondary`、文字を`.primary`の85%にして、システムの青い強調と純白を避ける。

### 6.1.1 ノートのエディタ

ノートのエディタは`NoteTextEditor`（`NSViewRepresentable`、`NSScrollView`内の`NoteTextView`）である。SwiftUIの`TextEditor`は表示属性を付ける手段を持たないため、AppKitを使う。整形は`NoteLineStyle.runs(in:baseOffset:)`（ReaderCore。UTF-16のRange。見出し・リストの行と記号を返す純粋関数）と`NoteEditorStyle`（フォント・色・折り返しのインデント）で、`NSTextStorage`の表示属性だけを変える。文字列は変えず、`NSTextStorageDelegate.didProcessEditing`で編集された段落だけを基本の見た目に戻して付け直す。`hasMarkedText()`の間は何もせず（変換中の文字を乱さない）、確定・取り消し後の`textDidChange`／選択変更で整える。貼り付け・ドロップはプレーンテキストだけ（`readablePasteboardTypes`・`acceptableDragTypes`）。引用符・ダッシュ・文字置換・リンク検出は切る。入力の変更は`textDidChange`で一度だけ`saveNote`へ渡す。外からの文字（要約の送信と取り消し）は`updateNSView`が、文字列が違い、かつ変換中でないときだけ、1回の元に戻せる編集で入れ、選択を範囲内に保ち、保存し直さない。起動時に自分で入力先にならない。

### 6.2 画像

RSS/Atomのenclosure・media・本文画像から選ぶ。`hatena:imageurl`はnamespace URIと位置を検査して優先し、HTMLでは`entry-image`を優先する。`cite`内・favicon・はてブ件数／追加ボタン・明示的に小さい画像は候補から除く。完全な意味分類・原文からの画像探索は保証せず、第三者favicon APIへ購読URLを送らない。

取得・検査・ImageIO縮小・ディスクI/Oはactorで行い、MainActorを塞がない。scheme・redirect検査を使い、表示対象を優先する。購読アイコンも同じactor／キャッシュを使う。

| 制約 | 値 |
|---|---|
| レスポンス／復号前pixels／縮小後最大辺 | 4MiB / 20,000,000 / 1,200px |
| ディスクキャッシュ／成功TTL／失敗TTL／同時取得 | 64MiB / 7日 / 10分 / 4件 |
| 固定表示枠 | favicon 18pt、記事一覧52pt、読書画像領域180pt |

完了時はID・URL一致とキャンセルを検査する。画像の後着・失敗・オフラインで行高・選択・読書位置を変えない。本文内NSHostingViewは固定frameとし、intrinsic-sizeによる周囲の組版変更を無効にする。ノート所有の永久画像にはしない。
