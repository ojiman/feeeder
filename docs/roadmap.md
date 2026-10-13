# Roadmap

The **order** of the planned work to the beta and 1.0. The value and the questions to ask when in doubt are in the [vision](vision.md); the product is in the [specification](specification.md). Older plans, records and roadmaps were removed from the working tree by the prune PR; they are in Git history.

This file is the order and the reasons; the units of work are [GitHub issues](https://github.com/ojiman/unagi-reader/issues). See "Where work is tracked" in [AGENTS.md](../AGENTS.md).

## How a stage runs

Each stage has a short plan PR first (scope, files and tests it touches, the decisions it needs). Merging the plan approves it. Then one implementation PR per stage, with failing tests first, one independent review of a fixed commit when the change is risky, and the specification, the architecture and the user guide updated for what changed. A plan lives in `docs/superpowers/plans/` only until its stage is merged; then delete it (Git keeps it).

## Now: the beta

Everything that must be done before the beta is an issue in the milestone [Beta](https://github.com/ojiman/unagi-reader/milestone/1). **The milestone is closed to new issues** (the owner, 2026-10-14): the owner has listed everything. **The beta is done when every issue in the milestone is closed.** Something found later goes to a later milestone, unless the owner moves it in.

1. **Decision 0050, in order.** One at a time: all three touch the same files. [#139](https://github.com/ojiman/unagi-reader/issues/139) the layout button and the ✕, then [#140](https://github.com/ojiman/unagi-reader/issues/140) `Esc` and `j` / `k`, then [#141](https://github.com/ojiman/unagi-reader/issues/141) the wider note. The specification is already ahead of the code for these. ([Decision 0050](decisions/0050-the-note-screen-closes-like-the-original-page.md).)
2. **Real-device check (the owner).** Read, add subscriptions, import OPML, write in the note beside the articles, copy the note into another AI, Japanese input in the note, a narrow window, and a long dogfooding week. The checklists are [#136](https://github.com/ojiman/unagi-reader/issues/136) and [#145](https://github.com/ojiman/unagi-reader/issues/145). Bugs found here come before any polish; each becomes an issue.
3. **Beta preparation.** [#142](https://github.com/ojiman/unagi-reader/issues/142) a fresh acceptance run of the reading features; [#143](https://github.com/ojiman/unagi-reader/issues/143) the user guide matches the app; [#144](https://github.com/ojiman/unagi-reader/issues/144) the owner approves the specification. Signing and distribution only on the owner's instruction.
4. **Other conditions of the beta:** [#126](https://github.com/ojiman/unagi-reader/issues/126) the entity gap in the feed parser (security), [#127](https://github.com/ojiman/unagi-reader/issues/127) the layout test that fails on macOS 27, [#134](https://github.com/ojiman/unagi-reader/issues/134) the decision about feeds that exist only on `http://`, [#156](https://github.com/ojiman/unagi-reader/issues/156) how to sign, notarize and distribute the beta (research only; nothing is signed or published without the owner's instruction).

## Next: planned features

Features the owner has decided to build, in the order the owner gave. They are not conditions of the beta. A feature that touches no screen can start beside the beta work; one that touches `ReaderView.swift` waits for its turn (see "Working in parallel").

1. **Keyword filter for the article list** ([#129](https://github.com/ojiman/unagi-reader/issues/129)). The band of the middle column is ready for its icon (decision 0048). It waits for the owner's answers to the questions in the issue.
2. **Translation** (the design is merged and approved: [docs/superpowers/plans/2026-10-12-translation-design.md](superpowers/plans/2026-10-12-translation-design.md)). Three pull requests, in order, each merged before the next: [#152](https://github.com/ojiman/unagi-reader/issues/152) T1 the core (no screen), [#153](https://github.com/ojiman/unagi-reader/issues/153) T2 the button and the display, [#154](https://github.com/ojiman/unagi-reader/issues/154) T3 the language menu.
3. **OPML export** ([#130](https://github.com/ojiman/unagi-reader/issues/130)). No screen of its own; it can be done at any time.
4. **UI smoke tests in CI** ([#158](https://github.com/ojiman/unagi-reader/issues/158)). So that the owner is not the only one who checks the screens. No screen of its own; it can be done at any time.

## Working in parallel

The label on an issue says what it can run beside; there is no hand-kept list.

- [`area:no-screen`](https://github.com/ojiman/unagi-reader/issues?q=is%3Aopen+label%3Aarea%3Ano-screen): touches no screen; can run beside anything.
- [`area:reader-view`](https://github.com/ojiman/unagi-reader/issues?q=is%3Aopen+label%3Aarea%3Areader-view): touches `ReaderView.swift` and the window's long modifier chain; **one at a time**. This includes the steps of decision 0050.

## Candidates (ideas: no order, no issue)

A candidate is an idea. It has no order and no issue. When the owner decides to build it, it moves to "Next" and gets an issue (Problem, Acceptance Criteria, Constraints, Out of scope). When it is dropped, it moves to "Not planned". A candidate is never a requirement: the specification lists only what V1 is and is not.

- **Reading size.** One shared size in Appearance (Small / Standard / Large / Extra Large = 14 / 16 / 18 / 20 pt, default Standard) and View-menu commands. A probe showed that a separate update path keeps the top visible line in place across 36 synthetic cases, and that the update time grows with the article (about 10 to 20 ms at 7,800 characters, about 0.2 to 0.35 s at 156,000). The probe code is in Git history (PR #28). Open: a time budget (the proposal: finish within about 100 ms up to about 50,000 characters, above that apply once after the key is released), and how it feels on the device.
- **Note editor size.** The same scale for the note editor. Needs a real Japanese input check: the update waits while text is being composed.
- **A summary as an insertion into the note**, redone to Apple's Human Interface Guidelines (decision 0049 removed the old one; a new decision is needed to bring it back).
- **A draft helper from an AI outside the Mac** (bring your own key); needs a new decision.
- **A language setting and a time zone setting** (a language setting is needed before the public release).
- **More styling in the note editor:** tables, check lists, a preview.
- **More than one note, and note folders, search and tags** (decision 0049 chose one note).
- **Passing only a part of the note to an AI**, system sharing services, a view of past days, copying the URL.

## Not planned

Goals and learning plans; AI suggestions of notes; AI editing of the note; sync and accounts (Backend, accounts and sync start again from the product decision only if they become necessary); a settings framework; key remapping.

## Before 1.0

[#138](https://github.com/ojiman/unagi-reader/issues/138) a second prune pass over the verification records, the decision records and the user guide, run as an audit; the owner approves what to cut.

## Done (history)

- **V1 simplification** ([decision 0019](decisions/0019-v1-simplification-notes.md)): stages S1 to S5 (notes replace themes, the summary and the Claude review, light styling of the editor). Parts of it were removed later by decision 0049 (the summary, the send to a note, the hand-off to Claude, the list of notes). The rename to Unagi Reader ([decision 0023](decisions/0023-rename-to-unagi-reader.md)) is done.
- **Decision 0049** (one note, no AI of its own), steps 1 to 4: [#115](https://github.com/ojiman/unagi-reader/pull/115) the hand-off to Claude removed (「Markdownをコピー」 stays), [#116](https://github.com/ojiman/unagi-reader/pull/116) the summary and the send to a note removed, [#118](https://github.com/ojiman/unagi-reader/pull/118) one note, [#119](https://github.com/ojiman/unagi-reader/pull/119) the new layout (`n`, the move of about 0.3 s, 「一覧」), with fixes in [#122](https://github.com/ojiman/unagi-reader/pull/122).
- **Layout and motion** (decisions 0044, 0046 to 0048): the original page slides out, the sidebar folds, the ✕, the title below the band ([#106](https://github.com/ojiman/unagi-reader/pull/106), [#111](https://github.com/ojiman/unagi-reader/pull/111), [#112](https://github.com/ojiman/unagi-reader/pull/112), [#113](https://github.com/ojiman/unagi-reader/pull/113)).
- **Subscriptions** (decisions 0036 to 0041): the address is checked as it is typed, the folder in the add sheet, the feed found from a site address, `http://` checked as `https://`, OPML import, rename in the row ([#93](https://github.com/ojiman/unagi-reader/pull/93) to [#98](https://github.com/ojiman/unagi-reader/pull/98), [#100](https://github.com/ojiman/unagi-reader/pull/100)).
- **Name and icon** (decision 0051): [#121](https://github.com/ojiman/unagi-reader/pull/121).
