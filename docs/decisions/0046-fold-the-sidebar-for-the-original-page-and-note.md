# 0046 Fold the sidebar when the original page opens and when a note is shown

- Status: valid for the original page. Point 4 (the way back) is replaced by [0047](0047-the-way-back-is-a-cross-in-the-right-column.md); the note-screen parts by [0049](0049-one-note-and-no-ai-of-its-own.md) and [0050](0050-the-note-screen-closes-like-the-original-page.md).
- Date: 2026-10-12
- Decider: the owner (PdM) asked to use the left-panel fold shown in the supplied screen recording, even though it differed from the specification's existing layout rule. The owner answered the open points in chat; the details below are the Product Owner's.
- Refines: [0044](0044-original-page-slides-out.md) (the page's motion: 0.22 s becomes 0.3 s), and the note screen's fold rule in specification 3.3 (the 1,300 pt rule).

## Background

The owner shared a screen recording (about 18 seconds) and asked for the same fold of the left panel in two places: on the note screen, and on the RSS screen when `v` opens the original page. The following observations describe that recording, not a verified run of Unagi Reader. In the recording, pressing `v`:

- The sidebar slides out to the left and the list follows it to the window's left edge. The list keeps its width. The whole move takes about 0.35 s (frames at 20 per second).
- The article column is covered and the original page comes in from the right. The page uses the width of the article column and the sidebar together.
- A "<" (back) appears at the top left, next to the window buttons.
- Closing is the reverse: the page slides out to the right and the sidebar slides back in.
- The sidebar folds in a wide window too: it does not depend on the window's width.

Until now the specification said the opposite for the page: "the page opens inside the right column and keeps the width of the left and middle columns". The owner's reason for the change: after reading the page the person goes back to hopping between articles, and then it must be easy to pick another subscription.

## Decision

1. **Opening the original page (`v`) folds the sidebar.** In any window width. The page gets the width of the article column and the sidebar. The list moves to the left edge with the same width.
2. **Closing the page brings the sidebar back, however the page was closed** (`Esc`, 「記事に戻る」, `j` / `k`, a click on another article). So a `j` that closes the page also slides the sidebar back in. The owner chose this on purpose, so that the person can choose another subscription easily after reading. If repeated `j` makes the motion tiring, this is to be looked at again.
3. **On the note screen the sidebar is folded when a note is selected, in any window width, and stays folded while the person is on the note screen** (also when going from one note to another). Going to another screen (Feeds, a folder, a subscription) brings it back. Opening or closing the note's panel does not move the sidebar. This replaces the rule that folded the sidebar only in a window narrower than about 1,300 pt.
4. **The way back while the sidebar is folded is a "<" at the top left, next to the window buttons.** It replaces the sidebar button inside the list column. (Proposed by the Product Owner; the owner has not answered this point yet.)
5. **One motion, about 0.3 s, from the system's own sidebar fold** (the split view's column visibility), so that it feels like the rest of the Mac. The page's slide-in and slide-out change from 0.22 s to 0.3 s so that the two moves are one. Reduce Motion: no movement; the layout changes at once.
6. **The specification is changed to match** (3.1: the page's place, the motion; 3.3: the fold rule), and it is ahead of the code until the implementation pull requests land.

## Not in this change

No code. The implementation follows in small pull requests: the fold mechanism and the "<" button, then `v`, then the note screen. The architecture notes and the user guides (both languages) are updated with them. The note panel (inspector) is unchanged.

## Not verified

The app's motion at its real speed, and how closely the system's fold matches the recorded motion, are not verified; the supplied recording was read frame by frame only. Not known yet: the feel of repeated `j` with a page open (the sidebar goes in and out each time), Reduce Motion, VoiceOver, and the macOS 27.0 support floor.

## Sources

- The owner's recording and messages in chat on 2026-10-12.
- Specification 3.1 and 3.3; decision 0044.
