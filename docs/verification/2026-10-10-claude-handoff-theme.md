# Claude hand-off from a theme (PR 8): verification

Updated: 2026-10-10 (Japan time)

Target: [the PR 8 plan](../superpowers/plans/2026-10-10-claude-handoff-theme.md). Environment: Mac14,2 / macOS 27.0.1 / Swift 6.4 (local). All input is synthetic. The person's library was not used. The real Claude Desktop was not opened.

## Automated checks

| Item | Result |
|---|---|
| All tests | PASS (193 tests, Swift Testing) |
| Release build, signature check, `git diff --check` | PASS |
| Theme context in the package | Tests: questions and answers appear only when asked (answers off means no answer text, no "My answer", no evidence); a theme without questions is refused; the review becomes invalid when an included answer, the theme name, a question, the evidence, or the list of questions changes, or the theme is deleted; a change to an answer that was not included does not invalidate it; marker-like text in an answer stays verbatim and the package still ends with its own `END_PACKAGE`; a very large theme still splits losslessly. Mutation checks: always including answers, dropping the re-check in `reconcile`, and removing the `BEGIN_QUESTION` marker each make tests fail |
| Managed copies | Tests: a copy with answers is removed when its theme, one of its questions, or its saved-summary source is deleted or removed; it stays when an answer is edited or the theme is renamed (and still expires at 24 hours); a copy from an older version without the theme fields still reconciles and still follows the source rule; opening is refused when the package changed after review. Mutation checks: disabling the theme rule, and removing the hook from `deleteQuestion`, each make tests fail |

## Live check on a synthetic instance (separate bundle ID, temporary data; the person's real Feeeder was not touched)

I did **not** press 「Claudeで開く」 (Open in Claude) on the review screen, because it would open the real Claude Desktop. What was checked:

- The toolbar button 「Claudeで開く…」 is shown for a theme. It is dimmed (disabled) for an empty theme and enabled for a theme with articles.
- The review screen opens as a sheet. It shows the output language, the two switches (問いを含める = include the questions, on; 自分の答えと根拠の記事を含める = include my answers and evidence articles, off), the note about answers, each article with its two choices (retained text and saved RSS summary), and the full package text with its size and SHA-256.
- Answers off: the package has `BEGIN_THEME`, the theme name, the questions, and `Answers: not included` (3,188 bytes, SHA-256 `233a64fd…`). Answers on: the package contains `My answer (written by the user):` with the answer text and the evidence title and URL (3,472 bytes, SHA-256 `d456c0dd…`). Both numbers changed on the screen at once.
- Questions off: the answers switch becomes disabled and the package has no theme section (2,138 bytes).

## Not verified (not marked PASS)

- Claude Desktop versions, plans, and routes other than the one that was checked earlier (2.19675.0 / Pro / Cowork). A real launch from this screen was not tried in this PR. Whether the Cowork route reads the theme section as intended, and how useful Claude's review is.
- "全文をコピー" (copy all), the TXT export, and the split export were not run in the live check (tests cover the text and the split; the screen buttons were not pressed).
- IME and VoiceOver on the review screen; the review screen with a very large theme (many articles); macOS 26 CI (checked on this PR's CI).

## Independent review (opus, fixed commit `547b742`) and what was done

No Critical findings. One Important finding, fixed test-first.

| Finding | What was done |
|---|---|
| A managed copy was tied to its theme only when questions were on, and the source rule did not cover a retained article that leaves the theme. So a copy with a full article text survived `removeArticle`, and a copy without questions survived `deleteTheme`, against what decision 0012 and the guides said | Every package made from a theme records its `themeID` (`AIPackage.themeID`), and the copy is deleted when the theme is gone or a source article is no longer in it. Tests written first and seen failing: `aCopyOfARetainedArticleIsRemovedWhenThatArticleLeavesTheTheme` (with and without questions) and `aCopyWithoutQuestionsIsRemovedWhenItsThemeIsDeleted`. Mutation check: removing the membership rule makes the first fail. This also closes the review's note that the earlier deletion tests passed only through the source rule |

Also fixed (smaller findings): the hook runs even if the reload after a deletion fails (`theCleanUpRunsEvenWhenTheReloadAfterADeletionFails`); feed text in single-line fields (theme name, evidence title) is folded to one line and evidence URLs are validated, so a title cannot forge a line that looks like the person's own words (`feedTextCannotForgeTheLinesThatMarkTheUsersOwnWords`, mutation-checked); the review sheet is bound to the theme it was opened for (`.sheet(item:)`) instead of the live selection; turning the questions off also turns the answers off. The architecture paragraph was rewritten in English, the spec banner no longer says acceptance is complete, and the guides now say that renaming keeps a copy and removing an article deletes it.

Deferred: the toolbar button is enabled whenever the theme has articles, even if none can be a source (the sheet then says so); a malformed `themeID` in a copy's metadata makes that folder unreadable (the existing error alert repeats); source titles from feeds are not folded to one line (this predates the PR); the first cold test run of the reviewer exited with 1 after 124 passing tests and was not reproduced in two reruns (cause unknown).
