# 0014 The note migration: format, what stays, and what pauses

- Status: valid (approved by the PdM when the plan PR that proposes it was merged)
- Date: 2026-10-10
- Decider: the owner (PdM) approved the N2 plan, 2026-10-10-theme-note.md (removed; in Git history), which lists these points as "Decisions for you". The Product Owner (the agent) proposed them.
- Builds on: [decision 0013](0013-goal-and-note-for-themes.md) (point 3, the migration).

## Decision

1. **Format.** For each theme, in this order and separated by one blank line: the old "current understanding" as it is (no heading); then, for each question in creation order, a heading line `# <first line of the question>`, the rest of the question if it had line breaks, the answer exactly as typed, and, if it had evidence, the line `根拠の記事:` ("Evidence articles:") with one list line `- <title> <<url>>` per article (`- <title>` without a link). An unanswered question stays as a heading. A theme with nothing to convert gets no note. If the note already has text, the old text goes after it.
2. **Safety.** All notes are composed first. Each composed note must contain every non-blank piece of its source text; if not, nothing is saved. All notes and all removals happen in one save. After a failed migration nothing is removed, and the next launch tries again. A second run finds nothing to do. After a successful run that removed questions, `onContentPolicyChanged` runs, so a review or a managed Claude copy built from old questions is dropped.
3. **Not carried over.** The lens name, the "answered" mark, and the question timestamps (labels the app made, not words the person wrote).
4. **The old model stays in the schema.** `ThemeQuestion` and `Theme.understanding` remain as stored fields, with no way to create them, so an unmigrated library still opens. The unreachable question code (store functions, question proposals, their tests) is removed in a follow-up PR (N2b). Removing the model classes is a pre-1.0 step.
5. **The Claude hand-off is paused until N6.** It sends the theme's articles only. The review screen says the note can not be handed over yet.
6. **At launch.** The migration runs after the store is open and does not use the "library could not be opened" path. A failure shows an alert with "retry"; a success shows one notice. The app does not copy the library; the user guide asks the person to copy the data folder first.

## Not verified

- The migration on a real library; the real Japanese IME in the note editor; VoiceOver and Reduce Motion on the note face. See the verification record (removed; in Git history).

## Sources

- PdM approval of the N2 plan (PR #49) and decision 0013.
