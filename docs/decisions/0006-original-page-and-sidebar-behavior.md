# 0006 原文表示中の記事選択とサイドバー操作の方針

- 状態: 有効（承認済み内容の転記。承認根拠は出典のPR）
- 日付: 2026-10-08（PR #11）、2026-10-09（PR #14のマージ、日本時間）
- 決定者: 本人（PdM）

## 背景

Dogfoodingで、左カラムの操作整理と、原文表示から戻る際のボタン消失・列幅の変動を改善した。本人の指示をPR #11・#14で反映し、マージで承認した。

## 決定

- 原文を開いた後に `j/k` や一覧クリックで別の記事を選んだら、新しい記事の原文へ追従せず、原文を閉じて通常の読書表示へ戻る。
- 原文の開閉は右カラム内で行い、`columnVisibility` を変更しない。左・中央の幅と購読追加・更新ボタンを保つ。
- 標準のHide Sidebarは `toolbar(removing: .sidebarToggle)` で除去する。購読追加・更新は `NSTitlebarAccessoryViewController` の左配置に置く。
- フォルダ整理ボタンと専用sheetは置かず、購読の追加・編集でフォルダを指定する。

## 影響

- 原文表示中の記事選択を「新しい原文へ追従」に戻す、またはsidebarの開閉を復活させる変更は、この決定を覆すものとして利用者の確認を取る。
- 現行の挙動は docs/specification.md §3.1、docs/architecture.md §6.1に記す。
- macOS 26.6実機での確認は [読書UI追加受入](../verification/2026-10-07-feed-polish.md) の未確認項目を参照する。

## 出典

- 旧 docs/architecture.md §6.3・§6.7（commit `7451608` 時点。`git show 7451608:docs/architecture.md`）
- [PR #11](https://github.com/ojiman/feeeder/pull/11)（左カラム）、[PR #14](https://github.com/ojiman/feeeder/pull/14)（原文表示と復帰）
