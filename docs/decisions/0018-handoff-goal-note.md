# 0018 Claude hand-off with the goal and the note

- Status: valid (approved by the PdM when the plan PR that proposes it was merged)
- Date: 2026-10-11
- Decider: the owner (PdM) approved the N6 plan, [2026-10-11-handoff-goal-note.md](../superpowers/plans/2026-10-11-handoff-goal-note.md), and chose to give the review of a note against its goal to Claude after the on-device experiment ([the record](../verification/2026-10-11-goal-review-experiment.md)). The Product Owner (the agent) proposed the points.
- Refines: [decision 0012](0012-claude-handoff-from-themes.md) (the questions and answers switches become goal and note switches; points 5 and 6 lose the questions) and point 7 of [0013](0013-goal-and-note-for-themes.md).

## Decision

1. **Two switches** on the review screen: 「ゴールを含める」 (on by default when a goal exists) and 「ノートを含める」 (off by default from the toolbar entry). An empty goal or note is off and disabled. The screen says that the goal and the note leave the Mac when included.
2. **A button in the note panel,** 「Claudeでレビューを頼む」, opens the same screen with the goal and the note on (asking for a review is the explicit intent). The person still sees the full text and presses 「Claudeで開く」.
3. **The request.** With the note included, the package asks Claude to review the note against the goal: what the note already achieves (quoting the note); what is still missing, only on the basis of what the note does not say, and never claiming that something is missing when the note says it; weak support and opposing views from the sources, if included; what to read or write next; not to rewrite the note or write into the app. Without the note, the earlier request for the sources stays.
4. **Sources are optional** when the goal or the note is included; such a package lives 24 hours. With neither, at least one source is required (decision 0012, point 4).
5. **Invalidation and copies.** Editing the included goal or note, or renaming the theme, makes the review invalid. A managed copy is not deleted by such an edit (a snapshot), is deleted with its theme or when an included source leaves the theme, and expires after 24 hours. `questionIDs` in the metadata of old copies is ignored.
6. **Verbatim.** The goal and the note go into the package unchanged between `BEGIN_THEME` and `END_THEME`; marker-like lines in them are data; the split into 1 MiB parts stays lossless.

## Not verified

- A real launch into Claude Desktop with the goal and the note, and the usefulness of Claude's review. Other versions, plans or routes than the one checked (Claude Desktop 2.19675.0 / Pro / Cowork). A very large note through the Cowork route.
- See [the verification record](../verification/2026-10-11-handoff-goal-note.md).

## Sources

- PdM approval of the N6 plan (PR #61) and the goal review experiment (PR #60); decisions 0009, 0012, 0013.
