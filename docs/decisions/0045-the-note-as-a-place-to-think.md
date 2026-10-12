# 0045 The note as a place to think: remove the seams between reading and writing

- Status: **proposed**. Not approved. It becomes valid only when the owner (PdM) approves it and the PR that adds it is merged. Parts marked "open" or "PoC" are not decided.
- Date: 2026-10-12
- Decider: none yet. This is the Product Owner's proposal after a long discussion with the owner on 2026-10-12, which started from the discussion paper in [PR #105](https://github.com/ojiman/unagi-reader/pull/105).
- Would refine: [0019](0019-v1-simplification-notes.md) points 3, 5 and 9, and [0020](0020-summary-send-contract.md) (what a send writes). Would not change `docs/vision.md`; see "Vision" below.

## Background

The owner dogfooded the note view and found two problems.

1. **The place to write is too narrow.** The note panel is 300 to 640 pt wide (380 pt by default, `NotePanelWidth.range`) and the article list column keeps 280 to 640 pt. In the owner's screenshot the note wraps at about 14 Japanese characters per line while the article has the widest area and a large empty space below it. This is not a place to organise thoughts.
2. **Added articles look like scribbles.** A send writes a summary and a plain line `出典: title <URL>` into the body. The material and the person's own words share one look; only a trailing 「（AI要約）」 differs. The article, which has a thumbnail and a site name in the list, becomes a URL as text. A pile of these is a new kind of pile, like Stars that gather without being used.

The owner also doubted the on-device model. A later check on the Hatena Bookmark technology feed was better than expected, but its input was a short feed excerpt (the lead of the article), which is an easy input. Long articles whose lead is not the point are untested.

The discussion paper in PR #105 proposed a flow from selected Stars to a note. The Product Owner's view is that it moves the work (about the same number of actions as today) and adds a staging step, and that most of its layout part already exists (specification 3.3). This record keeps what is useful in it and drops the rest.

## The lens

Unagi Reader's value is a smooth loop with no seams (Vision: "A smooth feel is part of the value"). A note feature is judged by which seam it removes: a wait, a small decision, a lost position, a mode switch, or a broken link between the text and its source. A feature that only adds a capability that any RSS reader or notes app has (for example, quoting a selected sentence) is not the aim.

## Premise (owner, 2026-10-12)

Reading in RSS and writing a note are separate things. The note view is a place for writing, with its reference articles beside it. The panel for the note is therefore not something the person should lose by accident: dragging its edge must not collapse it (the owner chose this for the first fix, see below).

## Chosen by the owner in chat (2026-10-12; the record as a whole is still only proposed)

- **The note panel must not be collapsible by dragging its edge** (option A of the owner's choice; the other option was a visible entry point when collapsed). It is opened and closed only with the toolbar button or `⌥⌘I`. This is a fix for a reported problem on `main`: after the panel was dragged shut there was no way back that the person could find. It ships in its own pull request, not with this record.

## Proposed decisions

1. **Folding rule.** When the window is too narrow, fold the sidebar first and then give the article list less room. Never fold the article or the note. The person only opens and closes the note panel; the rest follows from the width. The note panel gets a larger ideal width and a higher maximum than 640 pt. The numbers come from PoC 1. PoC 1 found that the system's `detailOnly` does not fold the list column, and that widths which change with the fold state make the app hang on a large library (see the PoC results). So the list is not folded, and no column width may depend on the fold state.
2. **References stay in view.** The references of the open note are shown as a thin strip of small cards over the article pane (favicon or thumbnail, short title), with the current one marked. A click or `⌥⌘↑` / `⌥⌘↓` switches the article, and the note's caret and scroll position do not change. A popover that hides the references is not used.
3. **Collecting and writing are separate.** Recording a reference happens at once and does not wait for AI. What a send writes into the body is open (O1).
4. **Material in the body looks different from the person's words.** A summary is written as a Markdown quote (`>`) followed by a link line, and the editor shows quote lines muted with a bar on the left (display only; the saved characters are plain Markdown, as for headings and lists). Notes that already exist are not rewritten.
5. **The text and its source are linked both ways, with no new stored field.**
   - Activating a source link in the body selects that article in the reader.
   - A reference card shows a "cited" mark when the body contains its URL. The mark is computed from the body; nothing is stored or kept in step by hand.
   - Dragging a card into the body inserts a citation at the drop point.
6. **No companion panel (withdrawn).** An earlier draft let the note panel stay open beside RSS and Star so that `n` could send to the visible note. The owner's premise is that reading RSS and writing a note are two separate things, so this is not pursued and PoC 2 is dropped. `n` keeps its menu.
7. **Claude hand-off (open, O3).** If material leaves the body, the review package no longer shows where it came from. Consider adding the reference list (title and URL, no summaries) to the package. The review screen already shows the full text, so the person still reads exactly what leaves the Mac. This would change [0022](0022-note-only-package-clean-up.md).
8. **On-device summary is unchanged.** No preview screen, no change of the default in this record. A 30-minute check with about five long articles decides whether the default should change (O1).

## Open questions for the owner

| # | Question | Product Owner's lean |
|---|---|---|
| O1 | What does `n` write into the body by default: the summary as today, or nothing? | Keep the summary as a quote until the owner finds that they delete it every time. A setting 「本文に入れない」 may be added later. |
| O2 | What is the first line of a note made from one reference? | Keep `# article title` (no empty notes called 「新規ノート」 in the sidebar). |
| O3 | Does the review package carry the reference list? | Yes, title and URL only, shown on the review screen. |
| O4 | Does the folding rule always fold the list when the panel opens, or only when space is short? | Only when space is short; this is the rule in point 1. |

## Not in this decision

A bulk action 「ノートで考える」 from selected Stars. A destination that is remembered without being visible. A note panel that stays open beside RSS or Star. An AI preview before inserting a summary. A new collection object. Quoting a selected sentence (cheap to add later, not a differentiator). AI that combines several articles. A new label for the loop, a goal, a tag, or a folder for references.

## Vision

`docs/vision.md` says, under Note: "One button sends an article's summary to a note." If O1 changes this, the wording is the owner's to decide. This record does not edit that file.

## Proof of concept

The owner wants to try these before deciding. A PoC is throwaway code on a branch, never merged as it is. Only the decision that follows is merged, with the real implementation in its own PR. Each PoC is one theme and is time-boxed.

| PoC | What | What a test can show | What only the owner can judge |
|---|---|---|---|
| 0 | Check why the first block in the owner's screenshot has the AI mark but no summary. The specification says an empty answer falls back to an unmarked summary. | A failing test if it is a bug. | Nothing. |
| 1 | Folding rule, wider note panel, reference strip. No model change. | The fold rule as a pure function; panel width limits; the caret and scroll position are kept when the article changes. | Is it a place to think? Proposed floor: at least about 30 Japanese characters per line on a normal window. |
| 2 | ~~Companion panel across scopes~~ Dropped (owner's premise: reading and writing are separate). | | |
| 3 | Quote style in the editor, source link activates the article, "cited" mark, drag to cite. | The cited rule from the body; the link target; the saved text is unchanged by the style. | Does the material feel connected, not scribbled? |
| 4 | Summary check on about five long articles, with settings (input length, sentence count). | Nothing. | Is it good enough to stay the default? |

Rules for the PoCs:

- Run in a synthetic instance with its own data directory (`open -n`), never in the owner's library.
- PoC 1 comes first. If the owner does not feel it is better after PoC 1, stop and rethink; do not continue to PoC 2 and 3.
- The compiler in CI (Swift 6.3.3) is stricter than the local one. Add new window-level behaviour from outside the `ReaderView` modifier chain, and run CI before calling a PoC's design feasible.
- The result of each PoC is written back here as a short status, with the owner's own words for what only the owner can judge.
- Try every layout change with a large library (thousands of articles) as well as a small one. A hang showed only with the large one.

### PoC results (2026-10-12)

| PoC | Result |
|---|---|
| 0 | Reproduced: in bullet format, an answer of only list markers sent an AI mark with no summary. Fixed with tests first in [PR #108](https://github.com/ojiman/unagi-reader/pull/108). It is not confirmed that this was the cause in the owner's note (the owner may have edited the block). |
| 1 | Not finished. Findings below. The code is on the branch `poc/note-writing-space` (not for merge). The owner has not yet judged the feel. |

Findings of PoC 1:

1. **The note panel's width was never applied.** `inspectorColumnWidth` was put on the inspector itself and had no effect: the panel stayed about 270 pt wide, and the default of 380 pt and the saved width were not used. Put on the panel's content, it works (520 pt measured in a 1,339 pt window, about 35 Japanese characters per line against about 14 before). This is probably the main reason the owner found the note too narrow, and it is a bug in the current code that can be fixed on its own.
2. **`detailOnly` did not fold the list.** The state changed but the window still showed the list. Folding the sidebar (`doubleColumn`) works.
3. **Widths that depend on state hang the app.** With the list column's minimum and maximum and the panel's minimum changing with the fold state, opening a note from the sidebar while the all-articles list was shown, in a window narrower than 1,500 pt, kept the main thread at 100% CPU on a large library (13 MB store). With constant widths the same steps raise the CPU for a moment and then it is idle. The hot path is `ReaderView.visibleArticleIDs`, which filters every article each time it is read and is read many times per update (`ReaderStore.noteArticleIDs` under `visibleArticleIDs`). That cost is in the current code and any extra update makes it show.
4. **Hosted UI tests crash with the width on the content.** Three tests (`anEmptyNoteListsNoRows`, `theNotePanelHasNoSummaryButtonAndNoActionBar`, `shareButtonRemainsPresentForAnEmptyNoteAndOldReviewButtonIsGone`) end in AppKit's constraint update pass (`EXC_BREAKPOINT`) in the test harness, even with constant values and even with only an ideal width. The app itself ran. A real fix has to deal with this.
5. **Cost per update.** `visibleArticleIDs` should be computed once per update, not on every read. This is a separate, small fix.

Consequence for the proposal: the strip of reference cards (point 2) is not needed to start; the list is already the references. What remains for PoC 1 is the panel width fix (finding 1), the sidebar fold, and the owner's judgment. Narrowing the list needs a width that does not depend on the fold state (for example one fixed width for a note's list), which is untested.

## Not verified

Only PoC code is built (not merged). The screenshot is the only evidence of the narrow panel and the summary pile. Motion, the feel, Japanese input while composing in a quote line, VoiceOver, Reduce Motion, the macOS 27.0 support floor and long use are all unverified. The claim that a long article's summary is good enough is unverified (PoC 4).

## Sources

- The owner's messages in chat on 2026-10-12 (the narrow note, the screenshot of notes made from the Hatena Bookmark feed, the aim of a smooth experience).
- [PR #105](https://github.com/ojiman/unagi-reader/pull/105) and its discussion paper.
- Specification 3.2, 3.3 and 5.1; decisions 0019, 0020, 0022.
- `Sources/ReaderCore/NotePanelWidth.swift`; `Sources/UnagiReader/ReaderView.swift` (column widths).
