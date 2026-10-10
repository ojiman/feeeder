# 0015 The article summary: budget, insertion point, and limits

- Status: valid (approved by the PdM when the plan PR that proposes it was merged)
- Date: 2026-10-10
- Decider: the owner (PdM) approved the N4 plan, [2026-10-10-ai-summary.md](../superpowers/plans/2026-10-10-ai-summary.md). The Product Owner (the agent) proposed the points.
- Builds on: [decision 0013](0013-goal-and-note-for-themes.md) (points 5 and 6) and [0009](0009-on-device-ai-principles.md). It refines 0013 where the two differ (see 1 and 2).

## Decision

1. **Insertion point.** An adopted summary is inserted **after the end of the person's selection**, or at the cursor, or at the end of the note when there is neither. It never replaces the selection (0013 point 5 said "in place of the selection" for note actions; that stays for N5's rewriting actions, but a summary of another text must not delete the person's own words). It becomes its own paragraph, with a source line `出典: <title> <url>`. If the cursor is in the middle of a line, that line is split by blank lines; the text itself is not changed.
2. **Budget.** The model reads the first 3,000 characters of the retained article body (about 2,200 tokens at the measured 0.74 tokens per character; cut on `Character` boundaries) and a title of at most 200 characters. The output is capped at 400 tokens. This is the "article points" part of 0013's budget (it said 1,000 tokens), set from the experiment: a 4,800-character body still fitted. Character limits are used, not token counts, because the token-count API is newer than the macOS 26.6 build floor.
3. **Input source.** The retained body; if it is gone, the RSS summary the theme recorded for that article; if neither exists, nothing is sent. Expired text is never used.
4. **Limits.** A deadline of 20 seconds; any failure becomes a short message with "try again". Opening the summary, choosing an article, or switching the mode never starts a request.
5. **No undo promise** for an adopt in this version. Undo needs a native text bridge (PR 10).

## Not verified

- The card's buttons in any window; real summaries on real articles. See [the verification record](../verification/2026-10-10-ai-summary.md).

## Sources

- PdM approval of the N4 plan (PR #54), decision 0013, and [the AI experiment](../verification/2026-10-10-note-ai-experiment.md).
