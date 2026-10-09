# Settings メニュードラフトのフィジビリティ検証

更新日: 2026-10-10（日本時間）。状態: 設計判断のための検証、製品受入・仕様承認ではない。

対象: [Settingsドラフト](../superpowers/specs/2026-10-10-settings-draft.md)。製品コード・保存モデル・依存・正式PRD/Architectureは変更していない。固定commitの一時コピーへ設定値化パッチと合成試験を追加した。

## 結論と判断理由

**本文の設定値化は小さな変更で実現できる。5カテゴリは内容描画まで確認。ノートの文字サイズは合成部品で成立したが、製品エディタと実IMEの受入は残る。**

- 本文: 実際の`ArticleTextView.install()`と`setFrameSize()`を設定値化し、文字サイズ・通常段落と引用の行間・幅上限・左右余白を108通り確認した。設定を無視する対照で試験が失敗することも確認した。ただしSettingsからの通知・呼出側・保存・既読化副作用のない更新は未接続。
- ノート: ネイティブのfont変更と、SwiftUIのBinding同期を切り分けた。同期した合成変換中テキストはfont変更後も保持された。**前回の「即時反映では変換中テキストを保持できない」という診断と「編集中は反映を保留する」という推奨を撤回する。** 実際の日本語IMEとSettings sceneで反映方式を判断する。
- 読書位置: 実ウィンドウ上のスクロール領域で、段落内に収まる縦位置を確認して測った。同じ段落/80ptでも、幅変更で先頭文字が92 UTF-16 code unit移動した。現行方式で同じ文字へ戻れるとは言えない。文字基準の方式は未実装・未検証。本文設定の採用と位置保持の精度を別の判断にする。
- AI: この端末のAPI利用可否を読んだだけ。仮のUserDefaultsキーを保存しても製品のAI無効化を証明できないため、そのPASSを削除した。呼出抑止と遅延応答破棄は機能開発との合流で確認する。

既存の`Settings`・`AppStorage`・`ReaderStore`を使う方針は妥当。独立した設定基盤、新しい保存モデル、依存の追加を必要とする根拠はない。これらは構成の判断であり、完成したSettings統合の証拠ではない。

## 基準と環境

| 項目 | 値 |
|---|---|
| 固定した製品ソース | `e9bcd933873fe920fc3751ba417afe561ff2a99c`（問い・レンズ・答え・根拠の実装） |
| 作業ブランチ | `codex/settings-feasibility`、Draft PR #28 |
| レビュー時のmain | `19f6f05`。追加分はAI計画の文書で、今回の製品ソースは変わらない |
| OS | macOS 27.0.1、build 26A434、Apple Silicon |
| Xcode / Swift | Xcode 27.0（27A266a）/ Swift 6.4（swiftlang-6.4.0.34.1） |
| SDK | macOS 27 SDK。macOS 26 SDK / Swift 6.3.3の確認ではない |
| 入力と保存 | 合成した日英文章・絵文字・架空リンク。UUID専用UserDefaults suiteは試験後にそのsuiteだけ削除 |
| 外部操作 | 認証済みGitHub経由で非公開リポジトリのmainとレビューを取得、PRを更新。推論・資産取得・Claude起動・記事取得なし |

確認した構成は`ReaderSettingsView`、`RSSReaderApp`、`NativeArticleText`、`UnderstandingEditor`、`QuestionEditor`、`ContentRetention`とPRD/Architecture・決定0008/0009。別AIの開発へ変更を加えず、このPRは文書と検証資材に限る。

## 方法と結果

PASSは下記の表明範囲だけを指す。実装統合と製品受入を含めない。

| 項目 | 結果 | 確認した経路・限界 |
|---|---|---|
| 固定commitの既存関連試験 | PASS（初回実行） | UI17件/3 suite、Core6件/1 suite、計23件。本文・テーマ・問い編集・保持。全試験ではない。本体コードは本PRで変更しておらず、この結果を新しい統合試験の代用にはしない |
| 修正後の合成プローブ | PASS | 5件。最終結果と対照の出力は[結果抜粋](probes/settings-feasibility-results.txt)に保持 |
| 5カテゴリ | PASS（内容描画のみ） | `TabView`の選択をプログラムで変更して640×480ptの5枚を生成。内容の欠落・はみ出しを目視確認。実際のSettings scene、カテゴリ操作、⌘,、前回の面の復元はNOT_RUN |
| 通常のノートfont変更 | PASS（合成部品） | 16→20→14→18→16pt。ネイティブビュー同一性、文章、選択範囲、fontを表明。製品の保存Binding・問いTextFieldはNOT_RUN |
| ネイティブfont変更 | PASS（合成marked text） | `NSTextView.setMarkedText`後にfontだけ変更し、marked range・文章を保持 |
| SwiftUIとBinding | PASS（同期した条件） | `didChangeText()`でBindingへ通知してからfontを変更するとmarked range `{3,4}`と文章を保持。通知しない条件ではBindingが古いままで再反映され、marked range `{57,0}`・文章不一致となる。後者を実IMEの障害と扱わない |
| 別ウィンドウへのresponder移動 | PASS（文章保持のみ） | 別NSWindowを作り、編集側のfirst responderを解除して設定側へ移動後にfont変更。文章を保持。実際のkey window切替・日本語入力候補・確定操作は模擬していない |
| 設定値化した本文 | PASS（実描画経路） | 4サイズ×3行間×3最大幅×3ペイン幅=108。各段落のfont・行間、引用字下げ20pt、リンク先とクリック通知、ヘッダ11pt、本文文字列、幅上限・左右余白を確認。リサイズも設定した幅上限を使う |
| 設定を無視する対照 | EXPECTED_FAIL | 一時コピーで通常段落だけ16ptへ固定すると、サイズの表明が失敗しexit 1。試験が属性の不変性だけを確認するものではないことを確認。対照変更は復旧後に全5件を再実行 |
| 読書位置 | 現行方式の限界を確認 | ウィンドウにNSScrollViewを載せ、段落7の長さ774 UTF-16、縦位置80ptが変更前後の段落高936/390pt内に収まることを表明。幅360→1000pt、同じ段落/80ptへ戻って先頭UTF-16が5505→5597。現在の段落表現を否定するものではなく、同じ文字との違いの測定 |
| AI利用可否 | PASS（この端末） | FoundationModels available、日本語embedding資産あり。利用不可・資産なし・Apple Intelligence無効はNOT_RUN |
| AIオフの製品挙動 | NOT_RUN | 設定保存、呼出抑止、進行中要求の結果破棄は未接続。仮トグルの保存試験は根拠に使わない |
| 保存・削除 | PASS（既存関連Core試験のみ） | プレビュー非破壊性、短縮、期限、失敗復旧、テーマ記録保持/再open。新Settingsでの確認・キャンセルはNOT_RUN |

本文プローブは試験から属性を書き換えず、[設定値化パッチ](probes/settings-typography.patch)を当てた製品の描画処理を呼ぶ。現行本文は段落ごとに一律fontを生成しており、任意の太字・等幅fontを保持する処理ではない。今回の確認は現行のリンク・引用・ヘッダ契約に限る。未実装の属性保持を主張しない。

フォームの代表例: [読書・編集の内容画像](probes/settings-category-reading.png)。これは画面設計の完成像ではなく、部品の描画確認。タイトルバーのカテゴリ操作は画像外であり、ナビゲーションの証拠には使わない。

## 実装へ届く範囲と合流条件

| 範囲 | 届く場所 | 条件 |
|---|---|---|
| カテゴリ・外観・キー一覧 | `ReaderSettingsView`、`RSSReaderApp` | UI骨格から進められる。実操作・キーボード・最後の面の復元は受入で確認 |
| 本文の文字サイズ/行間/幅 | `NativeArticleText`、`ReaderView`の呼出側、AppStorage、位置復帰 | 設定値化パッチは実現性の証拠だけ。本文再取得・再既読化を起こさない更新経路は別途確認。文字基準の復帰方式は未決定 |
| ノート文字サイズ | `QuestionEditor`の問いTextField/答えTextEditor、`UnderstandingEditor` | 保存Binding、実IME、入力先切替、選択、文章保持を確認。同じ編集ファイルを触るため機能開発と合流が必要 |
| AI | 設定値、`ThemeAssistant`と利用可否検査 | オフ時の埋め込み/生成呼出抑止と遅延応答破棄を機能開発側と揃える |
| 保存 | 既存ReaderStore / ReaderSettings / DeletionPreview | 既存データ契約を維持。画面からモデルを直接変更しない |

本PRは機能開発から切り離せる。Settingsの本実装すべてが独立するわけではない。本文・ノート・AIは呼出側への接続で合流が必要。

## 再実行と保管した証拠

```sh
bash docs/verification/probes/run-settings-feasibility.sh
```

[実行スクリプト](probes/run-settings-feasibility.sh)は固定commitを`mktemp`へ展開し、パッチと[試験ソース](probes/settings-feasibility.swift)を追加して5件を実行する。各実行のPNG・ログ・ビルド領域は新しい一時ディレクトリに分離し、パスを出力する。本人のFeeederライブラリを開かない。一時ファイルを文書の参照先にせず、結果抜粋と代表画像をリポジトリへ保管した。

本文の対照は、コピー内の`append(paragraph, size: bodyFontSize, …)`を`size: 16`に置き換え、`--filter parameterizedProductionInstallAndWidth`を実行する。期待結果はexit 1とfontサイズの表明失敗。通常実行へ戻す際はコピーを捨てて上のスクリプトを再実行する。

初回のsandbox実行はコンパイルキャッシュ書込みで失敗したため実行権限付きで再実行。再検証中にSwift TestingのCGFloat/Double比較を同じ型へ修正した。保管した結果は修正後のソースに対応する。`git diff --check`とシェル構文確認も実行した。

## レビューによる修正

[PR #28のレビュー](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090231489)に対応。

1. 属性を試験から変更する108通りを廃止し、実描画の設定値化と設定無視の対照へ置換。
2. 任意fontの保持という主張を撤回。現行のリンク・引用・ヘッダに限定。
3. font操作、Binding同期、別ウィンドウのresponder操作を分離。IMEの結論と保留推奨を撤回。
4. ウィンドウに載せて段落内の縦位置で再測定。前回の600ptの数値を根拠から除外。
5. AIの仮キー保存PASSを除外。
6. GitHubを非公開・認証済みアクセスへ訂正。
7. 証拠抜粋と代表画像を同梱し、リポジトリにないログへの参照を削除。
8. AGENTS.mdの文書マップに未承認ドラフトの場所を追記。
9. 基本メニュー、本文設定、ノート設定、位置保持の精度を別の採用判断に分離。
10. PNGとログを実行ごとのディレクトリに分離。

## 残る確認と今回の対象外

- 実際のSettings scene・⌘,・カテゴリ操作/復元・複数ウィンドウのkey window切替。
- 製品エディタの実日本語IME・問いTextField・保存/失敗復旧・長いノートのスクロール。
- 同じ文字基準の復帰方式、画像を含む位置、本文再既読化/再取得の抑止。
- VoiceOver、Reduce Motion、コントラスト/透明度、数千件/長時間の体験、提案値のPdM比較。
- AI接続、非対応機器・資産なし・進行中の無効化、実プロセス再起動の設定保存。
- macOS 26 / Swift 6.3.3。変更はAGENTS.mdとdocs配下のみでCI対象外。Release、署名・配布、機能実装、正式仕様の承認、別AIへのメッセージ送信も対象外。

既存の[問い・答え](2026-10-10-theme-questions.md)と[テーマ画面](2026-10-10-theme-screens.md)の未確認事項をこのプローブで解消したとは扱わない。
