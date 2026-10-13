# 0052 The vision describes the screen as four areas, not "three columns"

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-14
- Decider: the owner (PdM) saw that the specification said "three columns" while the screen has four areas, and told the Product Owner to correct the vision as well ("fix that too").
- Changes: the wording of one line of `docs/vision.md`. The value, the user and the promises are not changed.

## Decision

The line "**Read.** A smooth three-column reader with keys." becomes "**Read.** A smooth reader with keys: sidebar, list and article, with the note beside them when you write." The reading screen still has three areas (sidebar, list, article); the note, the fourth, joins beside the article only while it is open. The specification (section 3.1) already describes the four areas and the four displays.

## Not in this change

Any other line of the vision.

## Sources

The owner's message in chat on 2026-10-14; specification 3.1 and `docs/spec-style.md`.
