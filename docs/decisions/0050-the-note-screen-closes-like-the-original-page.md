# 0050 The note screen closes like the original page; no list button; a wider note

- Status: valid (approved by the PdM when the PR that adds this record is merged). Points marked **open** need the owner's answer.
- Date: 2026-10-13
- Decider: the owner (PdM), after trying the build of PR #119 (the note beside the article). The four points come from the owner's message; the details and the proposals marked below are the Product Owner's.
- Refines: [0049](0049-one-note-and-no-ai-of-its-own.md) points 4, 5 and 6 (how the note screen is left, the 「一覧」 button, the width of the note).

## Background

With the note open (article on the left, note on the right) the owner found:

- `j` / `k` kept the person on the note screen. After the original page (`v`), the same keys close the page and show the next article in the normal reading screen. The owner wants the same here.
- `Esc` should close the note the same way, as it closes the original page.
- The note is a place to write, so it can be wider than the first width (380 pt).
- The 「一覧」 button at the top left of the article was not understood. The original page has a ✕ for closing; the note screen should have one too.

## Decision

1. **`j` / `k` on the note screen do what they do on the original page.** They close the note (the move of decision 0049 in reverse: the note slides out to the right, the sidebar and the list come back) and the next or previous article is shown in the normal screen, with the list selection on it. Zapping through articles is done in the normal screen.
2. **`Esc` closes the note the same way** and shows the same article. It does nothing while Japanese text is being composed (the first `Esc` cancels the composition, as now). On the original page `Esc` is unchanged.
3. **A ✕ closes the note.** It sits at the top left of the article, where the ✕ of the original page sits, and does the same as `Esc`. It replaces the 「一覧」 button.
4. **The note is wider.** The first width is **640 pt** (today's largest width). The person can drag it up to **1,280 pt** (twice that). A width the person chose earlier is kept, within the new range. If the window is too narrow for the width, the note takes what is left after the article's smallest width (360 pt).
5. **Open: the smallest width of the note.** Proposal: keep **300 pt**. Reason: with point 3 there is no screen with the list, the article and the note together, so nothing else needs the room.
6. **Open: the screen with the list, the article and the note together.** The owner's message does not say whether it stays. Proposal: **remove it** with the 「一覧」 button (point 3), because `j` / `k` and the ✕ now lead back to the list. This deletes `noteListShown`, `SidebarFold.listFolded`'s second argument and the button. If the owner wants the three columns, a different control is needed and the smallest width of point 5 must be higher.
7. **Open: the previous / next buttons in the note's header and `⌥⌘↑` / `⌥⌘↓`.** With point 1 they would close the note, so they have no use. Proposal: **remove them**; the header keeps 「Markdownをコピー」 only.

## Order of work (small pull requests, deletions first)

1. Remove the 「一覧」 button, the three-column form and the previous / next buttons (points 3, 6 and 7, if confirmed); add the ✕.
2. `j` / `k` and `Esc` close the note (points 1 and 2).
3. The wider note (points 4 and 5).

The specification (3.1, 3.3 and PRD-04) is changed in this pull request and is ahead of the code until those pull requests land. The user guides and the architecture notes change with them. PR #119 (step 4 of decision 0049) is merged first as it is, or changed by the first item; the owner decides.

## Not verified

How `Esc` and `j` / `k` feel when the keyboard is in the note's editor (they must not take the key while the person types: only `Esc` closes, and not during composition). Whether 1,280 pt is usable on a small screen. The macOS 27.0 support floor.

## Sources

- The owner's message in chat on 2026-10-13, after trying the build of PR #119.
- Decisions 0044, 0046, 0047 and 0049; specification 3.1 and 3.3.
