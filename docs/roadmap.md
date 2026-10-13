# Roadmap

The **order** of the planned work to the beta and 1.0. The value and the questions to ask when in doubt are in the [vision](vision.md); the product is in the [specification](specification.md). Older plans, records and roadmaps were removed from the working tree by the prune PR; they are in Git history.

This file is the order and the reasons; the units of work are [GitHub issues](https://github.com/ojiman/unagi-reader/issues). See "Where work is tracked" in [AGENTS.md](../AGENTS.md).

## How a stage runs

Each stage has a short plan PR first (scope, files and tests it touches, the decisions it needs). Merging the plan approves it. Then one implementation PR per stage, with failing tests first, one independent review of a fixed commit when the change is risky, and the specification, the architecture and the user guide updated for what changed. A plan lives in `docs/superpowers/plans/` only until its stage is merged; then delete it (Git keeps it).

## Now: the beta

Everything that must be done before the beta is an issue in the milestone [Beta](https://github.com/ojiman/unagi-reader/milestone/1). If a new condition appears, open an issue and give it that milestone.

1. **Decision 0050, in order.** One at a time: all three touch the same files. [#139](https://github.com/ojiman/unagi-reader/issues/139) the layout button and the ✕, then [#140](https://github.com/ojiman/unagi-reader/issues/140) `Esc` and `j` / `k`, then [#141](https://github.com/ojiman/unagi-reader/issues/141) the wider note. The specification is already ahead of the code for these. ([Decision 0050](decisions/0050-the-note-screen-closes-like-the-original-page.md).)
2. **Real-device check (the owner).** Read, add subscriptions, import OPML, write in the note beside the articles, copy the note into another AI, Japanese input in the note, a narrow window, and a long dogfooding week. The checklists are [#136](https://github.com/ojiman/unagi-reader/issues/136) and [#145](https://github.com/ojiman/unagi-reader/issues/145). Bugs found here come before any polish; each becomes an issue.
3. **Beta preparation.** [#142](https://github.com/ojiman/unagi-reader/issues/142) a fresh acceptance run of the reading features; [#143](https://github.com/ojiman/unagi-reader/issues/143) the user guide matches the app; [#144](https://github.com/ojiman/unagi-reader/issues/144) the owner approves the specification. Signing and distribution only on the owner's instruction.
4. **Other conditions of the beta:** [#126](https://github.com/ojiman/unagi-reader/issues/126) the entity gap in the feed parser (security), [#127](https://github.com/ojiman/unagi-reader/issues/127) the layout test that fails on macOS 27, [#134](https://github.com/ojiman/unagi-reader/issues/134) the decision about feeds that exist only on `http://`.

## Working in parallel

- Do not touch `ReaderView.swift`, so they can run beside anything: [#126](https://github.com/ojiman/unagi-reader/issues/126), [#127](https://github.com/ojiman/unagi-reader/issues/127), [#130](https://github.com/ojiman/unagi-reader/issues/130) (OPML export), [#131](https://github.com/ojiman/unagi-reader/issues/131), [#133](https://github.com/ojiman/unagi-reader/issues/133), [#135](https://github.com/ojiman/unagi-reader/issues/135).
- Touch `ReaderView.swift` and the window's long modifier chain, so **one at a time**, and not together with the decision 0050 steps: [#128](https://github.com/ojiman/unagi-reader/issues/128) (menu bar commands), [#129](https://github.com/ojiman/unagi-reader/issues/129) (keyword filter; it also waits for the owner's answers), [#132](https://github.com/ojiman/unagi-reader/issues/132) (splitting the chain).

## Candidates (not scheduled; an issue is opened when one is scheduled)

- **Reading size.** One shared size in Appearance (Small / Standard / Large / Extra Large = 14 / 16 / 18 / 20 pt, default Standard) and View-menu commands. A probe showed that a separate update path keeps the top visible line in place across 36 synthetic cases, and that the update time grows with the article (about 10 to 20 ms at 7,800 characters, about 0.2 to 0.35 s at 156,000). The probe code is in Git history (PR #28). Open: a time budget (the proposal: finish within about 100 ms up to about 50,000 characters, above that apply once after the key is released), and how it feels on the device.
- **Note editor size.** The same scale for the note editor. Needs a real Japanese input check: the update waits while text is being composed.
- **Translation.** A toolbar button that translates the open article on the Mac with the Translation framework. The design is merged and approved ([docs/superpowers/plans/2026-10-12-translation-design.md](superpowers/plans/2026-10-12-translation-design.md); decision numbers and parts that mention removed features are to be re-checked at the start). Three pull requests, in order: the core, the button, the language menu.

## Not planned

Goals and learning plans; AI suggestions of notes; AI editing of the note; note folders, tags and search (after V1); system sharing services (after V1); sync and accounts; a settings framework; key remapping; a language setting before the public release is planned but has no stage yet.

## Before 1.0

[#138](https://github.com/ojiman/unagi-reader/issues/138) a second prune pass over the verification records, the decision records and the user guide, run as an audit; the owner approves what to cut.

## Done (history)

- **V1 simplification** ([decision 0019](decisions/0019-v1-simplification-notes.md)): stages S1 to S5 (notes replace themes, the summary and the Claude review, light styling of the editor). Parts of it were removed later by decision 0049 (the summary, the send to a note, the hand-off to Claude, the list of notes). The rename to Unagi Reader ([decision 0023](decisions/0023-rename-to-unagi-reader.md)) is done.
- **Decision 0049** (one note, no AI of its own), steps 1 to 4: [#115](https://github.com/ojiman/unagi-reader/pull/115) the hand-off to Claude removed (「Markdownをコピー」 stays), [#116](https://github.com/ojiman/unagi-reader/pull/116) the summary and the send to a note removed, [#118](https://github.com/ojiman/unagi-reader/pull/118) one note, [#119](https://github.com/ojiman/unagi-reader/pull/119) the new layout (`n`, the move of about 0.3 s, 「一覧」), with fixes in [#122](https://github.com/ojiman/unagi-reader/pull/122).
- **Layout and motion** (decisions 0044, 0046 to 0048): the original page slides out, the sidebar folds, the ✕, the title below the band ([#106](https://github.com/ojiman/unagi-reader/pull/106), [#111](https://github.com/ojiman/unagi-reader/pull/111), [#112](https://github.com/ojiman/unagi-reader/pull/112), [#113](https://github.com/ojiman/unagi-reader/pull/113)).
- **Subscriptions** (decisions 0036 to 0041): the address is checked as it is typed, the folder in the add sheet, the feed found from a site address, `http://` checked as `https://`, OPML import, rename in the row ([#93](https://github.com/ojiman/unagi-reader/pull/93) to [#98](https://github.com/ojiman/unagi-reader/pull/98), [#100](https://github.com/ojiman/unagi-reader/pull/100)).
- **Name and icon** (decision 0051): [#121](https://github.com/ojiman/unagi-reader/pull/121).
