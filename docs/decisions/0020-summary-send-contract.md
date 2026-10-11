# 0020 Summary sending and undo (S2)

- Status: valid; approved by the PdM by merging [PR #69](https://github.com/ojiman/feeeder/pull/69) on 2026-10-11.
- Decider: the owner (PdM).
- Refines: [0019](0019-v1-simplification-notes.md), points 3, 5, 6 and 11.

The S2 plan makes the summary flow concrete: one explicit send at a time; a new note or the 8 most recently edited notes; an appended block with a source line; one article link; an AI mark only for AI output. Length is 1/3/5 sentences, format is prose/bullets, and an optional instruction is one line of at most 200 characters. The `n` key replaces `t`. If both title and URL are absent, AI output keeps its mark on its own line.

An unavailable model, missing assets, model refusal, error, blank answer or the 20-second deadline sends an unmarked fallback: retained RSS text and the source, or the title and URL. This resolves the older specification sentence that said model failure leaves the note unchanged. Cancellation and switching AI off during generation write nothing.

Undo is offered for 8 seconds and only succeeds if the note text still matches the send. It restores the prior text, removes only the source record the send created, and deletes only a note the send created without other source records. It never overwrites a later edit. Removing an article from a note removes its source record, never its text or Star.

A save and the following reload have different failure boundaries. Failed save rolls back the text and link. Failed reload after successful save reports an error, but the committed write remains; there is no automatic repeat. The guides tell the person to check the note before sending again.

S3 (the Claude share button and note-only package), S4 cleanup, and S5 styling are outside this decision's implementation scope. Verification is in [the S2 record](../verification/s2-send-summary.md).
