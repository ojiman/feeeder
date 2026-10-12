# 0039 The unread mark is the colour of the source name

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) said the unread dot may go, if the code gets cleaner, and left the choice to the Product Owner ("the unread mark can be dropped; put the colour on the source name; gray once read, like the headline"). The details below are the Product Owner's.
- Refines: [0027](0027-calmer-colours.md) (the accent was for "small marks only: the unread dot"; the source name was gray).

## Why

In a narrow article list the source name was cut off with no ellipsis ("はてなブックマー", "Latest"). The row drew the name from an attributed string, made only to colour the unread dot. That string had no paragraph style, so the label lost its "cut the end with an ellipsis" setting, wrapped at a space, and clipped the rest. The dot also took about 12 pt of the width that a long name needs.

## Decision

1. **No dot.** An unread article has its source name in the soft accent (`AppPalette.accent`). A read article has the name in gray, the same as the read headline. A selected row keeps the selection text colour, as before.
2. **The name is a plain string with a text colour.** It keeps `lineBreakMode`, so a long name ends with an ellipsis. The code that coloured one character is removed.
3. The star mark and the note mark in front of the name stay as they are.
4. PRD §3.1: the unread mark is the accent colour of the source name, together with the brighter text (it said "an orange mark").

## Not in this change

The unread count in the sidebar, the colour of the headline, the row height and the order of the elements in the row.

## Not verified

VoiceOver reads the row the same as before (the dot was never read aloud), but this was not run. Real library names in many languages. Run in a test window (dark and light): an unread name in the accent, a read name in gray, and a long name with an ellipsis. A failing test came first (the name had no truncating paragraph style and wrapped to a second line); it passes now with the rest of the suite (257 tests).
