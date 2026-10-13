# Roadmap

The **order** of the work to the beta and 1.0, and why. The units of work are [GitHub issues](https://github.com/ojiman/unagi-reader/issues); how they are written and taken is in [AGENTS.md](../AGENTS.md). The value is in the [vision](vision.md), the product in the [specification](specification.md).

## Now: the beta

**What the beta is for** (a draft by the agent, 2026-10-14; the owner confirms or rewrites it): the first build that someone other than the owner uses. It answers one question: does the loop (read → note → understand) hold for an engineer who reads many feeds, without the owner beside them? What we want back: where they waited (specification 2.1), where they had to manage or decide something (vision, question 2), and whether they still write in the note after a week. Who, and how many: the owner decides.

Everything that must be done before the beta is an issue in the milestone [Beta](https://github.com/ojiman/unagi-reader/milestone/1). It is closed to new issues; only the owner adds to it. **The beta is done when every issue in it is closed.**

1. **Decision 0050, in order** (the same files): [#139](https://github.com/ojiman/unagi-reader/issues/139) the layout button and the ✕, then [#140](https://github.com/ojiman/unagi-reader/issues/140) `Esc` and `j` / `k`, then [#141](https://github.com/ojiman/unagi-reader/issues/141) the wider note.
2. **The keyword filter** ([#129](https://github.com/ojiman/unagi-reader/issues/129)). It touches `ReaderView.swift`, so it comes after 0050. It waits for the owner's answers to the questions in the issue.
3. **Translation** ([design](superpowers/plans/2026-10-12-translation-design.md)), in this order: [#152](https://github.com/ojiman/unagi-reader/issues/152) T1 the core (touches no screen; it can start beside the work above), then [#153](https://github.com/ojiman/unagi-reader/issues/153) T2 the button and the display, then [#154](https://github.com/ojiman/unagi-reader/issues/154) T3 the language menu. T2 and T3 touch `ReaderView.swift`, so they come after the filter.
4. **Real-device check by the owner:** [#136](https://github.com/ojiman/unagi-reader/issues/136), [#145](https://github.com/ojiman/unagi-reader/issues/145), and a dogfooding week. Bugs found here come before any polish.
5. **Preparation:** [#142](https://github.com/ojiman/unagi-reader/issues/142) a fresh acceptance run; [#143](https://github.com/ojiman/unagi-reader/issues/143) the user guide matches the app; [#144](https://github.com/ojiman/unagi-reader/issues/144) the owner approves the specification. Do it last: the filter and translation add sections to it, and it is already in English, so the approved text is the final text.
6. **Other conditions:** [#126](https://github.com/ojiman/unagi-reader/issues/126) XML entities in the feed parser (security), [#127](https://github.com/ojiman/unagi-reader/issues/127) the layout test that fails on macOS 27, [#156](https://github.com/ojiman/unagi-reader/issues/156) how to sign and distribute (research only).

## Next

**The checks that let an agent verify its own work.** Today the owner is the only one who can check the screens, and the list of unverified items keeps growing. These touch no screen and can run beside the beta work:

1. [#133](https://github.com/ojiman/unagi-reader/issues/133) UI test runs that end without a result line.
2. [#158](https://github.com/ojiman/unagi-reader/issues/158) UI smoke tests in CI.
3. [#164](https://github.com/ojiman/unagi-reader/issues/164) measure the no-waiting budgets (specification 2.1).

**Not scheduled.** OPML export ([#130](https://github.com/ojiman/unagi-reader/issues/130)) is an enhancement issue with no place in the order; whoever has room can take it.

## Candidates

Ideas: no order, no issue. When the owner decides to build one, it moves to Next with an issue; when it is dropped, to Not planned.

- Reading size: one size for the article in Appearance (14 / 16 / 18 / 20 pt) and View-menu commands. A probe (PR #28) kept the top line in place; open: the time budget for long articles and the feel.
- The same size scale for the note editor (needs a real Japanese input check).
- A summary inserted into the note, redone to Apple's Human Interface Guidelines (needs a new decision; 0049 removed the old one).
- A draft helper from an AI outside the Mac, with the person's own key (needs a new decision).
- A language setting and a time zone setting (a language setting is needed before a public release).
- More styling in the note editor: tables, check lists, a preview.
- More than one note; note folders, search and tags (0049 chose one note).
- Passing part of the note to an AI; system sharing services; a view of past days; copying the URL.

## Not planned

Goals and learning plans; AI suggestions of notes; AI editing of the note; sync and accounts; a settings framework; key remapping.

## Before 1.0

The conditions in [specification 7.1](specification.md). A prune of the documents before the release (the second pass was done on 2026-10-14).

## Done

- V1 simplification (decision 0019), stages S1 to S5; parts later removed by decision 0049. Rename to Unagi Reader (0023).
- One note, no AI of its own (decision 0049): [#115](https://github.com/ojiman/unagi-reader/pull/115), [#116](https://github.com/ojiman/unagi-reader/pull/116), [#118](https://github.com/ojiman/unagi-reader/pull/118), [#119](https://github.com/ojiman/unagi-reader/pull/119), [#122](https://github.com/ojiman/unagi-reader/pull/122).
- Layout and motion (0044, 0046 to 0048), subscriptions (0036 to 0041, 0043, 0053), name and icon (0051).
- Documents in English and pruned; budgets for no waiting (2026-10-14).
