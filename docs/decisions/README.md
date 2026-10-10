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
| [0004](0004-dogfooding-keys-and-scrap.md) | Dogfooding改訂: キー操作・スクラップ・週候補 | 一部置換済み（日次・週ノート、スクラップ、週候補は0008） |
| [0005](0005-v1-product-decisions-2026-10-04.md) | V1の製品判断4件（タイムゾーン・保持・Claude連携・ソース公開） | 有効 |
| [0006](0006-original-page-and-sidebar-behavior.md) | 原文表示中の記事選択とサイドバー操作の方針 | 有効 |
| [0007](0007-support-floor-macos-27.md) | サポート下限をmacOS 27.0にし、ビルド下限は26.6のまま据え置く | 有効 |
| [0008](0008-theme-centered-notes.md) | ノートをテーマ中心に改める（0004の日次・週ノート部分を置換） | 一部置換済み（問い・答えは0013） |
| [0009](0009-on-device-ai-principles.md) | AIは端末内の提案に限る | 有効 |
| [0010](0010-on-device-suggestion-defaults.md) | 端末内の提案（近いテーマ・まとまり）の既定 | 有効 |
| [0011](0011-on-device-generation-defaults.md) | 端末内の生成（テーマ名の案・問いの具体化）の既定 | 有効 |
| [0012](0012-claude-handoff-from-themes.md) | Claude hand-off from themes | valid (the questions and answers switches change under 0013) |
| [0013](0013-goal-and-note-for-themes.md) | A learning goal and one note per theme (replaces questions and answers of 0008) | valid |
| [0014](0014-note-migration-format.md) | The note migration: format, what stays, what pauses | valid (approved by merging the N2 plan) |
| [0015](0015-article-summary-details.md) | The article summary: budget, insertion point, and limits | valid (approved by merging the N4 plan) |
| [0016](0016-note-actions.md) | Note actions: two actions, their limits, and how an adopt is undone | valid (approved by merging the N5 plan) |
| [0017](0017-note-beside-the-article.md) | The note beside the article | valid (approved by merging the PR that adds it) |

0001〜0006は、すでに他の文書にあった決定を転記したものです。誤りがあれば、新しい記録で置換してください。

0004〜0006の承認根拠は各出典のマージ済みPRです。転記によって新しい承認待ちを作りません。現行の契約はPRD／Architectureを読み、理由・承認の来歴が必要なときに該当記録を参照します。
