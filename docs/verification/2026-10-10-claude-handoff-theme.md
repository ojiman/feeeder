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
- With the questions switch off, the answers switch is greyed out but still shows its checked state. The request ignores it, so nothing is sent. The display could be clearer.
- IME and VoiceOver on the review screen; the review screen with a very large theme (many articles); macOS 26 CI (checked on this PR's CI).

## Independent review

(To be added after the review of a fixed commit.)
