# Settings メニュードラフトのフィジビリティ検証

更新日: 2026-10-10（日本時間）。状態: 未承認の設計案と一時コピーの試作。製品受入・仕様承認ではない。

対象: [3カテゴリに縮小したSettingsドラフト](../superpowers/specs/2026-10-10-settings-draft.md)。製品コード・保存モデル・依存・正式PRD/Architectureは変更していない。

## 現時点の結論

**3カテゴリ・文字サイズ1設定を未承認の推奨案とする。本文を再インストールしないサイズ更新と、上端の文字を含む行への復帰は、合成本文ビューの36ケースで成立した。製品統合の実現性・受入がすべて確認できたわけではない。**

- 初期描画の設定値化は108通りで確認したが、それだけでは開いている記事の即時更新を証明できない。既存`install()`は表示開始通知、初回表示状態の初期化、全文属性の再生成を行うため、今回は別の`updateReadingSize()`を試作した。
- 更新では既存の本文範囲のfont・行間とレイアウト幅だけを変え、本文文字列を再設定しない。変更前の上端行の文字位置と行内の縦差を取り、変更後の同じ文字が属する行へ戻す。選択範囲も保持する。
- 成立した判定は「変更前の上端行の文字が、変更後の上端行に含まれる」。再改行で行頭が変わるため、先頭UTF-16位置の完全一致ではない。末尾でスクロール制限がかかる場合や、画像・空白が上端にある場合は未検証。
- 比例行間`size / 2`、最大幅`670 × size / 16`は試作の入力値。広いペインでの1行の長さを調整する案で、狭いペインで文字数一定を保証しない。読みやすさの実機評価は未実施。
- ノートは同じ1設定を次の編集面表示で適用する案。製品のエディタ表示境界・保存には未接続。合成marked textは手動Binding通知の有無で結果が異なり、実IMEの即時反映は**未確定**。別NSWindowのresponder移動後もmarked textは残ったため、変換確定を模擬した証拠にはしない。

## 基準と環境

| 項目 | 値 |
|---|---|
| 固定した製品ソース | `e9bcd933873fe920fc3751ba417afe561ff2a99c` |
| 作業ブランチ | `codex/settings-feasibility`、Draft PR #28 |
| OS / CPU | macOS 27.0.1 (26A434)、Apple Silicon |
| Xcode / Swift | Xcode 27.0 (27A266a)、Swift 6.4 (swiftlang-6.4.0.34.1) |
| 入力 | 合成した日英文章・絵文字・架空リンク。本人のライブラリは開かない |
| 外部操作 | 認証済みGitHub経由で非公開リポジトリのレビューを確認、PR更新。記事取得・AI推論・資産取得・Claude起動なし |

`ReaderSettingsView`、`RSSReaderApp`、`NativeArticleText`、`QuestionEditor`、テーマのUnderstandingEditor、保持処理とPRD/Architecture・決定0008/0009を参照した。現行本文の呼出側はsignature変更時だけinstallする。文字サイズの変更をsignatureへ単純に追加するだけでは本試作の安全な経路へ接続できない。

## 試作と表明範囲

[初期描画用パッチ](probes/settings-typography.patch)と[表示更新用パッチ](probes/settings-live-update.patch)は一時コピーへだけ適用する。製品のソースディレクトリは本PRで変更しない。

| 確認 | 結果 | 表明範囲 |
|---|---|---|
| 最新の合成プローブ | PASS | 6件。[最新結果抜粋](probes/settings-po-results.txt)。コミットするパッチと同じ入力で実行 |
| 初期描画の設定値化 | PASS | 4サイズ×3行間×3最大幅×3ペイン幅=108。installとsetFrameSize経由でfont・通常/引用行間・幅上限・左右余白・リンク先/通知・ヘッダを確認 |
| 個別の設定無視対照 | EXPECTED_FAIL | font、行間、幅上限、左右余白を別々に無視すると各表明で失敗。fontと行間の式も分離し、短絡で未評価になることを避けた |
| 本文のライブサイズ更新 | PASS（36ケース） | 3ペイン幅360/600/1000pt×3開始段落0/7/20×4更新20/14/18/16pt。ウィンドウに載せたNSScrollViewで旧上端行の文字が新上端行に含まれることを表明 |
| 更新時の本文状態 | PASS（同36ケース） | 本文文字列、選択範囲、リンク、引用字下げ/行間を保持。幅は比例式/ペインの上限と一致 |
| 更新時の表示通知 | PASS（同36ケース） | bitmap描画と非同期通知を処理して、onDisplayBegin / onDisplayedは各1回の初回通知から増えない。installの初回表示状態をリセットしない |
| 既存の段落/縦差復帰 | 限界を確認 | 幅360→1000pt、段落7/80ptを保持しても先頭文字5505→5597。変更前後の段落高936/390pt内に80ptが収まることを確認。新方式の文字サイズ更新とは別の測定 |
| フォーム描画 | PASS（旧5カテゴリの骨格のみ） | 640×480ptの仮文言とPickerの描画。全提案項目のはみ出し確認ではない。[旧代表画像](probes/settings-category-reading.png)は縮小案の完成画面ではない。3カテゴリの実フォームはNOT_RUN |
| 合成エディタ | 条件付きPASS | 通常のfont変更は文章・選択を保持。marked textは手動didChangeTextでBinding同期した場合に保持。実IMEと製品への接続はNOT_RUN |
| AI利用可否 | PASS（この端末） | FoundationModels available、日本語embedding資産あり。非対応/一部不可・オフの製品挙動はNOT_RUN |

ライブ更新の試作は読み込み・ネットワーク・Storeを呼ばない。ただし、アプリ本体のReaderViewやNSViewRepresentableから呼んでいないため、**本体で再取得や再既読化がないという受入にはしていない**。呼出側の更新、scroll通知のCoordinator、画像のレイアウト、選択した記事の切替は別途確認が必要。

試作は現行の段落font契約に限る。現行で実装されていない任意の太字・等幅runの保持は主張しない。サンプル末尾の改行属性・本文なし/期限切れ表示へのライブ更新も未検証。

## 以前の記録とPO再レビューへの対応

初回の固定commit関連試験はUI17件/3 suite、Core6件/1 suite、計23件。[前回結果抜粋](probes/settings-feasibility-results.txt)はcommit `f87bca5`時点の試験で、最新統合の代用ではない。前回の5カテゴリ案と108通りの任意設定は調査の履歴で、今回採用を推奨する設定数ではない。

[初回レビュー](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090231489)の10項目では、実描画経路、private GitHubの記述、AI仮キーPASS除外、証拠同梱、AGENTSの文書地図、採用判断の分割、実行ごとの出力分離を修正した。

[PO再レビュー](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090440369)の5項目への今回の対応:

1. 初期描画とライブ更新を区別し、installとは別の試作を測定。結論の範囲を本文ビュー単体へ限定。
2. font/行間の表明を分離。行間・幅上限・余白も個別の設定無視対照を追加。
3. 実IMEの反映は未確定と記述。手動Binding同期、marked textが残るresponder操作を実入力と扱わない。
4. 旧フォーム描画は仮の骨格と明記。今回の3カテゴリ完成画面の証拠には使わない。
5. 最終実行の後に入力パッチを変更しない。入力SHA256と結果を最新記録へ保持。前回の空白正規化は過去の記録に留める。

POの製品提案はPdM未承認。薄い3カテゴリ、文字サイズ1設定、ノート次回表示、ヘルプへの一覧配置を推奨案へ反映した。テーマ記事の本文保持は既存保存契約を変える別件として、本PRから分離した。

## 再実行

```sh
bash docs/verification/probes/run-settings-feasibility.sh
```

[スクリプト](probes/run-settings-feasibility.sh)は固定commitをmktempへ展開し、2つのパッチと[試験ソース](probes/settings-feasibility.swift)を追加する。PNG・ログ・ビルドは実行ごとのディレクトリへ出力する。専用UserDefaults suiteだけを使い、試験後にそのsuiteを削除する。

個別対照の再現: 展開コピーのNativeArticleText.swiftで下記を**1件ずつ**置換し、同じswift testオプションで`--filter parameterizedProductionInstallAndWidth`を実行する。各期待結果はexit 1。元に戻してから次の対照を実行する。

| 対照 | 置換前 | 置換後 |
|---|---|---|
| font | `append(paragraph, size: bodyFontSize` | `append(paragraph, size: 16` |
| 行間 | `style.lineSpacing = lineSpacing` | `style.lineSpacing = 8` |
| 幅上限 | `min(maximumBodyWidth, newSize.width - 84)` | `min(670, newSize.width - 84)` |
| 左右余白 | `max(42, (newSize.width - width) / 2)` | `CGFloat(42)` |

結果抜粋・入力SHA256をリポジトリへ保持し、リポジトリにないログを文書の参照先にしない。文書リンク、shell構文、git diff --checkを確認する。プローブの最初のsandbox実行はコンパイルキャッシュの権限で止まったため、許可された実行権限で実行した。

## 残る確認・合流

- 実際のSettings scene、3カテゴリの完成レイアウト、⌘,、カテゴリ復元、複数ウィンドウ。
- ReaderView/NSViewRepresentableの設定接続、Store・取得の副作用、scroll通知・記事切替、⌘+/⌘−/⌘0の配列/入力欄/WebViewとの衝突。
- 上端が画像/見出し/空白の場合、文末のスクロール制限、非常に短い記事、ヒーロー画像、元記事が変わる場合、原文からの復帰。
- 既存ノートの次回表示境界、問いTextFieldと答え/理解TextEditor、実日本語IME、保存/失敗復旧、長い編集文。
- 更新時の遅延・滑らかさ、比例式の日英読みやすさ、VoiceOver、Reduce Motion・コントラスト・透明度、数千件・長時間のUX。
- AI接続、一部不可・資産なし・非対応、進行中の無効化、非同期状態確認、設定の別プロセス再起動。
- macOS 26 / Swift 6.3.3。AGENTS.mdとdocsのみのためCI対象外。Release、署名/配布、製品実装、正式仕様承認は対象外。

既存の[問い・答え](2026-10-10-theme-questions.md)と[テーマ画面](2026-10-10-theme-screens.md)の未確認事項は残る。
