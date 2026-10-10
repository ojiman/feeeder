# 0012 Claude hand-off from themes

- Status: valid (approved by the PdM when the PR 8 plan, [#36](https://github.com/ojiman/feeeder/pull/36), was merged)
- Date: 2026-10-10
- Decider: the owner (PdM). The choices below are the implementation choices listed at the top of the plan.

## Background

Decision 0009 says the only route that sends content off the Mac is the existing, reviewed Claude hand-off (PRD §5.2). That hand-off was built for daily and weekly notes. When notes became themes (decision 0008), its entry point was removed. PR 8 brings it back from a theme. The rule used for every choice: the person always sees exactly what leaves the Mac, and nothing leaves by accident.

## Decision

1. **Entry.** A toolbar button 「Claudeで開く…」 (Open in Claude…) is shown whenever a theme is selected. It opens the existing review screen as a sheet. It is disabled when the theme has no article that can be a source.
2. **Defaults.** Questions are included. **Answers are not** (they are the person's own writing). The answers switch is off, and disabled while questions are off. A note on the screen says that answers leave the Mac.
3. **What can be chosen.** The output language; each source one by one (the saved RSS summary or the retained article text, never both for one article); questions on or off; answers on or off (with the evidence articles the person chose for each question). The theme's "current understanding" (「いまの理解」) is never included.
4. **At least one source is required.** A package with only questions and answers is not allowed. This keeps the rules for managed copies and expiry unchanged.
5. **The package is checked again.** The theme context is rebuilt from the store on every reconcile. If a question, an included answer, the theme name, or an included evidence title changed, the review becomes invalid and must be made again.
6. **When a managed copy is deleted.** The copy records the theme and its questions. It is deleted when the theme, any question it includes, or any source it includes is deleted or removed. It is **not** deleted when an answer is edited or the theme is renamed: the copy is a labelled snapshot, and deleting a file that Claude may be reading would be worse. It still expires after 24 hours.
7. **No new launch path and no new claim.** Only the Cowork route that was checked (Claude Desktop 2.19675.0 / Pro / Cowork) is used. Nothing is sent automatically and Claude's reply is never written into the app.

## Impact

- The package text has a theme section (`BEGIN_THEME`…`END_THEME`). The person's words and article text are data; marker-like text inside them is kept verbatim.
- `deleteTheme`, `removeArticle`, and `deleteQuestion` call the existing `onContentPolicyChanged` hook, so the review and the managed copies are reconciled right away.
- The Japanese user guide and the English user guide describe the entry and the switches.

## Not verified

- Claude Desktop versions, plans, or routes other than the one that was checked.
- Whether the Cowork route reads a TXT with a theme section as intended, and how useful Claude's review is.
- A real launch from this screen (the live check of this PR does not press the launch button).
- IME and VoiceOver on the review screen; macOS 26 CI.

## Sources

- [PR 8 plan](../superpowers/plans/2026-10-10-claude-handoff-theme.md), [verification record](../verification/2026-10-10-claude-handoff-theme.md)
- [PRD §5.2](../specification.md), [decision 0005](0005-v1-product-decisions-2026-10-04.md), [decision 0009](0009-on-device-ai-principles.md)
