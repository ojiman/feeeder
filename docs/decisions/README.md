# 決定記録

「誰が・いつ・なぜ・何を決めたか」だけを残します。会話の全文は残しません。

## 目的

- 同じ決定が仕様・Architecture・AGENTS.md・READMEに言い換えで散らばり、食い違うのを防ぎます。各文書は詳細をここへ向け、決定の根拠はここを正とします。
- 新しい書き手（人でもエージェントでも）が、「なぜこうなっているか」を最初に読める場所にします。
- 仕様の「承認済み」表示の来歴を、日付と決定者で追えるようにします。

## 書き方

- 1決定1ファイル。`NNNN-題名.md`。追記のみで、決定を覆すときは新しい記録で「置換: NNNN」と書き、古い記録の状態を「置換済み」に変えます。
- 項目: 状態・日付・決定者・背景・決定・影響・出典。短く、事実だけ。
- 日付は、確認できた最古の出典（PRのマージ日など）に合わせます。不明なら、不明と書きます。

## 全文の会話ログをコミットしない理由

- 個人情報・認証情報・本人のライブラリの内容が混じるおそれがあります（AGENTS.mdの境界に反します）。
- 結論に至らなかった議論が大半で、後から読むエージェントの文脈を無駄に消費します。
- 決定に必要なのは結論と根拠です。根拠となった実測や出典は、PR・verification・issueにあります。

セッションごとの作業記録（`.superpowers/...` など）は、端末ローカルの作業メモとして扱います。リポジトリに無いものを、文書から参照しないでください。

## 一覧

| 番号 | 題名 | 状態 |
|---|---|---|
| [0001](0001-fresh-library-no-prototype-migration.md) | V1は空ライブラリから始める | 有効 |
| [0002](0002-single-supervised-writer.md) | 実装者は同時に1名 | 有効 |
| [0003](0003-beta-data-compatibility.md) | ベータ中はデータ互換を保証せず、1.0から保証する | 有効 |
| [0005](0005-v1-product-decisions-2026-10-04.md) | V1の製品判断4件（タイムゾーン・保持・Claude連携・ソース公開） | 有効 |
| [0006](0006-original-page-and-sidebar-behavior.md) | 原文表示中の記事選択とサイドバー操作の方針 | 有効 |
| [0007](0007-support-floor-macos-27.md) | サポート下限をmacOS 27.0にし、ビルド下限は26.6のまま据え置く | 有効 |
| [0009](0009-on-device-ai-principles.md) | AIは端末内の提案に限る | 有効 |
| [0012](0012-claude-handoff-from-themes.md) | Claude hand-off from themes | valid in part; replaced by 0019 |
| [0015](0015-article-summary-details.md) | The article summary: budget, insertion point, and limits | valid in part; refined by 0019 |
| [0017](0017-note-beside-the-article.md) | The note beside the article | refined by 0019 |
| [0019](0019-v1-simplification-notes.md) | V1 simplification: notes replace themes | valid (approved by merging the PR that adds it) |

| [0020](0020-summary-send-contract.md) | Summary sending and undo (S2) | valid (PR #69) |
| [0021](0021-note-share-menu-and-review.md) | Note sharing and Claude review (S3) | valid (PR #71) |
| [0022](0022-note-only-package-clean-up.md) | Note-only packages and managed-copy cleanup (S4) | valid (PR #74) |
| [0023](0023-rename-to-unagi-reader.md) | Rename to Unagi Reader | valid (with the rename PR) |
| [0024](0024-remove-the-old-name-from-code-and-scratch.md) | Remove the old name from code and scratch paths | valid (with the cleanup PR) |
| [0025](0025-refresh-feel.md) | The feel of a refresh | valid (with the refresh PR) |
| [0026](0026-article-list-row-spacing.md) | More room in the article list rows | valid (with the spacing PR) |
| [0027](0027-calmer-colours.md) | Calmer colours | valid (with the colours PR) |
| [0028](0028-article-list-type-sizes.md) | Article list: the headline leads | valid (with the type-size PR) |
| [0029](0029-sidebar-header-plus.md) | A + in the sidebar section headers | valid (with the sidebar-header PR) |
| [0030](0030-one-reading-surface.md) | One reading surface | valid (with the surface PR) |
| [0031](0031-less-clutter.md) | Less clutter in the window | valid (with the clean-up PR) |
| [0032](0032-simple-add-subscription.md) | A simple "add subscription" sheet | valid (with the sheet PR) |

0001〜0006は、すでに他の文書にあった決定を転記したものです。誤りがあれば、新しい記録で置換してください。

置き換わった記録（0004、0008、0010、0011、0013、0014、0016、0018）は、2026-10のprune PRで作業ツリーから外しました。内容と来歴はGit履歴にあります（`git log --follow -- docs/decisions/<ファイル名>`）。

0004〜0006の承認根拠は各出典のマージ済みPRです。転記によって新しい承認待ちを作りません。現行の契約はPRD／Architectureを読み、理由・承認の来歴が必要なときに該当記録を参照します。
