# 0029 A + in the sidebar section headers

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) proposed a way to add a source that matches how notes are added. The Product Owner (the agent) changed the form: a row at the bottom of the list scrolls out of sight when there are many sources, so the + goes in the section header.

## Decision

The headers of the sidebar sections 「ノート」 and 「購読元」 show a small + at their right end while the pointer is over the header. It creates a new note, or opens the form for a new source. The + at the top left of the sidebar and the row 「新しいノート」 stay. The + is always in the accessibility tree as a control, and the header also has it as an action named like the control (VoiceOver actions).

## Not verified

How the + looks and feels on hover in a real window (background control tools cannot move the pointer, and the headings are one element for the accessibility API, so the + could not be pressed in a test); VoiceOver reading of the header action.
