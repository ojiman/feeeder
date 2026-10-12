# 0047 The way back is a ✕ at the top left of the right column

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM). Decision 0046 proposed a "<" next to the window buttons, as Reeder has it; the owner found its place awkward and not beautiful, and proposed the ✕ that already appears at the top left of the right column.
- Replaces: point 4 of [0046](0046-sidebar-folds-like-reeder.md) (the way back is not a "<" next to the window buttons).

## Decision

1. **Original page (`v`):** the control at the top left of the page, which was 「< 記事に戻る」, is now a ✕ (label and tooltip 「記事に戻る」, `Esc` does the same). It closes the page and brings the sidebar back.
2. **Note screen:** a ✕ at the top left of the right column leaves the note screen: it goes back to the screen the person was on before (Feeds, a folder or a subscription, with its selection and reading position restored, as for any return from a note) and brings the sidebar back. It is not the same as hiding the note's panel (the toolbar button and `⌥⌘I`). *The meaning on the note screen is the Product Owner's proposal; the owner has not confirmed it.*
3. **The sidebar button inside the list column goes away** when the note screen gets its ✕.
4. **The list title keeps clear of the window buttons.** With the sidebar folded the list reaches the window's left edge, and its title would sit under the window buttons; it starts to their right.

## Not in this change

The note screen's ✕ and its fold arrive in the next pull request. This one does the original page (`v`) only: the fold, the ✕ and the title.

## Not verified

The motion at its real speed (it was checked slowed to 6 s in a synthetic copy, own bundle identifier and demo data, with a temporary build that opened the page on selection). Not checked: Esc and `j` / `k` closing (the same function), repeated `j`, Reduce Motion, VoiceOver, the feel on the owner's Mac.
