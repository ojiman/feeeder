# 0019 V1 simplification: notes replace themes

- Status: valid in part. Points 2, 3, 5, 6 and 8 are replaced by [0049](0049-one-note-and-no-ai-of-its-own.md). The rest (themes, goals and questions removed; notes replace themes) stands.
- Date: 2026-10-11
- Decider: the owner (PdM, the investor) asked for the simpler product after dogfooding the N6 build, answered the open questions in chat, and delegated the remaining product decisions to the Product Owner (the agent): "decide them in line with the Unagi Reader concept". The points marked "PO" are the Product Owner's decisions. Merging this PR records the owner's approval.
- Replaces: the theme model of 0008 (Git history) and 0013 (Git history) in part (the goal, the name, the theme picker, the theme suggestions), 0016 (Git history) (note actions).
- Refines: 0012 (Git history) and 0018 (Git history) (the hand-off becomes a function of a note), 0015 (Git history) (the summary goes straight to a note), 0017 (Git history) (the layout stays; it gets fixes).

## Background

Dogfooding showed that the theme, the goal, the AI suggestions, the note actions and the review made too many ideas for one reader. Three real problems came up in one session: the note did not open when a theme was selected, the summary card pushed the window out of view, and the panel was narrow. The owner decided that the minimum that still gives the Unagi Reader experience is: read, send an AI summary of an article to a note, write in the note while seeing the articles, and ask Claude about the note.

## Decision

1. **A note replaces a theme.** The word 「ノート」 (Note) is used in the app, the spec and the docs; 「テーマ」 is gone. A note is one Markdown text document; there are many. There is no goal and no separate name: the title is the first non-empty line with leading `#` marks and spaces removed (an empty note is shown as 「新規ノート」). *(PO.)*
2. **Notes sit in the sidebar like subscriptions.** The sidebar lists the notes (most recently edited first, flat) with a 「新しいノート」 button. Folders for notes are after V1 (owner's choice). Selecting a note shows, as before: the list of **the articles sent to that note** in the middle, the article in the reader, and the note as the panel beside the article. The articles can be read while writing. *(Owner's idea; the layout of 0017 (Git history) stays.)*
3. **How an article is linked to a note.** Only by sending: sending a summary to a note (point 5) records the article in that note, once (title, URL, the RSS summary at that time; kept after the body expires, as the theme records were). There is no separate action "put into a note". The link can be removed per article from the list (the context menu 「このノートから外す」); this removes the record only and never changes the note's text. An article can be in many notes. Sending the same article to the same note again appends the summary again (the person asked) and does not add a second record. Deleting a note (with confirmation) deletes its text and its records, never the articles or the Star. *(PO.)*
4. **The editor is a plain Markdown text editor** with autosave on every keystroke, undo, the system text services, and Japanese input that is never disturbed. It does not rewrite what the person types. Light styling of `#` headings and `-` lists is wanted but does not block V1. The editor has no AI assist; assist may come later if needed.
5. **Sending a summary to a note.** The article toolbar has one button, 「ノートに要約を送る」 (key `n`), in the place of 「テーマに入れる」. It works for any article. It opens a short menu: 「新しいノート」 and the most recently edited notes. Choosing an entry sends at once; the person can keep reading. A message shows the progress, then the result (「『…』に送りました」 with 「開く」), or the reason of a failure. A request is tied to the article and the note chosen when it was made. *(PO.)*
   - New note: the text starts with `# ` and the article title, then the summary, then the source line. Existing note: a blank line, the summary, the source line, at the end.
   - Source line: `出典: タイトル <URL>`, as in decision 0015. When the text was made by AI, the line ends with 「（AI要約）」, so a reader can tell it from the person's own writing.
   - Because the person pressed the button to send, the AI text is written without a second confirmation. The person can undo it from the message (「取り消す」) while the note is unchanged since; otherwise ⌘Z in the editor and ordinary editing apply. An undo also removes the record of the article if the send created it. This is an explicit exception to "AI never writes into the note" in decision 0009; no other AI path writes into a note.
6. **The summary is configurable (Settings, 「要約」).** *(PO defaults.)*
   - 作り方: 「AIで要約する（この Mac の中だけ）」 (default when the model is available) or 「要約せず、タイトル・URL・RSS要約を送る」. If AI is chosen but not available, the item is sent without AI and the message says so.
   - 長さ: 1文 / 3文以内（既定） / 5文以内. 形式: 文章（既定） / 箇条書き.
   - 追加の指示 (optional, up to 200 characters, the person's own words, put in the instructions of the model).
   - The input stays as in decision 0015: the retained body, the first 3,000 characters, 20 seconds. An article whose body has expired has no input for AI; the title, the URL and the RSS summary can still be sent without AI. Other model settings (temperature and so on) are not exposed in V1.
7. **Removed:** the goal, the name sheet, the theme picker and the `t` key, the unsorted-Star area, the on-device suggestions (nearby themes, groupings, theme names), the note actions (「わかりやすく」「3行の要点」), the summary card in the panel, the goal review (L3, L4) and the Writing Tools item (L5), and the hand-off of articles from the article list.
8. **Claude stays, as a function of the note.** When the note panel is shown, its header has a share-style button (the system share icon). Its menu has 「Claudeで開く…」, 「Markdownをコピー」 and 「Markdownとして書き出す…」. The button is not shown without a note. The system's own sharing services are after V1. *(PO.)*
   - 「Claudeで開く…」 shows the review screen of decision 0012 with the full text, and the person presses 「Claudeで開く」 as before. The package holds the note only: no articles, no goal. The request asks Claude to read the note and say what is already solid (quoting the note), what is missing only from what the note does not say, opposing views worth checking, and what to read or write next; not to rewrite the note or write into the app. Output language can be chosen. The package lives 24 hours. Edits of the note after the review make it invalid, and a managed copy is a snapshot, as in decision 0018 point 5.
9. **The layout fixes that come with it** (reported while dogfooding). Selecting a note opens its panel at once; the panel can be resized by dragging and keeps its width between launches; a tall card never moves the window (fixed in #63). The sidebar is folded by opening the panel only when the window is too narrow for the four areas; the threshold is set in the S1 plan. *(PO.)*
10. **Data.** The current themes and notes are test data and may be deleted. No migration is required. Beta compatibility is still not guaranteed (decision 0003) and the app still never deletes an unreadable store; if the old store cannot be opened, it shows the startup error. The S1 plan decides whether the stored model changes by a light migration or a new shape. Carrying old note text over is welcome only if it is cheap.
11. **Keys.** `n` sends a summary to a note. `t` is removed when `n` arrives (S2). The other keys are unchanged.
12. **Retention.** Article bodies and RSS summaries keep the 7 / 30 / 90 / 365 day setting. A note's text and its article records are never deleted automatically.

## Stages (each its own plan PR and implementation PR; the app works after each one)

| Stage | What |
|---|---|
| S1 | Notes: rename; no goal and no name (title from the first line); remove the suggestions, the note actions, the summary card in the panel and the article hand-off; the panel opens at once, is resizable and remembers its width; the sidebar fold rule. The picker and `t` stay for now as the only way to link an article. |
| S2 | 「ノートに要約を送る」 (button, menu, `n`), the automatic link and the removal of a link, the summary settings, the AI mark and 「取り消す」. Removes the picker and `t`. |
| S3 | Claude from the note (the share-style button in the panel; the note-only package). |
| S4 | Clean up: dead code and tests (article packages and sources, theme assistant parts, the migration code, old settings), docs and user guides. |
| S5 | Light styling of headings and lists in the editor. |

Stage A (real-device checks), the rename to Unagi Reader (D) and the beta preparation (F) of the roadmap continue after S3. PR 9 and PR 10 (reading size, editor size) stay as candidates. N2b is part of S4. L2 becomes S5; L4 and L5 are dropped.

## Not verified

- Nothing here is built yet. The menu flow, the sidebar rule and the Claude share-style entry are proposals checked only by the owner reading them.
- The size of the removal is not measured; S1's plan must list every file and test it touches.

## Sources

- Owner's messages in chat on 2026-10-11 (dogfooding of the N6 build, PR #62 and #63; the notes-in-the-sidebar idea; delegation of the remaining decisions).
- Decisions 0003, 0008, 0009, 0012, 0013, 0015, 0016, 0017, 0018.
