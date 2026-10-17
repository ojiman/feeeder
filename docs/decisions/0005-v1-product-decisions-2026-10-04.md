# 0005 V1の製品判断4件（タイムゾーン・保持・Claude連携・ソース公開）

- Status: valid in part. Point 1's exclusion of an in-app display-language setting is replaced by [0060](0060-language-settings-and-ui-localization.md). Point 3 (Claude Desktop hand-off) is replaced by [0049](0049-one-note-and-no-ai-of-its-own.md); the week ranges of point 1 went with the daily and weekly notes. Points 2 and 4 stand.
- 日付: 2026-10-04（PR #2のマージ、日本時間）
- 決定者: 本人（PdM）

## 背景

PRDの未決事項4件を本人と確定し、PR #2で承認した。ここには当時の判断だけを記す。日次スクラップの後続判断は0004（Git履歴）、現行の詳細はPRDに記す。

## 決定

1. **タイムゾーン**: 週の範囲は、初回のノート作成時にMacの現在のタイムゾーンで決めて固定する。下書きも固定する。Macのタイムゾーン変更だけで、保存済みの範囲・既読日時・ノート本文・採用済み出典を変えない。アプリ内のタイムゾーン／表示言語の設定はV1に置かない。
2. **保持・削除**: 記事本文・RSS要約は初期30日で、Settingsから変更できる。起算点は、未読なら初回受信、既読なら初回既読。再受信・再表示で延長しない。ノートと出典リンクは自動削除しない。
3. **Claude連携**: V1の連携先はClaude Desktopのみ。本人が確認したパッケージを直接起動して依頼文と生成ファイルを送信前の入力欄へ渡し、送信は本人が行う。実機で確認した経路だけを採用する。自動送信・返答の自動書込みはしない。
4. **ソース公開と第三者ライセンス**: ソースはApache-2.0。公開対象はコード・仕様・合成サンプル／テストだけで、本人の購読・履歴・記事・ノート・認証情報を含めない。公開は製品受入後の別判断とし、この方針の確定を公開・署名配布の指示とは扱わない。LICENSEと、第三者のライセンス・著作権表示・NOTICEを同梱する。

## 影響

- 1と2の使い勝手（タイムゾーン変更時の運用、30日が週の振り返りに足りるか、保存容量）はDogfoodingで確認する項目で、未確認のままPASSにしない。
- 3の通常Chatは本人の希望だが、自動添付は未検証。現行の経路はCoworkで、この判断は通常Chatの調査を妨げない。
- 現行の挙動は docs/specification.md §3.3・§5・§6、docs/architecture.md §3に記す。

## 出典

- [PR #2](https://github.com/ojiman/unagi-reader/pull/2)。当時のPRD §3・§5・§6・§9（commit `53574c0`。`git show 53574c0:docs/specification.md`）
- Claude Desktop連携の技術検証 (Git history)
