# 0042 A deleted note can be taken back for ten seconds

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) agreed to the Product Owner's advice in a discussion of note management: keep the notes flat (no folders yet), say the same things as for subscriptions, and treat deletion more carefully than for subscriptions, because a note is the person's own writing and cannot be fetched again. The details below are the Product Owner's.
- Refines: [0019](0019-v1-simplification-notes.md) point 3 (deleting a note, with confirmation).

## Decision

1. **After a note is deleted, 「ノートを削除しました　取り消す」 shows at the bottom left for ten seconds.** 「取り消す」 brings the note back as it was: the same identity, text, created and edited dates, and the records of the articles sent to it. It is opened again (selected, with its panel). A newer deletion replaces the older offer: only the last one can be taken back.
2. **The confirmation stays** (「このノートを削除しますか？」). Ten seconds is a short time to take something back, so the question before it is still the first safety. If a longer recovery is built later (for example a recently-deleted list), the question can go.
3. **After the ten seconds, or after the app quits, the deletion is final**, as before. The copy of the note lives only in memory (no new place in the library, nothing to manage).
4. **A failed restore keeps the offer** and shows the error; a restore never makes a second copy of a note that exists.
5. The same words and the same menu items as for subscriptions are kept (「名前を変更…」, 「削除…」); the next change (rename in the sidebar) joins the two.

## Not in this change

Note folders: the notes stay one flat list, newest edit first, until real use shows a need (then the chooser, the drag and the folder row of the subscriptions can be reused). A longer recovery (recently deleted). ⌘Z for the deletion (it would collide with the editor's own undo).

## Not verified

The context-menu item, the confirmation and the bar in a real window (the test tools cannot open context menus); the ten-second timer; VoiceOver for the bar. Covered by tests: the restore (identity, text, dates, records, saved to disk), no second copy, a failed save leaving the note deleted and retryable, the offer (the last deletion only, dismiss, a failed restore keeps it), and that the bar is drawn only while there is something to take back.
