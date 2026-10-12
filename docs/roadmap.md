# Roadmap

The order of work from the V1 simplification ([decision 0019](decisions/0019-v1-simplification-notes.md)) to the beta. The value and the questions to ask when in doubt are in the [vision](vision.md); the product is in the [specification](specification.md). Older plans, records and roadmaps were removed from the working tree by the prune PR; they are in Git history.

## How a stage runs

Each stage has a short plan PR first (scope, files and tests it touches, the decisions it needs). Merging the plan approves it. Then one implementation PR per stage, with failing tests first, one independent review of a fixed commit when the change is risky, and the specification, the architecture and the user guides updated for what changed. A plan lives in `docs/superpowers/plans/` only until its stage is merged; then delete it (Git keeps it).

## Stages

| Stage | What | Needs from the PdM |
|---|---|---|
| S1 | **Done** (two PRs, S1a and S1b). Notes: rename; no goal and no name (title from the first line); remove the suggestions, the note actions, the summary card in the panel and the article hand-off; the panel opens at once, is resizable and remembers its width; the sidebar folds only when the window is narrow. The picker and `t` stay as the only way to link an article until S2. | Merging the plan. |
| S2 | **Done.** 「ノートに要約を送る」 (button, menu, `n`), automatic links and removal, summary settings, the AI mark and 「取り消す」. The picker and `t` are removed. | Plan approved in PR #69. |
| S3 | **Done.** Note-panel share menu, exact Markdown copy/export, and note-only Claude review. | Plan approved in PR #71. |
| S4 | Done: unused note helpers, article package paths and managed-copy source metadata removed; note bytes and stored schema preserved. [Decision](decisions/0022-note-only-package-clean-up.md), [verification](verification/s4-clean-up.md). | Plan approved in [PR #74](https://github.com/ojiman/unagi-reader/pull/74). |
| S5 | **Done.** Light styling of headings and lists in the editor (display only; the text never changes). | Plan approved in PR #72. |

## Decision 0049 (one note, no AI of its own), in order

Each is its own pull request, deletions first. See [decision 0049](decisions/0049-one-note-and-no-ai-of-its-own.md).

1. **Done (#115).** The hand-off to Claude is removed; 「Markdownをコピー」 stays.
2. **Done (#116).** The on-device summary and the send to a note are removed.
3. **Done (#118).** One note: the note list, rename, delete, undo and the records of articles in a note are removed; the first start keeps the note edited last. The note opens from any screen with the toolbar button or `⌥⌘I`, as the panel it already was.
4. **Done (this stage).** The new layout: `n`, the move of about 0.3 s (the sidebar and the list fold, the note comes in from the right), and the 「一覧」 button. Next: the real-device check.

## After S3 (the rename to Unagi Reader is done: [decision 0023](decisions/0023-rename-to-unagi-reader.md))

- **Real-device check (the PdM).** Read, write in the note beside the articles, copy the note into another AI (decision 0049 removed the hand-off to Claude), Japanese input in the note, a narrow window, and a long dogfooding week. Bugs found here come before any polish.
- **Beta preparation.** The PdM approves `docs/specification.md` (its header still says approval is needed). A fresh acceptance run of the reading features (the older acceptance records were removed, because they described old commits). A check that the user guides match the app. Signing and distribution only on the PdM's instruction.

## Candidates (not scheduled)

- **Reading size.** One shared size in Appearance (Small / Standard / Large / Extra Large = 14 / 16 / 18 / 20 pt, default Standard) and View-menu commands. A probe showed that a separate update path keeps the top visible line in place across 36 synthetic cases, and that the update time grows with the article (about 10 to 20 ms at 7,800 characters, about 0.2 to 0.35 s at 156,000). The probe code is in Git history (PR #28). Open: a time budget (the proposal: finish within about 100 ms up to about 50,000 characters, above that apply once after the key is released), and how it feels on the device.
- **Note editor size.** The same scale for the note editor. Needs a real Japanese input check: the update waits while text is being composed.

## Not planned

Goals and learning plans; AI suggestions of notes; AI editing of the note; note folders, tags and search (after V1); system sharing services (after V1); sync and accounts; a settings framework; key remapping; a language setting before the public release is planned but has no stage yet.

## Prune before 1.0

The first pass was done by the prune PR (plans, records for removed features). Before 1.0: a second pass over the verification records that remain, the decision records and the user guides, run as an audit; the PdM approves what to cut.
