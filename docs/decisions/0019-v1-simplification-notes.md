# 0019 V1 simplification: notes replace themes

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) asked for the simpler product after dogfooding the N6 build, and answered the open questions in chat (summary settings, no note actions, Claude kept, old data may be deleted, the Product Owner's defaults for the editor). The Product Owner (the agent) proposed the points marked "proposed"; merging this PR approves them.
- Replaces: the theme model of [0008](0008-theme-centered-notes.md) and [0013](0013-goal-and-note-for-themes.md) (goal, theme-recorded articles, theme picker, theme suggestions), [0016](0016-note-actions.md) (note actions), [0017](0017-note-beside-the-article.md) (the note as an inspector next to the article).
- Refines: [0012](0012-claude-handoff-from-themes.md) and [0018](0018-handoff-goal-note.md) (the hand-off becomes a function of a note), [0015](0015-article-summary-details.md) (the summary goes straight to a note).

## Background

Dogfooding showed that the theme, the goal, the recorded articles, the two panes, the AI suggestions, the note actions and the review made too many ideas for one reader. Three real problems came up in one session: the note did not open when a theme was selected, the summary card pushed the window out of view, and the panel was narrow. The owner decided that the minimum that still gives the Unagi Reader experience is: read, send an AI summary to a note, write in the note, and ask Claude about the note.

## Decision

1. **A note replaces a theme.** The word 「ノート」 (Note) is used in the app, the spec and the docs; 「テーマ」 is gone. A note is one Markdown text document; there are many notes. There is no goal and no separate name: the title is the first non-empty line with leading `#` marks and spaces removed (an empty note is shown as 「新規ノート」). *(Title rule proposed.)*
2. **No link between an article and a note.** A note does not record articles. Nothing is stored with a note except its text. The Star stays as the "read later" mark, independent of notes. The "unsorted Star" area, the theme picker, the `t` key and the on-device suggestions of nearby themes, groupings and theme names are removed.
3. **Layout like Mac Notes.** The sidebar has Feeds, 「ノート」 (with the count) and the subscriptions. Selecting 「ノート」 shows the list of notes (most recently edited first) in the middle column and the editor in the right column. There is no inspector next to the article. *(Proposed.)*
4. **The editor is a plain Markdown text editor** with autosave on every keystroke, undo, the system text services, and Japanese input that is never disturbed. It does not rewrite what the person types. Light styling of `#` headings and `-` lists is wanted but does not block V1. Tables, checklists and live preview are after V1. The editor has no AI assist; assist for editing may come later if needed.
5. **Sending a summary to a note.** The article toolbar has one button, 「ノートに要約を送る」 (key `n`), in the place of 「テーマに入れる」. It works for any article. It opens a short menu: 「新しいノート」 and the most recently edited notes. Choosing an entry sends at once; the person can keep reading. A message shows the progress, then the result (「『…』に送りました」 with 「開く」), and a failure with the reason. A request is tied to the article and the note chosen when it was made. *(Proposed.)*
   - New note: the text starts with `# ` and the article title, then the summary, then the source line. Existing note: a blank line, the summary, the source line, at the end.
   - Source line: `出典: タイトル <URL>`, as in decision 0015. When the text was made by AI, the line ends with 「（AI要約）」, so a reader can tell it from the person's own writing.
   - Because the person pressed the button to send, the AI text is written without a second confirmation. The person can undo it from the message (「取り消す」) while the note is unchanged since; otherwise ⌘Z in the editor and ordinary editing apply. This is an explicit exception to "AI never writes into the note" in decision 0009; no other AI path writes into a note.
6. **The summary is configurable (Settings, 「要約」).** *(Proposed defaults.)*
   - 作り方: 「AIで要約する（この Mac の中だけ）」 (default when the model is available) or 「要約せず、タイトル・URL・RSS要約を送る」. If AI is chosen but not available, the item is sent without AI and the message says so.
   - 長さ: 1文 / 3文以内（既定） / 5文以内. 形式: 文章（既定） / 箇条書き.
   - 追加の指示 (optional, up to 200 characters, the person's own words, put in the instructions of the model).
   - The input stays as in decision 0015: the retained body, the first 3,000 characters, 20 seconds. An article whose body has expired has no input for AI; the RSS summary and the title and URL can still be sent without AI. Other model settings (temperature and so on) are not exposed in V1.
7. **The note actions are removed** (「わかりやすく」「3行の要点」), with the goal review (L3, L4) and the Writing Tools item (L5) from the roadmap.
8. **Claude stays, as a function of the note.** When a note is open, the toolbar has a share-style button (the system share icon). Its menu has 「Claudeで開く…」, 「Markdownをコピー」 and 「Markdownとして書き出す…」. The button is not shown in the article view. The system's own sharing services are after V1. *(Proposed.)*
   - 「Claudeで開く…」 shows the review screen of decision 0012 with the full text, and the person presses 「Claudeで開く」 as before. The package holds the note only: no articles, no goal. The request asks Claude to read the note and say what is already solid (quoting the note), what is missing only from what the note does not say, opposing views worth checking, and what to read or write next; not to rewrite the note or write into the app. Output language can be chosen. The package lives 24 hours. Edits of the note after the review make it invalid, and a managed copy is a snapshot, as in decision 0018 point 5.
   - The hand-off of articles from the article list or a theme is removed.
9. **Data.** The current notes are test data and may be deleted. No migration is required. Beta compatibility is still not guaranteed (decision 0003) and the app still never deletes an unreadable store; if the old store cannot be opened, it shows the startup error. Carrying the text of old notes over is welcome only if it is cheap; the plan decides.
10. **Keys.** `n` sends a summary to a note. `t` is removed. The other keys are unchanged.
11. **Retention.** Article bodies and RSS summaries keep the 7 / 30 / 90 / 365 day setting. Notes are never deleted automatically; deleting a note asks for confirmation. Nothing else is recorded by notes.

## Stages (each its own plan PR and implementation PR)

| Stage | What |
|---|---|
| S1 | Notes: the model without goal and article records, the Mac Notes layout, create, delete, title from the first line. Removes the theme screens, the picker, `t`, the suggestions, the note actions and the panel's summary card. |
| S2 | 「ノートに要約を送る」 (button, menu, `n`), the summary settings, the AI mark and 「取り消す」. |
| S3 | Claude from the note (the share-style button; the note-only package). |
| S4 | Clean up: dead code and tests (article packages and sources, theme assistant parts, the migration code, old settings), docs and user guides. |
| S5 | Light styling of headings and lists in the editor. |

Order: S1 first. Until S2 is merged the app has no summary-to-note path; this is accepted for the beta, which has one tester. Stage A (real-device checks), the rename to Unagi Reader (D) and the beta preparation (F) of the roadmap continue after S3. Items PR 9 and PR 10 (reading size, editor size) stay as candidates. N2b is part of S4. L2 becomes S5; L4 and L5 are dropped.

## Not verified

- Nothing here is built yet. The layout, the menu flow and the Claude share-style entry are proposals checked only by the owner reading them.
- The size of the removal is not measured; S1's plan must list every file and test it touches.

## Sources

- Owner's messages in chat on 2026-10-11 (dogfooding of the N6 build, PR #62 and #63).
- Decisions 0003, 0008, 0009, 0012, 0013, 0015, 0016, 0017, 0018.
