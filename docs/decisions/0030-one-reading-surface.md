# 0030 One reading surface

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) saw too many dark grays and strong lines between the columns and the headers; he proposed to give the right column the same make-up as the middle one. The points marked "PO" are the Product Owner's.

## What was measured

In a screenshot of the app the reading area used five different dark grays: the sidebar #26262B, the list #202023, the article #1E1E1E, the toolbar above the article #28282A with a 1 px lighter line under it, and the header strip of the note #222224.

## Decision

1. **The list, the article, the note and its header, the strips above and below the list, and the window behind the toolbar are one gray** (`AppPalette.surface`: #1E1E1E in dark mode, white in light mode). *(PO.)*
2. **The toolbar has no background of its own** (no gray bar, no line): it sits on the surface. *(PO.)*
3. **The sidebar stays a little lighter**, as the system draws it; it is the one deliberate step in the window. *(PO.)*
4. The thin line the system draws between columns stays (it is not a colour step any more).
5. The colour is a fixed value, not `textBackgroundColor`: inside a column of the split view the system resolves that colour with a vibrant appearance and gets a lighter, bluish gray (#27262B). Measured in a synthetic window: the list was #27262B next to the article's #1E1E1E until the fixed value was used.

## Not verified

The light appearance; the divider line in a very large window; the note panel header on the real library. The look of the toolbar when the article under it scrolls (macOS may draw its own scroll-edge effect).
