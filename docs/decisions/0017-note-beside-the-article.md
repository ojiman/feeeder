# 0017 The note beside the article

- Status: refined by [0019](0019-v1-simplification-notes.md) (the layout stays; the panel opens at once, is resizable, and the sidebar folds only when the window is narrow)
- Date: 2026-10-10
- Decider: the owner (PdM) proposed the screen after trying the note face (N2 to N5). The Product Owner (the agent) compared options and recommended; the PdM chose.
- Replaces: point 4 (the screen) of [decision 0013](0013-goal-and-note-for-themes.md). Its other points stand. The screens built in N3 (the note in the middle column, the reader's top bar, the 「原文｜AI要約」 switch) are replaced by L1 in [the roadmap, Part 1d](../superpowers/plans/2026-10-10-theme-notes.md).

## Background

With the note in the middle column the article list disappears, so moving between articles needs a top bar, and the reading flow of an RSS reader (a list that stays, `j` / `k`) is lost. The PdM proposed: the middle column is always the article list; the right column shows the article; the note opens over or beside the article with a modern editor, a button to summarize the article, AI help for writing, and an always visible AI review against the goal, in a calm, Claude-app-like style.

## Decision

1. **Screen.** The middle column is always the article list (for a theme, its articles, with the goal on top). The right column is the reader. The note opens **beside the reader as the standard macOS inspector** (a toolbar button and `⌥⌘I`; it can be resized). A layer that covers the article was considered and not chosen: it hides the article, which is what the note is for reading next to, and it is not a system behavior. The sidebar folds when the note opens (the rule from N3) and comes back when it closes.
2. **Summary.** A button 「記事から要約する」 in the note panel summarizes the article that is shown, as in N4 (on request, a card, adopt by choice). The 「原文｜AI要約」 switch is removed.
3. **Editor look.** First, only the look: headings and lists are displayed as such, while the saved text stays the same plain text (so the migration, the hand-off, the section finder of the note actions, and the Japanese IME are not affected). A real WYSIWYG editor with its own storage format is a later decision, taken after real use.
4. **AI help.** The note actions (N5) stay. The system Writing Tools are turned on in the note editor where available (L5). Actions that continue or expand the PdM's text are not built before an experiment, because the model can invent facts.
5. **Review against the goal.** The panel area is always present, but its content is made when the person asks or, if they turn it on in Settings, once after typing stops (never for an unchanged note, and a stale review says so). It is not generated on every change. An experiment on synthetic notes (L3) comes before the panel (L4): the earlier experiment found on-device "what is missing" and "an opposing view" weak, and an always visible wrong review misleads more than no review. If the quality is not enough, the review belongs to the Claude hand-off (N6).
6. **Look.** Calm, warm surfaces, rounded cards, the AI's own words set apart (a serif for them, as the Claude app does), text that streams in while it is written. This is refined in a real window over several rounds; the first version builds the states and the frame.

## Impact

- No data change. The goal, the note, the migration, and the AI rules (on request, adopt by choice, undo) are as before.
- N3's face switch, top bar and its tests, and N4's switch, are rewritten in L1. The sidebar folding rule, the shared reader state, the note actions and the undo bridge are kept.
- The roadmap gets Part 1d (L1 to L5).

## Not verified

- How the inspector behaves in a narrow window and with the folding sidebar on a real Mac; whether a note beside the article feels right. This is what L1's real-window check is for.

## Sources

- The PdM's description of the screen (2026-10-10) and the answers to three questions: the inspector, the look only first, and the review on request with an optional update, after an experiment.
- [Decision 0013](0013-goal-and-note-for-themes.md), [0015](0015-article-summary-details.md), [0016](0016-note-actions.md), and [the AI experiment](../verification/2026-10-10-note-ai-experiment.md).
