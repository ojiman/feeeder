# 0016 Note actions: two actions, their limits, and how an adopt is undone

- Status: valid (approved by the PdM when the plan PR that proposes it was merged)
- Date: 2026-10-10
- Decider: the owner (PdM) approved the N5 plan, [2026-10-10-note-actions.md](../superpowers/plans/2026-10-10-note-actions.md). The Product Owner (the agent) proposed the points.
- Builds on: [decision 0013](0013-goal-and-note-for-themes.md) (points 5 and 6). Replaces point 5 of [0015](0015-article-summary-details.md) ("no undo promise"): an adopted summary can now be undone too.

## Decision

1. **Two actions.** 「わかりやすく」 (rewrite) and 「3行の要点」 (the essence). "What is missing" and "an opposing view" are not built: the experiment found them weak. They may come through the Claude hand-off (N6).
2. **What an action works on.** The selection (white space at both ends, such as the line break a triple click takes, is not part of it); else the section under the cursor, from the nearest line that starts with `#` at or above the cursor to the line before the next such line (text before the first heading is a section). The heading line is not part of the text. Blank text gives no action.
3. **Budget.** At most 1,300 characters of the person's text (about 1,000 tokens). A rewrite **refuses** longer text; the essence uses the first 1,300 characters and says so. The goal goes only to the essence. A rewrite is about as long as its input, so its output cap is **1,200 tokens** (the plan's 700 would cut a rewrite of a full 1,300-character text); the essence cap is 300. With about 220 tokens of instructions the request stays near 2,400 of the model's 4,096 tokens. Deadline **30 seconds** (a rewrite of 1,300 characters can take longer than a short summary). A rewrite that comes back much shorter than its input (under half, for inputs of 200 characters or more) is treated as cut off at the token cap and is not offered.
4. **Adopting.** A rewrite replaces the text (not the heading). The essence inserts three lines starting with 「・」 as a new paragraph after the section, or after the line the selection ends in (never in the middle of a line; the insertion rules of 0015). A CRLF note keeps CRLF in a rewrite. Nothing reaches the note except by 「採用」.
5. **A card is dropped when it could be wrong.** When the note text or the selection differs from what the card was made for, or the theme, the face or the AI setting changes, the card is dropped and cannot be adopted. A late answer is never shown.
6. **Undo, and how.** Adopting is one step that ⌘Z takes back (and ⇧⌘Z redoes). It is done by handing the whole new text to the same save path as typing, and registering one step with the editor's undo manager that restores the old text through that save path, **only while the saved note still equals what the step produced** (so an undo can never put an old copy over text typed after the adopt, or over another theme's note; a step that does not apply does nothing, and an undo that cannot be saved is reported). An edit is refused, and the plain save is used instead, when the text view does not show the saved note (for example while Japanese text is being composed). (The first design, editing the text view's own storage and relying on its undo, did not undo reliably when SwiftUI drives the text view, so the app-level step is used.) The note's text view is found as the editable text view that is not a field editor, in the key window first and preferring the one that shows the expected note text. If it cannot be found, the adopt falls back to the plain save, without undo. N4's summary adopt uses the same path.
7. **The buttons are borderless**, which makes them AppKit buttons that a test can press.

## Not verified

- A real window and the real IME (⌘Z inside a composition); real rewrites on real notes: in a probe on a synthetic note the rewrite changed almost nothing, and one essence line turned "thinking about" into "chose". See [the verification record](../verification/2026-10-10-note-actions.md).

## Sources

- PdM approval of the N5 plan (PR #56), decision 0013, [the AI experiment](../verification/2026-10-10-note-ai-experiment.md).
