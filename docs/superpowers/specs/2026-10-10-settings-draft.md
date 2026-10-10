# Feeeder Settings Menu Draft

Updated: 2026-10-10 (Japan time). **Unapproved recommendation.** PO comments are recommendations, not PdM approval. This does not replace the formal PRD, Architecture, or approved decisions. This PR contains documents and verification probes, not a product implementation.

## 1. Purpose and assumptions

Feeeder should be ready to read without setup. Users can adjust readability, AI, and retention when needed. The main flow is collect → read → save with Star → understand through themes and questions. Settings should remain a small screen users visit occasionally.

This draft follows the [PRD](../../specification.md), [Architecture](../../architecture.md), decisions 0008/0009, current code, and [PO comments](https://github.com/ojiman/feeeder/pull/28#issuecomment-6090440369). It reduces the first five-category draft to three categories. It replaces the first proposal to group article typography, separate note sizing, previews, and shortcut reference into the same settings area.

The fixed product source for the probes is `e9bcd933873fe920fc3751ba417afe561ff2a99c`. Integration with the separately developed AI implementation remains a later merge point. Product renaming, sync, accounts, and added dependencies are outside this proposal.

## 2. Recommended categories

| Category | Proposed item and default | Reason |
|---|---|---|
| Appearance | Appearance: System / Light / Dark; default System | Keep the existing three options without creating a category for one item. |
| Appearance | Reading size: Small / Standard / Large / Extra Large; default Standard | One scale for article text and note editing, while retaining the existing size hierarchy at Standard. |
| On-device AI | Use suggestions: On / Off; default On | Existing contract in decision 0009. Manual themes, questions, and answers remain usable when off. |
| Storage | Retain article body and RSS summary: 7 / 30 / 90 / 365 days; default 30 days | Keep the current retention contract. |
| Storage | Delete all article bodies and RSS summaries: confirmation required | Separate destructive action from normal choices and show counts, impact, and that recovery is unavailable. |

Use the standard macOS category switcher and grouped forms. Open Settings from the app menu or with Command-comma, and restore the last category. Avoid a custom window frame. Ordinary settings apply as changed; only destructive actions require confirmation.

Show AI status in one line: “Checking,” “Available,” “Partly unavailable (reason),” “Unavailable (reason),” or “Off.” Track embedding and generation availability separately internally so that partial availability is not presented as total failure. Check asynchronously so opening Settings stays responsive.

Proposed AI explanation:

> Suggestions are processed on this Mac. They never write automatically to your answers or “current understanding.”

Explain Claude hand-off in the theme confirmation screen. When AI is off, do not start embedding or generation, and do not show a result that arrives later. Unavailability must not change the user's On/Off choice.

## 3. Reading size behavior and acceptance

### Article text

Settings and reading-surface commands should change the same value. Command-plus increases size, Command-minus decreases it, and Command-zero restores the default size. Resetting size must not reset appearance, retention, or AI.

Production commands should be standard items in the View menu, with key equivalents assigned to “Increase Text Size,” “Decrease Text Size,” and “Actual Size.” Proposed Japanese labels are 「文字を大きく」(Increase Text Size), 「文字を小さく」(Decrease Text Size), and 「実際のサイズ」(Actual Size). The system menu and responder chain should handle keyboard-layout resolution, menu visibility, accessibility, and disabled states at the size limits. The low-level event monitor in the synthetic probe is measurement tooling only; it is not the proposed product command implementation. Verify the actual key equivalents with JIS and other input sources before product acceptance.

Apply size to article bodies and RSS summaries, not original web pages. Keep headings, publisher, and date at their current hierarchy. Do not change normal typing behavior. At a size limit, further commands leave the value unchanged and do not trigger layout work.

Do not expose line spacing or maximum width as separate settings. The probe used additional line spacing `size / 2` and maximum width `670 × size / 16`. These match the current 8 pt and 670 pt at Standard 16 pt, but the proportional scale has not been judged for Japanese and English readability. Narrow panes cannot expand, so the same line length is not guaranteed. Tune with device testing; keep the formula unapproved.

**Position retention and response time are acceptance conditions.** Text visible at the top before a change should remain in the top line after reflow. Exact UTF-16 line-start equality is not required because wrapping can change. The saved reading position must also be refreshed after reflow so that returning from the original page or revisiting the article restores the same visible text. Decide acceptable behavior on device for end-of-article clamping and when an image, heading, or paragraph gap is at the top. This probe does not redefine the stored position format.

Update time grows roughly with article length and is close to the time to open the same article (about 1.2–2.4 ms per 1,000 UTF-16 characters). A very long 200-paragraph article of about 156,000 characters took 0.2–0.35 seconds; about 23,000 characters took around 30–55 ms. These values are records, not acceptance thresholds. Laying out content before the top text is necessary to preserve its position; laying out only nearby text did not preserve it. The PdM must set time budgets by article length before performance can pass. Choose whether very long articles update immediately or wait until the key is released and apply once. Four size choices limit effective increases/decreases to three layout updates before reaching a bound. Measure the distribution of real article lengths and key-to-draw response before deciding.

A size change must not trigger another article fetch, mark an unread article as read, or rewrite content. Preserve selection, links, and quotes. Do not reuse `install()` for an open article: it has side effects on display notifications, first-read state, and selection. Use a separate update path and update the saved scroll position after it finishes.

### Note editing

Use the same scale for questions, the user's answers, and “current understanding.” Do not force every note editor to 16 pt. At Standard, preserve the current text size and hierarchy. Keep theme names, headings, publisher, and lens choices at their current hierarchy.

| Content | Standard baseline | Proposed scale behavior |
|---|---|---|
| Article body and RSS summary | 16 pt, regular | 14 / 16 / 18 / 20 pt |
| User answer and current understanding | Current `.body`, regular | Scale the resolved current `.body` font size; preserve its current appearance at Standard. |
| Question text | Current `.title3.weight(.semibold)` | Scale the resolved current title3 font size and preserve semibold. |

Scale factors are 0.875 / 1 / 1.125 / 1.25. Do not assume `.body` is always exactly 13 pt; confirm the current editor's resolved font and implement from that baseline. Do not propose changing Standard notes to 16 pt. Applying the scale to real editors and comparing visual hierarchy remains unverified.

The unapproved recommendation is to apply changes immediately to open editors during normal input and defer them only while an IME marked-text composition is active. Detect composition with `hasMarkedText()` on the actual input control. If several changes arrive during composition, keep only the latest. Apply it after composition ends or is cancelled, preserving the existing view, text, save binding, and selection. New editors use the latest value. Never force composition to commit as a side effect.

While an update is pending, show that reading size will apply after composition. Settings and the same three commands in note editing change the shared value. Verify that Japanese input and candidate navigation remain intact, and that the pending update always resolves after composition. SwiftUI's ability to observe marked text is unverified; a native input bridge may be needed. The article-text probe does not implement note integration.

Synthetic marked-text results changed depending on whether the test manually notified the binding. Calling `didChangeText()` by hand or changing the first responder in a separate window does not reproduce real IME behavior. Safe immediate update remains **unconfirmed**. Deferring during composition is the recommendation, but it does not remove the need for real IME, save, and failure testing.

## 4. Retention explanation and boundaries

Proposed article-retention text:

> For unread articles, the period starts at first receipt. For read articles, it starts when they were first marked read. Starring or adding an article to a theme does not extend the original body's retention period.

> Theme names, questions, answers, current understanding, saved summaries, and article URLs are never deleted automatically. If an original body expires, saved notes and the source link remain.

Before shortening retention or deleting all bodies, show body and summary counts, estimated space recovered, what remains, and that deletion cannot be undone. Reuse `DeletionPreview` and `ReaderStore`. Cancellation must leave saved values intact; failures must not be reported as success. Do not present estimated recovered space as the entire library size.

Retaining bodies for articles in themes may be worth considering, but it changes the existing storage contract. It is a separate product decision and is not proposed or prototyped here. The PdM should decide separately whether to explore it. If adopted later, update the Storage explanation with that decision.

## 5. Excluded from this proposal

- Separate settings for line spacing, article width, or note-specific size; sample article; standalone reset button. Add no controls until a need is shown.
- A shortcut list inside Settings. Put a reference list in Help. Do not build key remapping.
- Auto-save interval or an auto-save toggle. Reliable saving and visible failures are product contracts.
- Lens editing; AI model, prompt, threshold, or API key; note retention period; removing delete confirmation.
- Theme rediscovery or search features. Do not expand this Settings investigation into feature work.
- App settings that duplicate Reduce Motion, contrast, or transparency controls provided by macOS. Respect the system settings.

## 6. Decisions and implementation hand-off

| Decision | Recommendation | Remaining condition |
|---|---|---|
| Three categories and reduced item set | Candidate | PdM decision; exercise the actual Settings scene and status display. |
| One reading-size value and reading-surface entry points | Candidate | Side-effect-free update, visible and saved position retention, menu-key behavior, persistence, PdM time budgets by article length, and a choice for very long articles. |
| Immediate note updates with deferral during IME composition | Candidate | Integration with current editors, resolved font baselines, marked-text monitoring and deferral, real IME, save, and failure recovery. |
| Position retention by visible text | Candidate acceptance condition | Test end-of-document, images, gaps, and acceptable precision on device. |
| Retaining themed article bodies | Out of scope | PdM decides whether to create a separate decision record. |

Use the existing SwiftUI Settings, AppStorage, and ReaderStore. Add no settings framework or storage model. Article text needs integration between NativeArticleText and its ReaderView caller. Notes need QuestionEditor and UnderstandingEditor. AI needs ThemeAssistant. Keep the macOS 27.0 support floor separate from the CI build floor of 26.6, and do not require APIs from the macOS 27 SDK.

The [feasibility record](../../verification/2026-10-10-settings-feasibility.md) and [ReaderView/key-input record](../../verification/2026-10-10-settings-key-path.md) are evidence from a temporary copy, not a completed product integration. After implementation, verify the three-category layout, Command-comma, View menu commands, VoiceOver, system accessibility settings, AI-off and partial availability, and save cancellation/failure. If adopted, update the formal PRD, Architecture, and decision record in the same PR.

## References

- [PRD](../../specification.md), [Architecture](../../architecture.md)
- [Decision 0008](../../decisions/0008-theme-centered-notes.md), [Decision 0009](../../decisions/0009-on-device-ai-principles.md)
- [Apple Settings HIG](https://developer.apple.com/design/human-interface-guidelines/settings). Category count, values, and update behavior here are Feeeder proposals, not Apple requirements.
