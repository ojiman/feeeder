# Settings Menu Feasibility Verification

Updated: 2026-10-10 (Japan time). Status: unapproved design recommendation and temporary-copy probes. This is not product acceptance or specification approval.

Scope: the [reduced three-category Settings draft](../superpowers/specs/2026-10-10-settings-draft.md). No product source, storage model, dependency, formal PRD, or Architecture was changed by this probe work.

## Current conclusion

**Recommend the three-category menu and one reading-size setting as an unapproved proposal.** A separate update path changed the article text size without reinstalling the text and retained the character in the top visible line across 36 synthetic cases. Update time grows with article length and is close to the time to open the same article. A very long article of about 156,000 characters took over 0.2 seconds, so performance remains unaccepted until the PdM sets budgets by length. The ReaderView path was connected in a temporary copy and verified; product integration and performance acceptance remain incomplete.

- The initial rendering probe covered 108 combinations, but it does not prove safe updates to an open article. Existing `install()` sends display notifications, initializes first-read state, and regenerates all text attributes. The probe therefore added a separate `updateReadingSize()` path.
- The update changes font, line spacing, and layout width on existing text ranges without resetting the article string. It captures the visible top character and its vertical offset, then restores that character after reflow. Selection also remains unchanged.
- The assertion is that a character from the old top line appears in the new top line. Exact UTF-16 line-start equality is not required because wrapping changes. Behavior near the end of a document, or with an image or blank gap at the top, remains unverified.
- Update time grows roughly with article length and is close to `install()` for the same article. A 200-paragraph article of about 156,000 UTF-16 characters required roughly 0.2–0.35 seconds of synchronous work. About 23,000 characters took around 30–55 ms; about 7,800 characters took around 10–20 ms. These are observations, not performance thresholds. Laying out all text before the top character was necessary to preserve position. Laying out a nearby window did not preserve it.
- Proportional line spacing `size / 2` and maximum width `670 × size / 16` are probe inputs. They adjust line length in wide panes, but do not keep a constant number of characters per line in narrow panes. Readability on actual devices has not been evaluated.
- Notes are proposed to update immediately in normal editing and defer only during IME composition. At Standard, preserve current `.body` and `title3` size and hierarchy; do not force notes to 16 pt. Marked-text monitoring, deferral, and save behavior are not integrated with the real editors. Synthetic results differed depending on whether the test manually notified the binding; a responder change in another window did not simulate IME completion. Real IME behavior remains **unconfirmed**.

## Baseline and environment

| Item | Value |
|---|---|
| Fixed product source | `e9bcd933873fe920fc3751ba417afe561ff2a99c` |
| Work branch | `codex/settings-feasibility`, PR #28 |
| OS / CPU | macOS 27.0.1 (26A434), Apple Silicon |
| Xcode / Swift | Xcode 27.0 (27A266a), Swift 6.4 (swiftlang-6.4.0.34.1) |
| Input | Synthetic Japanese and English text, emoji, and fictional links. The user's library was not opened. |
| External actions | Read private-repository review comments and updated the PR through authenticated GitHub. No article fetching, AI inference, model asset retrieval, or Claude launch. |

The work read `ReaderSettingsView`, `RSSReaderApp`, `NativeArticleText`, `QuestionEditor`, `UnderstandingEditor`, retention code, the PRD, Architecture, and decisions 0008/0009. The current caller installs text when its signature changes. Adding size to that signature alone does not provide the safe update path used in the probe.

## Probe results and limits

The [initial-render patch](probes/settings-typography.patch), [live-update patch](probes/settings-live-update.patch), and [ReaderView/key-path patch](probes/settings-key-path.patch) apply only to a temporary copy. No production source is changed by this PR.

| Check | Result | Evidence scope |
|---|---|---|
| Latest synthetic probe before ReaderView wiring | PASS | 10 Release tests. [Latest result excerpt](probes/settings-po-results.txt); same inputs as the committed probe assets. |
| Configurable initial rendering | PASS | 4 sizes × 3 line spacings × 3 maximum widths × 3 pane widths = 108. Checks font, body/quote line spacing, width limit, margins, link targets/notifications, and headings through `install()` and `setFrameSize()`. |
| Isolated ignored-setting controls | EXPECTED_FAIL | Ignoring font, line spacing, width limit, or margins individually fails its assertion. Font and line-spacing formulas are checked independently so short-circuiting cannot hide a failure. |
| Live article-size update | PASS (36 cases) | Three pane widths (360/600/1000 pt) × three starting paragraphs (0/7/20) × four target sizes (20/14/18/16 pt). A window-hosted `NSScrollView` verifies that an old top-line character appears in the new top line. |
| Article state during update | PASS (same 36 cases) | Text, selection, links, quote indentation/spacing, proportional width, and width limit remain consistent. |
| Display callbacks during update | PASS (same 36 cases) | Bitmap drawing and async callbacks are processed. `onDisplayBegin` and `onDisplayed` remain at their initial single calls; `install()` does not reset first-display state. |
| Live and fresh rendering match | PASS (8 cases) | Two widths × four sizes. Full attributes including newlines, document height, and paragraph drawing ranges match for ordinary text and quotes. |
| Control with position restoration removed | EXPECTED_FAIL | Removing only `scroll(to:)` from `updateReadingSize()` fails the old top-character assertion. |
| Long-article update time | Performance not accepted; record only | 20 synchronous Release updates across five cycles of 20/14/18/16 pt on a 200-paragraph article. Median varies from 210–351 ms with machine load; at commit `558e8b2`, median/p95/max were 217/289/361 ms. This excludes event wait and drawing. |
| Length and time relationship | Proportional; record only | 3/10/30/100/200 paragraphs (about 2,400–156,000 UTF-16 units), roughly 1.2–2.4 ms per 1,000 characters. Update was 0.9–1.2× `install()` for the same article. Absolute time varied by about 2× with load; ratio and length relationship were stable in the recorded runs. |
| Window-only layout shortcut | Rejected; position not retained | Laying out text only around the viewport was faster, but its estimated y position differed by 13,000–60,000 pt from full layout. Discontinuous attribute updates were also slower. If position retention remains a requirement, preceding text cannot be skipped with this method. |
| Existing paragraph-plus-offset restoration | Limitation observed | At width 360→1000 pt, paragraph 7 and 80 pt offset restored the first character from 5505 to 5597. The 80 pt offset remained within the old/new paragraph heights of 936/390 pt. This is separate from the new character-size update. |
| Settings form rendering | PASS for an old five-category skeleton only | Placeholder text and a picker rendered at 640×480 pt. This is not a complete overflow check. The [old representative image](probes/settings-category-reading.png) is not the reduced design. The actual three-category form is NOT RUN. |
| Synthetic editor | Conditional PASS | Ordinary font changes retained text and selection. Marked text remained only when the test manually called `didChangeText()` to sync the binding. Real IME and product integration are NOT RUN. |
| On-device AI availability | PASS on this machine | FoundationModels was available and Japanese embedding assets were present. Unsupported, partial, and Off product behavior is NOT RUN. |

The live update itself calls no loading, network, or Store path. The additional [ReaderView connection and key-input verification](2026-10-10-settings-key-path.md) wired a temporary copy through the caller and confirmed no additional fetch or mark-as-read calls with a synthetic Store. Product integration and acceptance remain incomplete. Image layout, end-of-article and gap restoration, real IME, and note integration remain unverified.

The probe includes the final newline in paragraph ranges for font and paragraph attributes. Initial quote styling also includes the newline, matching new rendering. The probe covers only the current paragraph-font contract; it does not claim to preserve arbitrary bold or monospaced font runs that the product does not currently implement.

## Earlier review history and PO findings

The initial fixed-commit tests had 17 UI tests across three suites and 6 Core tests in one suite, 23 total. The [earlier result excerpt](probes/settings-feasibility-results.txt) belongs to commit `f87bca5`; it is historical and does not replace current integration evidence. The earlier five-category proposal and 108 arbitrary settings combinations are investigation history, not the recommended settings count.

The [first review](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090231489) raised 10 points. Follow-up work corrected the rendering path, private-GitHub wording, removed the AI placeholder-key PASS, kept evidence in the repository, added the draft to the documentation map, split product decisions, and isolated per-run outputs.

The [PO review](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090440369) raised five points. Follow-up work separated initial rendering from live updates, limited claims to the article view, split font and spacing assertions, kept real IME unconfirmed, labeled the old form as a skeleton, and stored input hashes with the final probe assets. The earlier whitespace-normalization result remains historical.

The PO proposal to use three small categories, one reading-size setting, note composition deferral, and a Help shortcut reference is reflected in the unapproved draft. Retaining article bodies for theme entries changes an existing storage contract and remains a separate decision outside this PR.

## Performance analysis and recommendation

The PO decomposed the previously reported 217 ms median, 289 ms p95, and 361 ms maximum for 200 paragraphs:

1. **Full layout dominates.** A one-off timing run outside the repository found full layout (`ensureLayout` in `layoutDocument()`) at about 84%, attribute changes at about 15%, and position search/scroll/selection restoration under 1 ms.
2. **The time is close to opening the article.** `install()` uses the same full `layoutDocument()`. For the same article, `install()` took 170–277 ms and update took 210–324 ms (0.9–1.2×). The size change costs about as much as opening that article; it is not a separate fixed penalty.
3. **Time grows with article length.** About 1.2–2.4 ms per 1,000 UTF-16 units, with about 2× machine-load variation. Two hundred paragraphs (156,000 characters) are much longer than a typical article. About 23,000 characters took 30–55 ms; 78,000 took 95–155 ms. Real article-length distribution is not measured.
4. **A shortcut did not preserve position.** Laying out text only near the top character estimated its y position 13,000–60,000 pt away from full layout. The position is unknown until preceding text is laid out. This method cannot skip full layout while preserving the current position.
5. **Repeated increases have a bound.** Four size steps mean no more than three effective increments or decrements before a limit. The measured 20 alternating updates are a stress input rather than a likely key sequence.

**Recommendation: keep performance as an open acceptance condition.** The current update does not have a length-independent response time, though it costs about as much as opening the same article. The PdM should set budgets by article length (for example, within 100 ms through about 50,000 characters and up to article-open time above that) after measuring real article lengths. The PdM should also choose whether very long articles update immediately or wait until the key is released and apply once. A larger text-layout redesign, such as adopting a viewport-only TextKit 2 layout, is a separate product decision and outside this PR.

## Response to the latest review

The [review of commit 8148495](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090606313) reported that the reviewer reran the earlier six tests successfully. The later inputs and measurements are recorded separately.

1. Revised note behavior from next-open-only to immediate updates with deferral during IME composition. Keep only the latest pending value. Real IME integration remains unverified.
2. Added a size map based on 16 pt article text, current `.body` for answers/understanding, and current `title3`/semibold for questions. Standard notes retain current size.
3. Applied font and paragraph attributes through paragraph newlines, including initial quote rendering, and checked full-attribute/layout equality with fresh rendering.
4. Added a position-restoration control and Release timing for 20 updates to a 200-paragraph article. This is separate from real-event and draw smoothness.
5. Marked the old result file as superseded and stored the latest results and input hashes in the repository.

## Re-run

```sh
bash docs/verification/probes/run-settings-feasibility.sh
```

The [runner](probes/run-settings-feasibility.sh) extracts the fixed commit into a unique temporary directory, applies two patches, adds the [test source](probes/settings-feasibility.swift), and runs Release tests. Images, logs, and builds go into that run's directory. It uses a dedicated UserDefaults suite and removes it after the tests.

To reproduce each ignored-setting control, make one change at a time in the temporary copy of `NativeArticleText.swift`, then run `swift test` with the same options and `--filter parameterizedProductionInstallAndWidth`. Each control should exit 1. Restore the source before the next control.

| Control | Replace | With |
|---|---|---|
| Font | `append(paragraph, size: bodyFontSize` | `append(paragraph, size: 16` |
| Line spacing | `style.lineSpacing = lineSpacing` | `style.lineSpacing = 8` |
| Width limit | `min(maximumBodyWidth, newSize.width - 84)` | `min(670, newSize.width - 84)` |
| Side margins | `max(42, (newSize.width - width) / 2)` | `CGFloat(42)` |

Keep result excerpts and input SHA256 values in the repository; do not link to logs outside it. Check document links, shell syntax, and `git diff --check`. The first sandbox run stopped because of compiler-cache permissions; it was run with the approved execution permissions.

## Remaining checks and integration

- Exercise the actual Settings scene, finished three-category layout, Command-comma, category restoration, and multiple windows.
- Product integration of the ReaderView/NSViewRepresentable path, acceptance for document end/images/gaps and article switching, physical JIS layout, real IME, and key repeat. The temporary settings path, synthetic Store side effects, ABC window input, sheet, and WebView boundaries were checked within the limits in the [additional record](2026-10-10-settings-key-path.md).
- Restoration when an image, heading, or gap is at the top; end-of-document clamping; very short articles; hero images; changed source URL; returning from the original page.
- Existing note font baselines and shared scale, marked-text monitoring and deferral, question TextField and answer/understanding TextEditor, real Japanese IME, save/failure recovery, long editing sessions.
- Update latency and smoothness, Japanese/English readability of the proportional formula, VoiceOver, Reduce Motion/contrast/transparency, thousands of items, long-running use.
- AI integration, partial/unavailable/assets-missing/off states, disabling while work is pending, async status, settings across process restarts.
- macOS 26 / Swift 6.3.3. CI skips docs-only changes. Product Release build, signing/distribution, product implementation, and formal specification approval are outside this PR.

Open checks in [questions and answers](2026-10-10-theme-questions.md) and [theme screens](2026-10-10-theme-screens.md) also remain.

## Latest review: saved position, editor commands, and product menu

The [review of commit `dc01fd8`](https://github.com/ojiman/feeeder/pull/28#issuecomment-6093795120) identified that size updates refreshed the visible position but left the value saved for return/navigation unchanged. It also found that the probe rejected all editable text controls, contrary to the note-editing recommendation, and asked for standard View-menu commands in the product and English project text.

The temporary update path now calls `recordScroll()` after it finishes restoring the visible character. A new integration assertion checks that the saved `ReaderScrollMemory` anchor/offset equals `readingPosition()`, then restores it and verifies the same top character. The key predicate now allows editable NSTextView/NSTextField responders and blocks only while `hasMarkedText()` is true. This is a responder-rule test; actual note surfaces and real IME composition remain unverified.

The draft and probe record now specify standard View-menu commands for Increase Text Size, Decrease Text Size, and Actual Size, with macOS key equivalents. The low-level local event monitor remains temporary measurement tooling and is expressly excluded from the product design. JIS and other keyboard layouts still require product verification.

The branch now includes `origin/main` through `9a9e831` to pick up the current documentation rules and project state. The reproducible settings probe remains pinned to `e9bcd933873fe920fc3751ba417afe561ff2a99c` so it does not absorb the independently developed product work into its test baseline. The PR diff remains scoped to Settings documents and probes.
