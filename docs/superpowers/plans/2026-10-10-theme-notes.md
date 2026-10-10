# Theme Notes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. このプロジェクトでは承認済みの単独・対話型実装を維持する（[決定0002](../../decisions/0002-single-supervised-writer.md)）。

**Goal:** 日次・週ノートを、Star→テーマ（記事・問い・自分の答え・いまの理解）の流れに置き換え、端末内AIで束ね方・名前・問いの具体化を提案する。

**Architecture:** SwiftDataに`Theme`・`ThemeArticle`・`ThemeQuestion`を追加し（PR 3）、既存の3カラムにテーマの区画と[記事｜問い]の切り替えを載せ（PR 4・5）、AIは`ThemeAssistant`プロトコルの背後に置いた端末内モデルの提案だけにする（PR 6・7）。Claude連携はテーマからの入口へ付け替える（PR 8）。

**Tech Stack:** Swift 6、SwiftUI、AppKit、SwiftData、FoundationModels、NaturalLanguage、Swift Testing。外部依存の追加なし。

**Spec:** [PRD](../../specification.md)第3.1〜3.3・5・7節、[Architecture](../../architecture.md)第2.1・2.2・3・6.1節、[決定0008](../../decisions/0008-theme-centered-notes.md)・[0009](../../decisions/0009-on-device-ai-principles.md)。仕様承認: [PR #21](https://github.com/ojiman/feeeder/pull/21)（main `b2d3d96`）。本計画はこのPRのマージで承認される。計画承認を最終製品受入とは扱わない。実装・検証結果は各PRの検証記録（`docs/verification/`）に記録する。

## この計画の範囲

実装は8本のPRのうちPR 3〜8で、**後ろのPRほど前のPRが作るコードを前提にする**。そこで、この文書は次の2部で構成する。

- **第1部 ロードマップ（PR 3〜8）**: 各PRの範囲、前提、受入、未検証、検証の要点。手順はまだ書かない。
- **第2部 PR 3の詳細計画**: 失敗するテストから書く手順を、コードつきで示す。

PR 4以降の詳細計画（手順とコード）は、直前のPRが着地して実コードが確定してから、別の計画文書として書き、そのPRで承認を取る。PR 1・2は完了済み（[#20](https://github.com/ojiman/feeeder/pull/20)・[#21](https://github.com/ojiman/feeeder/pull/21)）。

The work after PR 8 (Settings, the rename to Unagi Reader, and beta preparation) was added after PR 8 landed. It is in "Part 1b" below and follows the same rule: this document lists scope, order, gates and acceptance, and each PR gets its own detailed plan when it starts.

## Global Constraints

- サポート下限はmacOS 27.0、ビルド下限（`Package.swift`・CI）はmacOS 26.6のまま。macOS 27 SDK専用のAPIは、CIがビルドできるまで使わない（[決定0007](../../decisions/0007-support-floor-macos-27.md)）。
- Backend、アカウント、同期、無人worker、外部依存の追加をしない。単独writerで進める。SwiftSoupはexact固定のまま。
- Starとテーマは独立する。`t`は既読日時・Starを変えない。Starを外してもテーマには残る。未整理のStar＝Starが付いていてどのテーマにも入っていない記事。
- テーマに入れた時点のタイトル・URL・保持しているRSS要約を記録し、要約は本文の期限切れ・購読解除の後も残す。抽出全文は複製しない。Star・テーマへの追加は元記事の期限を延長せず、期限切れ全文をAI入力に復活させない。
- 同じ記事を同じテーマへ再追加しても、重複・内容の上書きをしない。保存失敗は成功扱いにしない。
- 答えといまの理解にAIや他の操作が自動で書き込まない。AIは端末内の提案だけで、外部通信・アカウント・APIキーを使わない。
- 新しい変更経路は先頭で`reloadIfNeeded()`を呼び、保存／再読み込みの失敗注入試験（`failedRecoveryBlocksChangesUntilReloadSucceeds`に追加）を足す。失敗後は、古いモデル参照ではなくIDから現在のモデルを解決する。
- ベータ間のデータ互換は保証しない（[決定0003](../../decisions/0003-beta-data-compatibility.md)）。旧ストアが開けない場合は、実DBを自動削除・再作成せず、本人に相談する。
- テキスト入力・IME変換・修飾キー付き操作では、文字入力と標準操作を優先する。
- 入力とDBは合成・一時データだけ。本人のライブラリ・資格情報・Keychain・ブラウザprofileを使わない。
- 1PR1テーマ。バグ・新機能は失敗するテストを先に書き、失敗と成功を記録する。コミット／PRの末尾には、セッションが指定する共著表記を付ける。
- 署名・配布・新Tag／Release、`main`への直接pushをしない。GitHubへのpush・PR作成は本人の許可を得る。

## Review Focus

仕様が暗黙に求めているが、通常のテストでは見落としやすい入力・失敗を、起きやすい順に挙げる。担当Taskにそれぞれ試験を置く。

1. 現行ベータで作ったストアを、モデルを追加した新スキーマで開く（既存の購読・既読・日次・週ノートが残ること）→ PR 3 Task 5。モデルを外すPR 4では最初のTaskでやり直す。
2. 保存が途中で失敗したあと、画面に失敗した値が残らず、同じ操作を再試行できる（作成・追加・答え・根拠・削除）→ PR 3 Task 4。
3. 購読解除・本文期限切れの後も、テーマに記録した要約が残り、タイトル・URLが読める → PR 3 Task 2。
4. 根拠にしていた記事をテーマから外しても、答えは消えず、根拠の紐付けだけが外れる → PR 3 Task 3。
5. 空白だけの名前・問い・答え、同じ記事の再追加、存在しないテーマ／記事のIDを渡されたとき、壊れず、データを変えない → PR 3 Task 1〜3。

---

# 第1部 ロードマップ（PR 3〜8）

| PR | テーマ | 範囲 | 前提・主な成果物 | 受入と検証の要点 |
|---|---|---|---|---|
| 3 | テーマの保存基盤 | `Theme`/`ThemeArticle`/`ThemeQuestion`、`QuestionLens`、`ReaderStore`の操作と索引。**追加のみ**で画面は変えない | 第2部。成果物: `createTheme`/`addArticle`/`addQuestion`など、`unfiledStarredArticleIDs(keeping:)` | 失敗注入、再open、旧ベータ（beta.2）ストアの再open。**危険な変更なので固定commitの独立レビュー** |
| 4 | テーマ画面と旧ノートの置き換え | 左カラムの再編（Feeds／テーマ／購読元）、テーマの[記事｜問い]切り替え（問いの面は「いまの理解」の行と編集のみ。問いの行はPR 5）、`t`とツールバーのアイコン（選択ポップオーバー、AIなし）、日次・週ノート・スクラップ・`n`・旧モデル5つ・AI入力の入口の削除、`DemoLibrary`は文言のみ変更（データは変えない）、PRD冒頭の「改訂中」注記とREADMEの更新。詳細は[PR 4の計画](2026-10-10-theme-screens.md) | PR 3。**最初のTask**: 現行main（旧10モデル）の合成ストアを、旧モデルを外した新スキーマで開く試験（`prepare-v1-store-fixture.sh`の基準commit追加）。開けなければ止まって相談 | 合成デモの別インスタンス（`open -n`＋`--data-directory`＋`--seed-demo`）で`t`・アイコン・切り替え・Feedsとの往復を確認。IME・VoiceOverは未検証として残す。Claude連携の入口がPR 8まで無いことをPRに明記 |
| 5 | 問いとレンズ（定型） | 問い一覧（先頭に「いまの理解」）、レンズ選択、問いの編集、答えの編集面、根拠の記事の選択と読書面への移動、回答済みの印 | PR 3の`addQuestion`/`saveAnswer`/`setEvidence`、PR 4の画面 | AIなしで「Star→テーマ→問い→答え」が完結する。**チェックポイント**: ここで本人が実機で手触りを確認してから、PR 6以降に進む（ベータ配布は本人の指示による） |
| 6 | 端末内AI①: 近いテーマ・まとまりの提案 | `ThemeAssistant`プロトコル、`OnDeviceThemeAssistant`（`NLContextualEmbedding`）、`t`の選択に近いテーマ、「未整理のStar」にまとまりの提案、設定の有効／無効 | PR 4・5。偽の`ThemeAssistant`でテストする | 並行処理を含むので独立レビュー。MainActorを塞がない、遅延応答を捨てる、資産が無くても通信しない。実物の質は環境つきで記録し、実Starでの精度は未検証として残す |
| 7 | 端末内AI②: 名前・レンズの具体化 | `FoundationModels`のプレーンテキスト応答（出力上限つき）でテーマ名案とレンズ具体化、失敗時は定型文 | PR 6 | ガードレールの誤検知・上限超過・取消で手動操作が止まらない。出力の質はPdMが判断（PASSは仕組みに付ける） |
| 8 | Claudeハンドオフの付け替え | `AIInputSelection`を`article`と`themeArticle`にし、テーマから「Claudeで開く」。問いと自分の答えを含めるかを確認画面で選ぶ。`deleteTheme`/`removeArticle`で管理コピーを同期 | PR 4〜5 | 既存のハッシュ・期限・再試行の試験を維持。Claude側の実機確認は検証済みのCowork経路だけを扱い、未確認を合格にしない |

各PRの共通の完了条件は`AGENTS.md`の「Definition of done」に従う（テスト、Releaseビルド、`git diff --check`、UI変更では合成インスタンスでの操作、未検証の列挙、仕様変更時の文書更新）。

---

# Part 1b: Follow-on roadmap (after PR 8)

Status when added: PR 3 to PR 8 are merged. The Settings draft ([draft](../specs/2026-10-10-settings-draft.md), [feasibility record](../../verification/2026-10-10-settings-feasibility.md), [key-input record](../../verification/2026-10-10-settings-key-path.md)) is merged as **unapproved** evidence; it is not a decision. The PdM chose the product name **Unagi Reader** (2026-10-10). The earlier candidate, Mogura Reader, is not used. The concept is described in [README.md](../../../README.md).

Merging the PR that adds this part approves the order and gates below as a plan. It does not approve the Settings proposal, the rename details, or the beta. Each of those has its own PdM decision, listed below.

## How the stages fit together

The PdM's real-device check is the most important next step, so it runs first and does not wait for any PR. Settings work that does not depend on the theme screens runs beside it. Work that depends on screens, keys, or rules that feedback may still change waits until the first round of feedback is closed, so it is not built twice. The rename goes between PRs, because it touches many files. Beta distribution does not wait for PR 9. Documents and probes keep growing slowly under the proportion rules in AGENTS.md and are pruned once, in stage G, before the 1.0 acceptance.

| Stage | Owner | What | Exit |
|---|---|---|---|
| A. Real-device check and fixes | PdM tests; agent fixes | See the checklist below. Bugs reported here are fixed before any polish (AGENTS.md, Definition of done 1). | The PdM closes the first round and decides D2 and D3. |
| B. PR 9: article reading size | Agent | Runs beside A. A bug fix from A takes priority over PR 9. See the PR table. | PR 9 merged. D1 approved before its performance result is accepted. |
| C. Verification sweep | PdM hands needed | Items that automation could not check: real Japanese IME, VoiceOver, the macOS 26 CI result for the merged code, the new Settings display, and the behavior of the AI suggestion card. Also watch for one unexplained result: the first cold (no build cache) test run of an independent reviewer ended with exit code 1 after 124 passing tests, and two later runs did not repeat it (see `docs/verification/2026-10-10-claude-handoff-theme.md`). If it appears again, on CI or locally, investigate it then. | Records in `docs/verification/` updated. Open an "Unverified check" issue only for items that need tracking, within what the PdM allows (AGENTS.md, Definition of done 5). |
| D. Rename to Unagi Reader | Agent, after D4 | One theme in one PR, started when no other PR is in flight. See "The rename PR". | Rename PR merged, before beta distribution. |
| E. PR 10 and PR 11 | Agent | After A closes. PR 10 also needs the real-IME result from C. See the PR table. | PRs merged. They do not block the beta. |
| F. Beta preparation | PdM decides; agent prepares | PdM approval of `docs/specification.md` (its header says it is still required). A check that the user guides match the app. Signing and distribution only on the PdM's instruction (AGENTS.md, Boundaries). | A, D and the spec approval are done. Unverified items may remain if they are listed in the release notes; the PdM decides. |
| G. Prune before 1.0 | Agent audits and cuts; PdM approves the scope | Run the `complexity-budget` audit (read-only). The PdM approves what to cut. Then cut in small PRs: compress verification records and probes to their conclusions (raw logs, probe patches and event dumps stay in Git history), merge records on the same topic, make `README.md` the front door and mark `docs/` as internal records, and fix cross-links and the commit hashes that documents cite. No Git history rewrite. | After the beta and before the 1.0 acceptance demo (PRD-07), and after the 1.0 shipping conditions in PRD §7.1 are done, so the two do not compete. Records that the acceptance relies on are kept until the acceptance is done. |

Checklist for stage A:

- 「Claudeで開く…」 (Open in Claude…) on the theme screen opens Claude Desktop. This is the PRD-05 acceptance and it is still unverified.
- In the question face, the 「AIの案」 (AI suggestion) card appears and can be adopted.
- On real Stars, the quality of the suggested groupings and of the nearby themes.
- On the review screen of 「Claudeで開く…」, turn the switch 「自分の答えと根拠の記事を含める」 (include my answers and evidence articles) on and off. The package text, its size, and its SHA-256 must change at once, and your answers must appear only when the switch is on. Do not press the launch button unless you want to open Claude Desktop with this content. (The agent checked this on synthetic data only; see `docs/verification/2026-10-10-claude-handoff-theme.md`.)

## Roadmap for PR 9 onward

| PR | Theme | Scope | Prerequisites | Acceptance and verification |
|---|---|---|---|---|
| 9 | Article reading size | One shared reading size (Small / Standard / Large / Extra Large = 14 / 16 / 18 / 20 pt, default Standard) in the existing 「外観」 (Appearance) tab. View-menu commands 「文字を大きく」 (Increase Text Size), 「文字を小さく」 (Decrease Text Size), 「実際のサイズ」 (Actual Size) with key equivalents. A separate update path for an open article (not `install()`). Line spacing `size / 2` and maximum width `670 × size / 16` as unapproved candidates. The saved scroll position is refreshed after reflow. A small tool the PdM runs on their own store to print article-length statistics. A decision record and the PRD/Architecture edits for this behavior, in the same PR. | PR 8 (done). The Settings draft. Decision **D1** can be proposed in the plan and approved by merging it. | The top visible text stays in the top line after a size change. The saved position matches `readingPosition()` and restores the same text. No refetch, no re-read, no content rewrite. A size limit is a no-op. Check JIS and other input sources, and the menu commands in the real app. Measure event-to-draw time on synthetic articles of three lengths in a separate instance (`open -n`, `--data-directory`, `--seed-demo`). Start from the probe tests in the feasibility record. Time is recorded; the budget from D1 decides the performance result. |
| 10 | Note editor scale | The same scale for the theme note (decision 0013; it replaces question, answer and current understanding), based on the resolved current `.body` and `.title3` + semibold sizes (factors 0.875 / 1 / 1.125 / 1.25). Apply immediately while editing. Defer only while IME composition is active, keep the latest value, and show a pending message. | Stage A closed. N2 (the note editor exists). The real-IME check from C. | Real Japanese IME: composition and candidates stay intact, and the pending update always resolves. Save binding, selection and text stay intact. Standard keeps the current look. If SwiftUI cannot observe marked text, add a native input bridge and say so in the PR. |
| 11 | Settings polish | Help-menu list of shortcuts. Storage explanation text, aligned with D3. AI status wording (the 「端末内AI」 tab already shows status lines). | Stage A closed. Decision **D3**. | Labels match the real keys and behavior. No new settings are added. |
| (if D3 says yes) | Keep bodies of themed articles | A new decision record and a retention change (PRD §3.3, `ContentRetention`). A product change, not a Settings item. | Stage A closed, D3 | Its own plan, decision record and independent review. Not started without the PdM's instruction. |

## The rename PR (stage D)

The name is decided. What the rename changes is not, because some parts can orphan a beta user's library.

- **Proposed scope (display names and text):** the name shown in the app (window title, menus, About), the app bundle's display name, `README.md`, the user guides, and a short decision record. This is the part that does not touch stored data.
- **Not in the proposal, needs D4:** the bundle identifier and the data folder `~/Library/Application Support/Feeeder/`. Changing either makes an existing beta library invisible to the renamed app. Compatibility between beta versions is not guaranteed (decision 0003), but silently orphaning a library is a trap. The PRD (§7.1) already requires the bundle ID, storage location and signing to be fixed for 1.0. Proposal: keep both through the beta, and fix them together with the 1.0 conditions, with a visible migration or a clear message.
- **Not proposed:** renaming the repository, the SwiftPM targets (`RSSReader`, `ReaderCore`) or the source folders. They add churn and no user value. Do it only if the PdM asks.
- The first task of the PR is to list every place the old name appears, and to stop and ask if anything outside the proposal is found.

## Decisions for the PdM

- **D1 (before PR 9 is accepted).** Time budget by article length, and what happens for very long articles. Proposal: up to about 50,000 UTF-16 units, an update should finish within about 100 ms; above that, apply once after the key is released. The probe measured about 1.2 to 2.4 ms per 1,000 units, close to the time to open the same article. The numbers are a proposal, not a decision.
- **D2 (when stage A closes).** Whether the shared reading size and the proportional line spacing and width feel right on the device, or need separate controls.
- **D3 (when stage A closes).** Whether to explore keeping the bodies of articles that are in a theme. It changes the storage contract in decisions 0004 and 0005.
- **D4 (before the rename PR).** What the rename changes: display names and text only (proposed), or also the bundle ID and the data folder.
- **Spec approval (before beta).** Approval of `docs/specification.md`.
- **Prune scope (before stage G).** The PdM approves the audit result before anything is cut.

Feedback-sensitive assumptions. If feedback changes one of these, revisit the PR that depends on it before building it:

- The question and answer editor layout (PR 10).
- The set of keyboard shortcuts (the PR 11 list, and the PR 9 key choice).
- The behavior and wording of the AI features (PR 11).
- The reading-size values and the proportional formula (PR 9, checked on the device).
- The retention contract for themed articles (PR 11, D3).

Not in this roadmap: separate controls for line spacing, width or note size; a sample article; key remapping; a settings framework; the language setting that the README plans before the public release. Add them only if feedback shows a need.

---

# Part 1c: Goal and note (decision 0013)

Added after the PdM chose a new direction on 2026-10-10: a learning goal and one note per theme replace questions, answers, and the separate "current understanding" ([decision 0013](../../decisions/0013-goal-and-note-for-themes.md)). Merging the PR that adds this part approves the order and gates below as a plan. Each PR gets its own detailed plan when it starts, and updates the specification and the architecture for what it changes.

The work runs beside the PdM's real-device check (stage A) and PR 9. A bug from stage A comes first. The unit is one theme per PR.

| PR | Theme | Scope | Prerequisites | Acceptance and verification |
|---|---|---|---|---|
| N1 | Learning goal | `Theme.goal` (plain text, at most 200 characters, may be empty). Edit it where a theme is created and renamed, and show it at the top of the theme (both faces). The specification line for the theme (§3.2) and its acceptance row are updated. | None | Save and reload, a failed save is not shown as success (failure injection), the 200-character limit, an empty goal, a theme deleted while editing. |
| N2 | The note, and the migration ([detailed plan](2026-10-10-theme-note.md); the removal of the question code that is no longer reachable follows as N2b) | `Theme.note` (one plain-text document). The face switch becomes [記事｜ノート]. The note editor handles long text and IME. A one-time migration turns the "current understanding" and every question, answer, and evidence list into note text, then deletes the old records after success. The question screens, lenses, and question proposals (PR 5 and PR 7 code) are removed. The note replaces "current understanding" in the PRD (§3.3, PRD-04, PRD-06, PRD-13). | N1. Stage A feedback on the question screen is read first. | **Migration is the risk:** tests on synthetic stores of older shapes (with and without answers, evidence, empty answers); a failure must delete nothing and say so; nothing is lost. Typing, saving, and selection with the real Japanese IME (PdM check). Independent review of a fixed commit (store, model, deletion). |
| N3 | Two panes and the folding sidebar ([detailed plan](2026-10-10-theme-two-panes.md)) | On the note face the sidebar folds with the standard split-view behavior. Middle: the note. Right: the reader with a top bar (previous and next article, a menu of the theme's articles, `j` / `k`). The face restores per theme as today. Reduce Motion is respected. | N2 | The reader keeps its reading position when switching articles and faces. Folding and unfolding do not lose the note's cursor or unsaved text. A narrow window still works. Check on a real window and with Reduce Motion. |
| N4 | AI summary in the reader ([detailed plan](2026-10-10-ai-summary.md)) | A switch [原文｜AI要約] in the reader's top bar. One on-device request per article, only on request, cancellable, with a clear "AI" label and a link back to the original. Adopting puts the text into the note. Budgets follow decision 0013 (article points at most 1,000 tokens). | N3, and the experiment below | Failure, unavailable model, expired text, and a long article never block reading. Nothing is saved unless adopted. The AI setting off means no call. |
| N5 | Note actions ([detailed plan](2026-10-10-note-actions.md); narrowed to two actions after the experiment) | One-step actions below the note: what is missing for the goal, an opposing view, make this section clearer, the essence in three lines. Input is the goal, the section at the cursor or the selection, and chosen article points, within the budget. A card with adopt, another take, close. A stale card is dropped when the note or the selection changes. | N4, and the experiment below | The budget is tested (a long note is cut to the section). Adopt inserts at the cursor or replaces the selection only on the person's action, with undo. Failure and cancel leave the note alone. |
| N6 | Claude hand-off with goal and note | The package carries the goal and, if the person turns it on, the note (off by default). The questions and answers switches are removed. Managed copies follow the theme as in decision 0012. | N2 | The same checks as the PR 8 verification; an edit of the note after review invalidates the review. |

**Experiment before N4 and N5 (no product code).** On synthetic Japanese articles, run the article summary and the four actions with several prompts, and record the outputs and the time. The PdM reads them and decides whether the quality is enough. If not, narrow the actions or lean more on the Claude hand-off.

**Open items.** Whether to use the system Writing Tools for rewriting instead of our own "clearer" action. A Reeder-style fade of the sidebar (a later option). Whether the goal should be shown in the list of themes in the sidebar. Reading size (PR 9) and the note editor scale (PR 10) apply to the note editor once N2 exists; PR 10 starts after N2.

---

# Part 1d: The note beside the article (decision 0017)

Added on 2026-10-10 after the PdM tried the note face (N2 to N5) and proposed a different screen: the article list stays in the middle, the article is on the right, and the note opens beside the article as a panel with a calm, Claude-app-like AI area. [Decision 0017](../../decisions/0017-note-beside-the-article.md) records it and replaces the screen part of decision 0013 (point 4). The data (goal, note, migration) and the AI rules are unchanged.

| PR | Theme | Scope | Verification |
|---|---|---|---|
| L1 | The note as an inspector | The face switch, the reader's top bar and the 「原文｜AI要約」 switch are removed. The middle column is always the article list (a theme shows its articles, with the goal on top). The right column is the reader, and the note opens beside it as the standard inspector (toolbar button and `⌥⌘I`). Opening it folds the sidebar (N3's rule). The summary moves into the note panel as a button 「記事から要約する」. The note actions (N5) stay under the editor. [Detailed plan](2026-10-10-note-inspector.md) | The N3 to N5 behaviors still hold in the new layout (tests moved, not dropped). A real window check by the PdM. |
| L2 | The note looks like a document | The editor shows `#` lines as headings and list lines as lists (a styled display; the saved text is unchanged). Real WYSIWYG (bold, italic buttons, a new storage format) is not part of it. | IME stays intact; the saved text is byte for byte what was typed. |
| L3 | Experiment: review against the goal | No product code. On synthetic goals and notes, measure how useful an on-device "review the note against the goal" comment is (several prompts, time, quality). The PdM reads it. | Same as the N4/N5 experiment record. |
| L4 | The review panel | After L3, if the quality is enough: a quiet card area in the note panel (states: working, current, out of date, unavailable). Updated when the person asks, or, if they turn it on in Settings, once after typing stops (never when the note did not change). If the quality is not enough, the Claude hand-off (N6) is the place for a review. | The N4/N5 rules: a late or stale answer never shows; AI off means no call. |
| L5 | System Writing Tools | Turn on the system Writing Tools (proofread, rewrite, summarize) in the note editor where the Mac supports them. | Behavior on a real Mac; they are not under the app's control. |

Order: L1, then L2 and L3 in either order, then L4, then L5. N6 (the hand-off with the goal and the note) is independent of L1 to L5 and can go before or after them.

---

# 第2部 PR 3: テーマの保存基盤

**ブランチ**: `claude/theme-store`（`main`から切る）。**検証コマンド**（以降の各Taskで使う）: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`。

## ファイル構成

| ファイル | 責務 |
|---|---|
| `Sources/ReaderCore/Themes.swift`（新規） | `Theme`/`ThemeArticle`/`ThemeQuestion`、`QuestionLens`、`ThemeError`、`ReaderStore`のテーマ操作 |
| `Sources/ReaderCore/ReaderStore.swift`（変更） | スキーマ登録、取得結果の保持、索引の再構築（`private(set)`の保持と`private`の索引は同じファイル内で更新する） |
| `Tests/ReaderCoreTests/ThemeTests.swift`（新規） | テーマの試験一式 |
| `Tests/ReaderCoreTests/ReaderStoreTests.swift`（変更） | `failedRecoveryBlocksChangesUntilReloadSucceeds`に新しい変更経路を追加 |
| `docs/architecture.md`、`docs/verification/YYYY-MM-DD-theme-store.md`（新規） | 実装状況の更新と検証記録（YYYY-MM-DDは実行日） |

### Task 1: モデル・レンズ・テーマの作成／名前／理解／削除

**Files:**
- Create: `Sources/ReaderCore/Themes.swift`
- Modify: `Sources/ReaderCore/ReaderStore.swift`（プロパティ、`schema`、`reload()`、`refreshThemeIndex()`）
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: `ReaderStore`の`context`、`save()`、`reload()`、`reloadIfNeeded()`（既存）、`TestLibrary`（`Tests/ReaderCoreTests/ReadHistoryTests.swift`）。
- Produces（後続のTaskとPRが使う）:
  - `ThemeError: LocalizedError`（`missingName`、`missingTheme`、`missingArticle`、`missingQuestion`、`missingQuestionText`）
  - `QuestionLens: String, CaseIterable, Sendable`（`assumption`/`exception`/`condition`/`tradeoff`/`personal`/`custom`、`title: String`、`draft(themeName:) -> String`）
  - `Theme`（`id`、`name`、`understanding`、`createdAt`、`updatedAt`）
  - `ReaderStore.themes: [Theme]`（作成日時の昇順）、`theme(id:) -> Theme?`
  - `createTheme(name:at:) throws -> Theme`、`renameTheme(id:to:at:)`、`saveUnderstanding(themeID:text:at:)`、`deleteTheme(id:)`

- [ ] **Step 1: 失敗するテストを書く**

`Tests/ReaderCoreTests/ThemeTests.swift`を新規作成する。

```swift
import Foundation
import SwiftData
import Testing
@testable import ReaderCore

@MainActor struct ThemeTests {
    let at = Date(timeIntervalSince1970: 1_791_152_000)
    let day: TimeInterval = 86_400

    @Test func lensDraftsAreFixedAndNameTheTheme() {
        for lens in QuestionLens.allCases where lens != .custom {
            let draft = lens.draft(themeName: " 金利と家計 ")
            #expect(draft.contains("「金利と家計」") && draft.hasSuffix("。"))
        }
        #expect(QuestionLens.custom.draft(themeName: "x").isEmpty)
        #expect(Set(QuestionLens.allCases.map(\.title)).count == QuestionLens.allCases.count)
    }

    @Test func createTrimsNameAndRejectsBlank() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "  LLMの実用設計  ", at: at)
        #expect(theme.name == "LLMの実用設計" && theme.understanding.isEmpty)
        #expect(store.themes.map(\.id) == [theme.id] && store.theme(id: theme.id)?.id == theme.id)
        #expect(throws: ThemeError.self) { try store.createTheme(name: "   \n", at: at) }
        #expect(store.themes.count == 1)
    }

    @Test func renameAndUnderstandingPersistAcrossReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let theme = try store.createTheme(name: "金利", at: at)
            try store.renameTheme(id: theme.id, to: " 金利と家計 ", at: at.addingTimeInterval(10))
            try store.saveUnderstanding(themeID: theme.id, text: "いまの理解", at: at.addingTimeInterval(20))
            #expect(throws: ThemeError.self) { try store.renameTheme(id: theme.id, to: " ", at: at) }
            #expect(store.theme(id: theme.id)?.name == "金利と家計")
            return theme.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let theme = try #require(reopened.theme(id: id))
        #expect(theme.name == "金利と家計" && theme.understanding == "いまの理解")
        #expect(theme.createdAt == at && theme.updatedAt == at.addingTimeInterval(20))
    }

    @Test func unknownThemeIsANoOp() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let missing = UUID()
        try store.renameTheme(id: missing, to: "存在しない", at: at)
        try store.saveUnderstanding(themeID: missing, text: "書けない", at: at)
        try store.deleteTheme(id: missing)
        #expect(store.themes.isEmpty)
    }
}
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: FAIL（コンパイルエラー: `QuestionLens`・`ThemeError`・`createTheme`などが未定義）

- [ ] **Step 3: 最小の実装を書く**

`Sources/ReaderCore/Themes.swift`を新規作成する。

```swift
import Foundation
import SwiftData

public enum ThemeError: LocalizedError {
    case missingName, missingTheme, missingArticle, missingQuestion, missingQuestionText
    public var errorDescription: String? {
        switch self {
        case .missingName: "テーマの名前を入力してください。"
        case .missingTheme: "テーマが見つかりません。"
        case .missingArticle: "記事が見つかりません。"
        case .missingQuestion: "問いが見つかりません。"
        case .missingQuestionText: "問いの文を入力してください。"
        }
    }
}

/// Fixed lenses for starting a question. `draft` is the deterministic fallback; the on-device
/// assistant may later propose a more specific question, but this text must always work.
public enum QuestionLens: String, CaseIterable, Sendable {
    case assumption, exception, condition, tradeoff, personal, custom

    public var title: String {
        switch self {
        case .assumption: "前提を疑う"
        case .exception: "例外・反論"
        case .condition: "成り立つ条件"
        case .tradeoff: "トレードオフ"
        case .personal: "自分の場合"
        case .custom: "自由に書く"
        }
    }
    public func draft(themeName: String) -> String {
        let name = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .assumption: return "「\(name)」は、どんな前提の上に成り立っているか。その前提は本当に正しいか。"
        case .exception: return "「\(name)」に当てはまらない例外や、反対の立場からの反論はあるか。"
        case .condition: return "「\(name)」は、どんな条件のもとで成り立つか。条件が変わると何が変わるか。"
        case .tradeoff: return "「\(name)」で得るものと引き換えに、何を手放しているか。"
        case .personal: return "「\(name)」は、自分の場合どう当てはまるか。何を変え、何を変えないか。"
        case .custom: return ""
        }
    }
}

@Model public final class Theme {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var understanding: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(name: String, at: Date) {
        id = UUID(); self.name = name; understanding = ""; createdAt = at; updatedAt = at
    }
}

@Model public final class ThemeArticle {
    @Attribute(.unique) public var key: String
    public var themeID: UUID
    public var articleID: UUID
    public var summary: String
    public var addedAt: Date
    public init(themeID: UUID, articleID: UUID, summary: String, at: Date) {
        key = themeID.uuidString + ":" + articleID.uuidString
        self.themeID = themeID; self.articleID = articleID; self.summary = summary; addedAt = at
    }
}

@Model public final class ThemeQuestion {
    @Attribute(.unique) public var id: UUID
    public var themeID: UUID
    public var lensRaw: String
    public var text: String
    public var answer: String
    public var evidenceArticleIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
    public var lens: QuestionLens { QuestionLens(rawValue: lensRaw) ?? .custom }
    public var isAnswered: Bool { !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public init(themeID: UUID, lens: QuestionLens, text: String, at: Date) {
        id = UUID(); self.themeID = themeID; lensRaw = lens.rawValue; self.text = text
        answer = ""; evidenceArticleIDs = []; createdAt = at; updatedAt = at
    }
}

extension ReaderStore {
    public func theme(id: UUID) -> Theme? { themes.first { $0.id == id } }

    @discardableResult public func createTheme(name: String, at: Date) throws -> Theme {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        let theme = Theme(name: name, at: at)
        context.insert(theme)
        try save(); try reload()
        return theme
    }
    public func renameTheme(id: UUID, to name: String, at: Date) throws {
        try reloadIfNeeded()
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThemeError.missingName }
        guard let theme = theme(id: id), theme.name != name else { return }
        theme.name = name; theme.updatedAt = at
        try save(); try reload()
    }
    /// Typing path: saves without reloading so the editor is not rebuilt on every change.
    public func saveUnderstanding(themeID: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID), theme.understanding != text else { return }
        theme.understanding = text; theme.updatedAt = at
        try save()
    }
    public func deleteTheme(id: UUID) throws {
        try reloadIfNeeded()
        guard let theme = theme(id: id) else { return }
        for link in themeArticles where link.themeID == id { context.delete(link) }
        for question in themeQuestions where question.themeID == id { context.delete(question) }
        context.delete(theme)
        try save(); try reload()
    }
}
```

`Sources/ReaderCore/ReaderStore.swift`を変更する。

(a) 既存の`public private(set) var scraps: [NoteScrap] = []`の直後に追加:

```swift
    public private(set) var themes: [Theme] = []
    public private(set) var themeArticles: [ThemeArticle] = []
    public private(set) var themeQuestions: [ThemeQuestion] = []
    @ObservationIgnored var themeMembers: [UUID: Set<UUID>] = [:]
    @ObservationIgnored var articleThemeIDs: [UUID: Set<UUID>] = [:]
```

(b) `schema`の配列の末尾に`Theme.self, ThemeArticle.self, ThemeQuestion.self`を追加:

```swift
    public static var schema: Schema {
        Schema([Feed.self, Article.self, ContentSnapshot.self, FeedMembership.self, WeeklyPeriod.self,
                WeeklyNote.self, NoteSource.self, ReaderSettings.self, DailyNote.self, NoteScrap.self,
                Theme.self, ThemeArticle.self, ThemeQuestion.self])
    }
```

(c) `reload()`の`scraps = try context.fetch(...)`の直後に追加:

```swift
        themes = try context.fetch(FetchDescriptor<Theme>(sortBy: [SortDescriptor(\.createdAt)]))
        themeArticles = try context.fetch(FetchDescriptor<ThemeArticle>(sortBy: [SortDescriptor(\.addedAt)]))
        themeQuestions = try context.fetch(FetchDescriptor<ThemeQuestion>(sortBy: [SortDescriptor(\.createdAt)]))
```

(d) `reload()`の`refreshStarIndex()`の直後（`needsReload = false`の前）に`refreshThemeIndex()`の呼び出しを追加し、`refreshStarIndex()`の定義の隣に関数を追加:

```swift
        refreshThemeIndex()
```

```swift
    private func refreshThemeIndex() {
        themeMembers = [:]; articleThemeIDs = [:]
        for link in themeArticles {
            themeMembers[link.themeID, default: []].insert(link.articleID)
            articleThemeIDs[link.articleID, default: []].insert(link.themeID)
        }
    }
```

- [ ] **Step 4: 成功を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: PASS（4件）

- [ ] **Step 5: 既存のテストが壊れていないことを確認してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS（既存134件＋新規4件）

```bash
git add Sources/ReaderCore/Themes.swift Sources/ReaderCore/ReaderStore.swift Tests/ReaderCoreTests/ThemeTests.swift
git commit -m "feat: テーマの保存モデルと作成・名前・理解・削除を追加する"
```

### Task 2: 記事のテーマへの追加と取り外し、未整理のStar

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift`（`ReaderStore`の拡張に追記）
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: Task 1の`Theme`・`ThemeArticle`・`ThemeError`、`ReaderStore.themeMembers`/`articleThemeIDs`、既存の`isContentAvailable(_:at:)`、`starredIDs`、`starCount`、`articleIDs`。
- Produces:
  - `addArticle(_ articleID: UUID, toTheme themeID: UUID, at: Date) throws -> ThemeArticle`（`@discardableResult`）
  - `removeArticle(_ articleID: UUID, fromTheme themeID: UUID, at: Date) throws`
  - `themeArticleIDs(themeID:) -> [UUID]`（全記事の並び順）、`themeArticleCount(themeID:) -> Int`、`themeIDs(containing:) -> [UUID]`（`themes`の並び順）
  - `unfiledStarredArticleIDs(keeping: UUID?) -> [UUID]`、`unfiledStarCount: Int`

- [ ] **Step 1: 失敗するテストを書く**

`ThemeTests`の末尾（最後の`}`の前）に追加する。

```swift
    @Test func addingSnapshotsSummaryAndRepeatKeepsTheRecord() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let theme = try store.createTheme(name: "A", at: at)
        let first = try store.addArticle(article.id, toTheme: theme.id, at: at)
        article.summary = "更新後の要約"
        let repeated = try store.addArticle(article.id, toTheme: theme.id, at: at.addingTimeInterval(30))
        #expect(first.key == repeated.key && store.themeArticles.count == 1)
        #expect(repeated.summary == "合成RSS要約" && repeated.addedAt == at)
        #expect(store.themeArticleIDs(themeID: theme.id) == [article.id])
        #expect(store.themeArticleCount(themeID: theme.id) == 1)
    }

    @Test func missingOrExpiredSummaryStoresAnEmptySummary() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = ""
        let theme = try store.createTheme(name: "A", at: at)
        let empty = try store.addArticle(article.id, toTheme: theme.id, at: at)
        #expect(empty.summary.isEmpty)
        let other = store.articles[1]
        let expired = try store.addArticle(other.id, toTheme: theme.id, at: at.addingTimeInterval(31 * day))
        #expect(expired.summary.isEmpty && store.article(id: other.id)?.title == other.title)
    }

    @Test func recordSurvivesExpiryUnsubscribeAndReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]; article.summary = "合成RSS要約"
        let (id, title, url) = (article.id, article.title, article.originalURL)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(id, toTheme: theme.id, at: at)
        let later = at.addingTimeInterval(31 * day)
        try store.purgeExpired(at: later)
        for feed in store.feeds { try store.unsubscribe(feed) }
        #expect(store.article(id: id)?.summary.isEmpty == true)
        let reopened = try ReaderStore(url: library.url, now: later)
        let link = try #require(reopened.themeArticles.first)
        #expect(link.summary == "合成RSS要約" && link.articleID == id)
        #expect(reopened.article(id: id)?.title == title && reopened.article(id: id)?.originalURL == url)
    }

    @Test func starAndThemeAreIndependent() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let a = store.articles[0], b = store.articles[1]
        try store.setStar(articleID: a.id, isStarred: true, at: at)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(a.id, toTheme: theme.id, at: at)
        try store.addArticle(b.id, toTheme: theme.id, at: at)
        #expect(a.starredAt == at && b.starredAt == nil)
        #expect(a.firstReadAt == nil && b.firstReadAt == nil && !a.isRead && !b.isRead)
        try store.setStar(articleID: a.id, isStarred: false, at: at)
        #expect(Set(store.themeArticleIDs(themeID: theme.id)) == [a.id, b.id])
        #expect(store.themeIDs(containing: a.id) == [theme.id])
    }

    @Test func unfiledStarsAreStarredArticlesInNoTheme() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let ids = store.articles.map(\.id)
        for id in ids.prefix(3) { try store.setStar(articleID: id, isStarred: true, at: at) }
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == Array(ids.prefix(3)) && store.unfiledStarCount == 3)
        let theme = try store.createTheme(name: "A", at: at)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[1], ids[2]])
        try store.setStar(articleID: ids[1], isStarred: false, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: ids[1]) == [ids[1], ids[2]])
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[2]])
        try store.removeArticle(ids[0], fromTheme: theme.id, at: at)
        #expect(store.unfiledStarredArticleIDs(keeping: nil) == [ids[0], ids[2]])
    }

    @Test func oneArticleCanBelongToSeveralThemes() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        try store.addArticle(article.id, toTheme: second.id, at: at)
        try store.addArticle(article.id, toTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [first.id, second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeIDs(containing: article.id) == [second.id])
        try store.removeArticle(article.id, fromTheme: first.id, at: at)
        #expect(store.themeArticleCount(themeID: first.id) == 0 && store.themeArticleCount(themeID: second.id) == 1)
    }

    @Test func unknownIDsThrowWithoutChangingData() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "A", at: at)
        #expect(throws: ThemeError.self) { try store.addArticle(UUID(), toTheme: theme.id, at: at) }
        #expect(throws: ThemeError.self) { try store.addArticle(store.articles[0].id, toTheme: UUID(), at: at) }
        #expect(store.themeArticles.isEmpty)
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: FAIL（コンパイルエラー: `addArticle`・`unfiledStarredArticleIDs`などが未定義）

- [ ] **Step 3: 最小の実装を書く**

`Themes.swift`の`extension ReaderStore`の末尾（`deleteTheme`の後）に追加する。

```swift
    @discardableResult public func addArticle(_ articleID: UUID, toTheme themeID: UUID, at: Date) throws -> ThemeArticle {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        guard let article = article(id: articleID) else { throw ThemeError.missingArticle }
        if themeMembers[themeID]?.contains(articleID) == true,
           let existing = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) {
            return existing
        }
        let summary = isContentAvailable(article, at: at) ? article.summary.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let link = ThemeArticle(themeID: themeID, articleID: articleID, summary: summary, at: at)
        context.insert(link)
        theme.updatedAt = at
        try save(); try reload()
        return link
    }
    public func removeArticle(_ articleID: UUID, fromTheme themeID: UUID, at: Date) throws {
        try reloadIfNeeded()
        guard let link = themeArticles.first(where: { $0.themeID == themeID && $0.articleID == articleID }) else { return }
        for question in themeQuestions where question.themeID == themeID && question.evidenceArticleIDs.contains(articleID) {
            question.evidenceArticleIDs.removeAll { $0 == articleID }
            question.updatedAt = at
        }
        context.delete(link)
        theme(id: themeID)?.updatedAt = at
        try save(); try reload()
    }

    public func themeArticleIDs(themeID: UUID) -> [UUID] {
        _ = themeArticles
        guard let members = themeMembers[themeID], !members.isEmpty else { return [] }
        return articleIDs.filter { members.contains($0) }
    }
    public func themeArticleCount(themeID: UUID) -> Int {
        _ = themeArticles
        return themeMembers[themeID]?.count ?? 0
    }
    public func themeIDs(containing articleID: UUID) -> [UUID] {
        _ = themeArticles
        guard let ids = articleThemeIDs[articleID] else { return [] }
        return themes.map(\.id).filter { ids.contains($0) }
    }
    /// Starred articles in no theme. `keeping` keeps the current selection visible after it leaves the inbox.
    public func unfiledStarredArticleIDs(keeping: UUID?) -> [UUID] {
        _ = starCount; _ = themeArticles
        return articleIDs.filter { (starredIDs.contains($0) && articleThemeIDs[$0] == nil) || $0 == keeping }
    }
    public var unfiledStarCount: Int { unfiledStarredArticleIDs(keeping: nil).count }
```

- [ ] **Step 4: 成功を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: PASS（11件）

- [ ] **Step 5: コミットする**

```bash
git add Sources/ReaderCore/Themes.swift Tests/ReaderCoreTests/ThemeTests.swift
git commit -m "feat: 記事のテーマへの追加・取り外しと未整理のStarを追加する"
```

### Task 3: 問い・答え・根拠

**Files:**
- Modify: `Sources/ReaderCore/Themes.swift`
- Test: `Tests/ReaderCoreTests/ThemeTests.swift`

**Interfaces:**
- Consumes: Task 1〜2の`ThemeQuestion`・`QuestionLens`・`addArticle`・`removeArticle`・`themeMembers`。
- Produces:
  - `addQuestion(themeID:lens:text:at:) throws -> ThemeQuestion`（`@discardableResult`）、`questions(themeID:) -> [ThemeQuestion]`（作成日時の昇順）
  - `updateQuestion(id:text:at:)`、`saveAnswer(questionID:answer:at:)`、`setEvidence(questionID:articleIDs:at:)`、`deleteQuestion(id:)`
  - 振る舞い: 問いの文は空白除去し、空は`missingQuestionText`。答えは入力どおり保存し、`isAnswered`は空白除去後の非空。根拠はそのテーマの記事だけを、重複なし・渡された順に保存する。

- [ ] **Step 1: 失敗するテストを書く**

```swift
    @Test func questionsKeepAnswersAndDeriveTheAnsweredState() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let theme = try store.createTheme(name: "A", at: at)
        let draft = QuestionLens.assumption.draft(themeName: "A")
        let question = try store.addQuestion(themeID: theme.id, lens: .assumption, text: " \(draft) ", at: at)
        #expect(question.lens == .assumption && question.text == draft && !question.isAnswered)
        try store.saveAnswer(questionID: question.id, answer: "自分の答え", at: at.addingTimeInterval(5))
        #expect(question.isAnswered && question.updatedAt == at.addingTimeInterval(5))
        try store.saveAnswer(questionID: question.id, answer: "  \n", at: at.addingTimeInterval(6))
        #expect(!question.isAnswered)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: theme.id, lens: .custom, text: "  ", at: at) }
        let second = try store.addQuestion(themeID: theme.id, lens: .custom, text: "自分で立てた問い", at: at.addingTimeInterval(1))
        #expect(store.questions(themeID: theme.id).map(\.id) == [question.id, second.id])
        try store.updateQuestion(id: second.id, text: " 言い換えた問い ", at: at.addingTimeInterval(2))
        #expect(second.text == "言い換えた問い")
        #expect(throws: ThemeError.self) { try store.updateQuestion(id: second.id, text: " ", at: at) }
        #expect(second.text == "言い換えた問い")
        try store.deleteQuestion(id: second.id)
        #expect(store.questions(themeID: theme.id).map(\.id) == [question.id])
    }

    @Test func unknownThemeOrQuestionIsRejectedOrIgnored() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        #expect(throws: ThemeError.self) { try store.addQuestion(themeID: UUID(), lens: .custom, text: "問い", at: at) }
        try store.saveAnswer(questionID: UUID(), answer: "書けない", at: at)
        try store.setEvidence(questionID: UUID(), articleIDs: [], at: at)
        try store.deleteQuestion(id: UUID())
        #expect(store.themeQuestions.isEmpty)
    }

    @Test func evidenceMustBeThemeMembersAndRemovingAnArticleKeepsTheAnswer() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let id = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let a = store.articles[0], b = store.articles[1], outsider = store.articles[2]
            let theme = try store.createTheme(name: "A", at: at)
            try store.addArticle(a.id, toTheme: theme.id, at: at)
            try store.addArticle(b.id, toTheme: theme.id, at: at)
            let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
            try store.setEvidence(questionID: question.id, articleIDs: [b.id, outsider.id, a.id, b.id], at: at)
            #expect(question.evidenceArticleIDs == [b.id, a.id])
            try store.saveAnswer(questionID: question.id, answer: "答え", at: at)
            try store.removeArticle(b.id, fromTheme: theme.id, at: at.addingTimeInterval(5))
            #expect(question.evidenceArticleIDs == [a.id] && question.answer == "答え")
            return question.id
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        let question = try #require(reopened.themeQuestions.first { $0.id == id })
        #expect(question.evidenceArticleIDs.count == 1 && question.answer == "答え")
    }

    @Test func deletingAThemeRemovesOnlyItsOwnRecords() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
        let article = store.articles[0]
        try store.setStar(articleID: article.id, isStarred: true, at: at)
        let first = try store.createTheme(name: "A", at: at)
        let second = try store.createTheme(name: "B", at: at.addingTimeInterval(1))
        for theme in [first, second] {
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
        }
        try store.deleteTheme(id: first.id)
        #expect(store.themes.map(\.id) == [second.id])
        #expect(store.themeArticles.map(\.themeID) == [second.id] && store.themeQuestions.map(\.themeID) == [second.id])
        #expect(store.article(id: article.id)?.starredAt == at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themes.map(\.id) == [second.id] && reopened.themeQuestions.count == 1)
    }
```

- [ ] **Step 2: 失敗を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: FAIL（コンパイルエラー: `addQuestion`・`saveAnswer`・`setEvidence`などが未定義）

- [ ] **Step 3: 最小の実装を書く**

`Themes.swift`の`extension ReaderStore`の末尾に追加する。

```swift
    @discardableResult public func addQuestion(themeID: UUID, lens: QuestionLens, text: String, at: Date) throws -> ThemeQuestion {
        try reloadIfNeeded()
        guard let theme = theme(id: themeID) else { throw ThemeError.missingTheme }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ThemeError.missingQuestionText }
        let question = ThemeQuestion(themeID: themeID, lens: lens, text: text, at: at)
        context.insert(question)
        theme.updatedAt = at
        try save(); try reload()
        return question
    }
    public func questions(themeID: UUID) -> [ThemeQuestion] {
        themeQuestions.filter { $0.themeID == themeID }.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }
    public func updateQuestion(id: UUID, text: String, at: Date) throws {
        try reloadIfNeeded()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ThemeError.missingQuestionText }
        guard let question = themeQuestions.first(where: { $0.id == id }), question.text != text else { return }
        question.text = text; question.updatedAt = at
        try save()
    }
    /// Typing path: saves without reloading. The answer is stored exactly as typed.
    public func saveAnswer(questionID: UUID, answer: String, at: Date) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == questionID }), question.answer != answer else { return }
        question.answer = answer; question.updatedAt = at
        try save()
    }
    public func setEvidence(questionID: UUID, articleIDs: [UUID], at: Date) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == questionID }) else { return }
        let members = themeMembers[question.themeID] ?? []
        var seen = Set<UUID>()
        let evidence = articleIDs.filter { members.contains($0) && seen.insert($0).inserted }
        guard evidence != question.evidenceArticleIDs else { return }
        question.evidenceArticleIDs = evidence; question.updatedAt = at
        try save()
    }
    public func deleteQuestion(id: UUID) throws {
        try reloadIfNeeded()
        guard let question = themeQuestions.first(where: { $0.id == id }) else { return }
        context.delete(question)
        try save(); try reload()
    }
```

- [ ] **Step 4: 成功を確認する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: PASS（15件）

- [ ] **Step 5: コミットする**

```bash
git add Sources/ReaderCore/Themes.swift Tests/ReaderCoreTests/ThemeTests.swift
git commit -m "feat: テーマの問い・答え・根拠の記事を追加する"
```

### Task 4: 保存／再読み込みの失敗注入と全体の再open

**Files:**
- Modify: `Tests/ReaderCoreTests/ThemeTests.swift`
- Modify: `Tests/ReaderCoreTests/ReaderStoreTests.swift`（`failedRecoveryBlocksChangesUntilReloadSucceeds`）

**Interfaces:**
- Consumes: Task 1〜3のすべての変更経路。`ReaderStore.init(container:seedDemo:now:saveHook:reloadHook:)`（既存、`@testable`で利用）。
- Produces: なし（試験のみ。不具合が見つかった場合は、その実装をこのTaskで直す）。

- [ ] **Step 1: 保存失敗の試験を書く**

`ThemeTests`の末尾に追加する。

```swift
    final class SaveGate { var failNext = false }

    private func gatedStore(_ library: TestLibrary, _ gate: SaveGate) throws -> ReaderStore {
        let schema = ReaderStore.schema
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Reader", schema: schema, url: library.url, cloudKitDatabase: .none)])
        return try ReaderStore(container: container, seedDemo: true, now: at, saveHook: {
            if gate.failNext { gate.failNext = false; throw CocoaError(.fileWriteUnknown) }
        })
    }

    @Test func failedSaveLeavesNoPartialThemeStateAndCanBeRetried() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let gate = SaveGate()
        let store = try gatedStore(library, gate)
        let ids = store.articles.map(\.id)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.createTheme(name: "失敗", at: at) }
        #expect(store.themes.isEmpty)
        let theme = try store.createTheme(name: "成功", at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.addArticle(ids[0], toTheme: theme.id, at: at) }
        #expect(store.themeArticles.isEmpty && store.themeArticleCount(themeID: theme.id) == 0)
        try store.addArticle(ids[0], toTheme: theme.id, at: at)
        try store.addArticle(ids[1], toTheme: theme.id, at: at)

        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "問い", at: at)
        try store.setEvidence(questionID: question.id, articleIDs: [ids[0], ids[1]], at: at)

        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveAnswer(questionID: question.id, answer: "失われる答え", at: at) }
        #expect(store.themeQuestions.first { $0.id == question.id }?.answer == "")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.saveUnderstanding(themeID: theme.id, text: "失われる理解", at: at) }
        #expect(store.theme(id: theme.id)?.understanding == "")
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.setEvidence(questionID: question.id, articleIDs: [ids[0]], at: at) }
        #expect(store.themeQuestions.first { $0.id == question.id }?.evidenceArticleIDs == [ids[0], ids[1]])
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.removeArticle(ids[1], fromTheme: theme.id, at: at) }
        #expect(store.themeArticleCount(themeID: theme.id) == 2)
        gate.failNext = true
        #expect(throws: (any Error).self) { try store.deleteTheme(id: theme.id) }
        #expect(store.themes.count == 1 && store.themeArticles.count == 2 && store.themeQuestions.count == 1)

        try store.saveAnswer(questionID: question.id, answer: "再試行した答え", at: at)
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.themeQuestions.first?.answer == "再試行した答え" && reopened.themeArticles.count == 2)
    }

    @Test func everythingSurvivesAReopen() throws {
        let library = try TestLibrary(); defer { library.cleanup() }
        let (themeID, questionID, articleID) = try autoreleasepool {
            let store = try ReaderStore(url: library.url, seedDemo: true, now: at)
            let article = store.articles[0]; article.summary = "合成RSS要約"
            let theme = try store.createTheme(name: "A", at: at)
            try store.saveUnderstanding(themeID: theme.id, text: "いまの理解", at: at)
            try store.addArticle(article.id, toTheme: theme.id, at: at)
            let question = try store.addQuestion(themeID: theme.id, lens: .tradeoff, text: "問い", at: at)
            try store.saveAnswer(questionID: question.id, answer: "答え", at: at)
            try store.setEvidence(questionID: question.id, articleIDs: [article.id], at: at)
            return (theme.id, question.id, article.id)
        }
        let reopened = try ReaderStore(url: library.url, now: at)
        #expect(reopened.theme(id: themeID)?.understanding == "いまの理解")
        let link = try #require(reopened.themeArticles.first)
        #expect(link.articleID == articleID && link.summary == "合成RSS要約")
        let question = try #require(reopened.themeQuestions.first { $0.id == questionID })
        #expect(question.lens == .tradeoff && question.answer == "答え" && question.evidenceArticleIDs == [articleID])
        #expect(reopened.themeArticleIDs(themeID: themeID) == [articleID])
    }
```

- [ ] **Step 2: 実行する**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter ThemeTests`
Expected: PASS（17件）。失敗した場合は、失敗した操作の実装（`save()`の前に画面へ見える状態を変えていないか、`reloadIfNeeded()`が先頭にあるか）を直し、このStepを繰り返す。**新しい経路の失敗試験を実装の追従だけで通さず、失敗を一度確認する**（例: `addArticle`の`try save()`の前に`themeMembers`を更新する実装を一時的に入れて失敗を確認し、元に戻す）。

- [ ] **Step 3: 回復試験に新しい変更経路を追加する**

`Tests/ReaderCoreTests/ReaderStoreTests.swift`の`failedRecoveryBlocksChangesUntilReloadSucceeds`を変更する。

(a) `let scrap = try store.scrap(...)`の直後に追加:

```swift
        let theme = try store.createTheme(name: "保存済み", at: at)
        try store.addArticle(article.id, toTheme: theme.id, at: at)
        let question = try store.addQuestion(themeID: theme.id, lens: .custom, text: "保存済みの問い", at: at)
```

(b) `changes`配列の`{ try store.deleteDailyNote(id: scrap.noteID) },`の直後に追加:

```swift
            { _ = try store.createTheme(name: "変更", at: at) },
            { try store.renameTheme(id: theme.id, to: "変更", at: at) },
            { try store.saveUnderstanding(themeID: theme.id, text: "捨ててはいけない変更", at: at) },
            { _ = try store.addArticle(article.id, toTheme: theme.id, at: at) },
            { try store.removeArticle(article.id, fromTheme: theme.id, at: at) },
            { _ = try store.addQuestion(themeID: theme.id, lens: .custom, text: "変更", at: at) },
            { try store.updateQuestion(id: question.id, text: "変更", at: at) },
            { try store.saveAnswer(questionID: question.id, answer: "捨ててはいけない変更", at: at) },
            { try store.setEvidence(questionID: question.id, articleIDs: [article.id], at: at) },
            { try store.deleteQuestion(id: question.id) },
            { try store.deleteTheme(id: theme.id) },
```

(c) `failReload = false`の後、`let reopened = ...`の前に追加し、`reopened`の検証に1行足す:

```swift
        try store.saveUnderstanding(themeID: theme.id, text: "再試行した理解", at: at)
```

```swift
        #expect(reopened.theme(id: theme.id)?.understanding == "再試行した理解" && reopened.themeQuestions.first?.answer == "")
```

- [ ] **Step 4: 全体の成功を確認してコミットする**

Run: `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`
Expected: PASS（既存134件＋新規17件）

```bash
git add Tests/ReaderCoreTests/ThemeTests.swift Tests/ReaderCoreTests/ReaderStoreTests.swift
git commit -m "test: テーマの保存失敗・再読み込み失敗・再openの試験を追加する"
```

### Task 5: 旧ベータのストアの再open・文書・検証記録・レビュー依頼

**Files:**
- Modify: `docs/architecture.md`（§2.1の導入文）
- Create: `docs/verification/YYYY-MM-DD-theme-store.md`（YYYY-MM-DDは実行日）

**Interfaces:**
- Consumes: Task 1〜4の成果物、既存の`scripts/prepare-v1-store-fixture.sh`と`V1StoreUpgradeTests`（`FEEEDER_V1_FIXTURE_DIR`が未指定ならスキップ）。
- Produces: PR 3の検証証拠。

- [ ] **Step 1: 配布済みベータ（beta.2）のストアを新スキーマで開く**

モデルを追加したスキーマで、配布済みベータが作ったストアが2回開き、既存データが残ることを確認する。基準commit `f9db83b49a82947a7031ddf874bc94fcb91ef89d`はbeta.2で、スクリプトが許可する固定のcommit。fixtureは存在しない専用ディレクトリに作る。このスクリプトは基準commitのコードをビルドするため、固定版のSwiftSoupを取得する（依存の追加ではない）。

```bash
bash scripts/prepare-v1-store-fixture.sh /private/tmp/feeeder-beta2-fixture-themes f9db83b49a82947a7031ddf874bc94fcb91ef89d
FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-beta2-fixture-themes swift test --scratch-path /private/tmp/feeeder-dogfooding-build --filter V1StoreUpgradeTests
```

Expected: PASS。ネットワークまたはsandboxで基準commitのビルドができない場合は、NOT_RUNとして理由を検証記録に書く（PASSにしない）。失敗した場合は、**実装を直す前に原因を記録し、本人に相談する**（旧ストアを自動削除・再作成しない）。

- [ ] **Step 2: Releaseビルドと全体の検査**

```bash
bash scripts/build-app.sh release
swift test --scratch-path /private/tmp/feeeder-dogfooding-build
git diff --check
```

Expected: すべて成功。画面は変えていないので、合成インスタンスでの操作は不要（PRにその旨を書く）。

- [ ] **Step 3: Architectureの実装状況を更新する**

`docs/architecture.md`の§2.1の導入文を、次の趣旨に更新する（実行時点の文面を読んで、その文の事実だけを直す）。

```markdown
保存モデルは、現行ベータの10モデルから次の8モデルへ置き換える（[決定0008](decisions/0008-theme-centered-notes.md)）。実装は段階的で、`Theme`・`ThemeArticle`・`ThemeQuestion`は追加済み（画面は未接続）。置き換えが終わるまで現行の`DailyNote`・`NoteScrap`・`WeeklyPeriod`・`WeeklyNote`・`NoteSource`が残る。
```

- [ ] **Step 4: 検証記録を書く**

`docs/verification/YYYY-MM-DD-theme-store.md`に、対象commit、環境（OS・Swift・機種）、実行したコマンドと結果（PASS／FAIL／NOT_RUN）、テスト件数、旧ベータストアの再open結果、失敗注入で確認した操作の一覧、**未検証**（画面・IME・VoiceOver・実データでの性能・数千件規模の索引のコスト）、本人のライブラリを使っていないことを書く。失敗を一度確認したStep（Task 4 Step 2）の結果も書く。

- [ ] **Step 5: 独立レビューを依頼する**

保存モデル・失敗復旧の変更なので、`AGENTS.md`の完了条件8に従い、**固定commit**に対して`docs/review-checklist.md`の観点でレビューを依頼する（`superpowers:requesting-code-review`）。レビュー担当は`git diff origin/main...HEAD`を読み、アプリの起動・実機試験は行わない。指摘があれば、再現するテストをREDで確認してから直し、再レビューの対象commitを更新する。

- [ ] **Step 6: コミットし、PRの準備をする**

```bash
git add docs/architecture.md docs/verification
git commit -m "docs: テーマ保存基盤の検証記録を追加する"
```

PR本文は`.github/pull_request_template.md`に従う。**含めないもの**: 画面、`t`キー、旧モデルの削除、AI、Claude連携。**未検証**: 上のStep 4の一覧。pushとPR作成は本人の許可を得てから行う。
