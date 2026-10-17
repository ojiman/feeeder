# Translation: design

- Status: approved when it was merged (2026-10-12). It is deleted when the last translation PR (#154) is merged. What the person sees is in the [specification](../../specification.md) 3.6; this file keeps the engine choice, the parts and the order of work.
- Date: 2026-10-12
- Owner's request: a translate button at the top right; press it and the article is translated into a language of the person's choice. The owner suggested Foundation Models.
- Revision (2026-10-17): [decision 0060](../../decisions/0060-language-settings-and-ui-localization.md) replaces the article language menu and app-language target default with Settings and independent system-derived defaults. The dated decisions and HIG check below remain historical evidence.
- Reading order: [vision](../../vision.md), the specification 3.6, this design. A decision record (the next free number) is added by the first implementation PR.

## 1. What it is

A button in the article toolbar. Pressing it translates the open article (title and body) into the target language, in place, on the Mac. Pressing it again shows the original. The target is chosen in Settings (specification 3.6); the button has one action.

## 2. Does it fit the vision?

| Question (from the vision) | Answer |
|---|---|
| Does it make the loop smoother? | Yes, for the target reader: an engineer who reads English feeds every day can read a hard article in the same window, without copying text to another app. |
| Does it add something to manage? | One button and one remembered target in Settings; no per-feed list (decision 0060). |
| Can it make the reader wait? | Not without a button: translation starts only when pressed. It shows the first paragraphs as soon as they are ready, and it stops when the person moves to another article. |
| Can text leave the Mac without a button? | No. Translation runs on the Mac. The only network use is the system downloading a language pack, which the system asks the person to allow. |
| Does it work with AI off? | Yes. The Translation framework does not need Apple Intelligence. |
| Does it fit decision 0049 ("the app adds no AI of its own")? | Yes. Translation is a function of the system, like the Writing Tools the owner chose for the note; the app ships and runs no model of its own and sends no text anywhere. This is also why Foundation Models is not used (section 3). |

## 3. Engine: the Translation framework, not Foundation Models

The owner asked about Foundation Models (FM). Both run on the Mac. The recommendation is the **Translation framework** (`import Translation`), for these reasons.

| | Translation framework | Foundation Models |
|---|---|---|
| Built for translation | Yes | No. A general model. Apple lists its strengths as summarising, extracting, classifying and generating text. Quality for translation has to be tested, not assumed. |
| Needs Apple Intelligence | No. Works on every supported Mac. | Yes. Depends on the device, the region and the model being ready (`availability`). |
| Long articles | Batch API (`translations(from:)`, and `translate(batch:)` which returns results as they become ready). Made for many paragraphs. | One request must fit the context window, which is small and depends on the model version (`contextSize`; 4,096 tokens in the first version). An article has to be cut and joined by our own code. |
| Keeps formatting | `translate(AttributedString)` keeps formatting such as links. | Output is free text; structure has to be asked for and checked. |
| Faithfulness | A translation model: it translates and adds nothing. | An instruction-following model: it can add comments, shorten, or refuse a topic. |
| Languages | A fixed list, asked at run time (`LanguageAvailability`). | A fixed list, asked at run time (`supportedLanguages`). |
| Models | Language packs, downloaded once with the person's permission (`prepareTranslation()` or the system sheet). | Part of the system model. |
| Privacy | On device. Apple may collect usage numbers (app, language pair), not the text. | On device. |

Two more facts decide it:

- The Translation framework has a strategy setting (`preferredStrategy`). With the default high-fidelity strategy the system uses Apple Intelligence models when the Mac has them and falls back to the traditional models when it does not. So the framework already gives the better quality where it is available, and still works everywhere. We do not need to build that choice.
- "Any language" means any language **Apple supports**. The target list is whatever `LanguageAvailability` reports (a few dozen languages); the app does not invent its own list.

Foundation Models is **not** used for this feature. (The app no longer uses it at all: decision 0049.)

Sources: Apple's documentation for [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), the [Translation framework](https://developer.apple.com/documentation/translation) and [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), read on 2026-10-12. Nothing here was tried on a Mac yet; section 9 lists what must be checked on a real Mac.

## 4. What the person sees

It is in the specification, section 3.6 (the button, the key `t`, the status row, the Settings target and the failure sentences). The current default and language choice replace the original design under decision 0060.

One reason that the specification does not repeat:

- **Only the reader text is translated, not the original page.** There is no public way to translate a page inside the app's web view; it would need our own code that reads the text nodes of the page, translates them and writes them back, which breaks on dynamic pages and is out of proportion for this version. The reader text is also the better place to read a translation: it is clean, and 「全文を取得」 gives it the whole article.

## 5. How it works

```
Toolbar button / key t
  -> ReaderView sets the target on an ArticleTranslation (ReaderCore, @Observable)
  -> ArticleTranslation builds the request list: title + one request per body paragraph (index = clientIdentifier)
  -> a small hidden view in the article area holds `.translationTask(configuration)` and receives the TranslationSession
  -> the session translates the batch; each response is handed to ArticleTranslation by index
  -> ArticleDetailView shows the translated paragraphs through the same rendering path as the original
```

Parts (names are proposals):

| Part | Where | Role |
|---|---|---|
| `TranslationPlan` | ReaderCore | Pure. From an `ArticleContent` and the target: the title and the list of paragraphs to translate (empty ones skipped, order and quote depth kept). |
| `ArticleTranslation` | ReaderCore | `@Observable @MainActor` state: idle, preparing, translating(done of total), done, failed(message). Owns a generation counter so a late answer for an old article, language or toggle is dropped (the same rule as `FeedChecker`). Holds a small in-memory cache (the last few articles, keyed by article id, content version and target). |
| `LanguageDecision` | ReaderCore | Pure. With the detected language and the target: translate, "already in the target language", or "unsupported". Detection uses `NLLanguageRecognizer` on the title and the start of the body. If the language cannot be told, the source is left empty and the framework detects it. |
| `TranslationHost` | UnagiReader | A zero-size SwiftUI view in the background of the article area with `.translationTask(configuration)`. The only place that touches `TranslationSession`. It translates with `translate(batch:)` so that results arrive as they are ready, and calls `cancel()` when the generation changes. |
| Display | `ArticleDetailView` / `NativeArticleText` | Receives the translated title and paragraphs as `BodyParagraph` values in the same order, so layout, images and the scroll anchor (by paragraph index) work as they do now. |
| Button, key, menu | `ReaderView` | The article button, the key `t`, and the menu-bar translate/original command. The target is chosen in Settings (specification 3.6). Added from outside the window's long modifier chain (see AGENTS.md known gotchas). |

Why the session is created in a view: Apple documents two ways to get a `TranslationSession`. The direct initializer `init(installedSource:target:)` has no UI but throws when a language is not installed, and it is available only from macOS 26.4; the SwiftUI `translationTask` shows the system download request and is available from macOS 15. The app uses `translationTask`, because the first use of a language pair needs that request. (A later change may use the direct initializer for pairs that are already installed.)

**Data and retention.** A translation is derived data. It is **not stored**: nothing is added to the library, the model, or the retention rules. It lives in memory only (the small cache) and disappears when the app closes. This keeps decision 0019's retention rules as they are.

**Links.** Some words of an article are links (underlined words that open another page). The first version shows the translated paragraphs as plain text: those words are no longer links, because their positions change in translation. The original is one press away. (The owner agreed to leave this out.) A later change can translate `AttributedString` (which keeps links) and rebuild the link ranges.

## 6. Cases that must be handled

| Case | Behavior |
|---|---|
| The article changes, the language changes, or the button is pressed again while translating | The running translation is cancelled; a late answer is ignored (generation counter). |
| The text of the article changes (「全文を取得」 replaced the body) | The translation is stale: the original text shows, the button is off. |
| Language pack not installed | The system asks the person to allow the download; the row shows 「言語を準備しています…」. If refused, the message says so and the original stays. |
| Offline and the pack is missing | A message; the original stays. Offline with the pack installed works. |
| A very long article | Paragraphs are requests of a batch; the first paragraphs show first. Nothing blocks the main actor: the session does the work, and results are applied one by one. |
| A paragraph fails | Its original text stays in place; the status row counts the failures. |
| Code, tables, text that is not language | Sent as paragraphs like any other; the framework returns them unchanged or nearly so. A later change can skip paragraphs that look like code. |
| Right-to-left languages | Shown by the existing text view; checked on a real Mac. |
| Selection moves with `j` / `k` while translating | The same as "the article changes". |

## 7. Platform and build

- The app's support floor is macOS 27; CI builds on macOS 26.6. Everything above exists on both: `translationTask` since macOS 15; `preferredStrategy` and `init(installedSource:target:)` since macOS 26.4. Nothing needs a macOS 27-only API.
- The Translation framework is a system framework: no new dependency (AGENTS.md: dependencies need the owner's instruction).
- `TranslationSession` can only be exercised in a running app with language packs installed, so CI can build it but cannot run a real translation. All logic that can be separated is separated (`TranslationPlan`, `ArticleTranslation`, `LanguageDecision`), so it is covered by unit tests with a fake translator.

## 8. Tests

Unit tests (ReaderCore), written first:

- the plan: empty paragraphs skipped, order and quote depth kept, the title included;
- the state machine: idle to preparing to translating to done; cancel; failure; partial failure keeps original paragraphs;
- stale answers: another article, another language, a second press, a changed body;
- the cache: hit for the same article, content and target; a miss for any change; a size limit;
- the language decision: same language, different language, unknown language, unsupported pair (with an injected detector and an injected availability).

UI tests: the button is present and disabled without an article; its icon changes with the state (pixel check, as for the other toolbar items); the key `t` is ignored in a text field.

## 9. What cannot be tested by tools and must be tried on a real Mac

The system's download request; a real translation of a long article and how fast the first paragraphs appear; quality for the language pairs the owner uses (English to Japanese first); right-to-left text; VoiceOver for the button and the status row; Reduce Motion; the behavior on a Mac without Apple Intelligence; macOS 26 (CI builds only). Each implementation PR lists these as unverified, as AGENTS.md requires.

## 10. Order of work (one theme per PR, each merged before the next)

1. **T1. The core.** `TranslationPlan`, `ArticleTranslation`, `LanguageDecision`, the cache, with a fake translator and the unit tests. Decision record (next free number). No UI.
2. **T2. The button.** The toolbar item, the key `t`, `TranslationHost` with `translationTask`, the status row, the display of translated paragraphs, the default language. First end-to-end use on a real Mac (the owner tries it).
3. **T3. Language settings and UI localization.** The Settings choices and independent defaults of specification 3.6 and 3.7 (decision 0060); one article action.
   T2 also adds the menu bar command and the accessibility labels (section 12).
4. **Later, only if real use asks for it** (not planned): links kept through `AttributedString`; an "always translate" choice per subscription; showing the original and the translation together, paragraph by paragraph (useful for learning); translated titles in the article list; skipping code paragraphs; Foundation Models for "explain in simple words".

## 12. Check against Apple's Human Interface Guidelines

Read on 2026-10-12: [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) and [Pull-down buttons](https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons) (the Japanese pages load their text by script; the text was read from Apple's published data of the same pages). The Windows page has nothing on controls; its rules on bottom bars and inspectors are the ones that matter here.

| Part of the design | Guideline | Result |
|---|---|---|
| A symbol button in the toolbar, filled when on | Toolbars: prefer simple, recognizable system symbols without borders; add only important or frequent items | Fits. The same pattern as the Star button (`star` / `star.fill`). The symbol is the system's `translate` (check that it exists on the support floor; else `character.bubble`). |
| The button is only in the toolbar | Toolbars (macOS): "Make every toolbar item available as a command in the menu bar", because people can hide or customize the toolbar | **Did not fit. Fixed:** a menu bar command 「表示 ▸ 翻訳 / 原文に戻す」 is added (T2). |
| Status shown in a row above the article text, not in a bottom bar | Windows: avoid important information or actions in a bottom bar, because the bottom edge may be hidden; a bottom bar is for a small amount of information | Fits. The row is part of the content and holds nothing critical. |
| A progress indicator while translating | Not covered by these pages | A small determinate indicator is used (the number of paragraphs is known). |
| Failure messages in the status row, not in an alert | Alerts are for important, blocking questions | Fits: a failed translation does not need an answer. |
| The language menu on the button | Pull-down buttons: a menu of items that relate to the button's purpose; at least three items; a succinct menu title only if it adds meaning; a pop-up button is for a choice that is not a command | Fits: there are many languages, and choosing one is a command (it translates). No menu title. |
| A click acts and a menu opens from the same button (a split button) | The guideline pages do not describe it; macOS uses it in system apps | **Verify on a real Mac** that the button shows a visible menu indicator. If not, fall back to a pull-down button whose first item is 「翻訳 / 原文に戻す」 followed by the languages. The key `t` and the menu bar command stay the quick way. |
| Disabled with a help text while the original page is open | The app's own toolbar rule (items stay, so the toolbar does not change). The pages above say nothing about disabled items | Consistent with the app. The help text is the only explanation, so it must be short and clear. |
| The key `t` without Command | Menu key equivalents normally use Command; the reading keys (`j`, `k`, `s`, `n`) are the app's own, deliberate choice | Kept for consistency with the other reading keys; it is ignored in text fields. The menu bar command shows no key (it is not a Command shortcut). |
| Accessibility | The button's label follows its state: 「翻訳」 / 「原文を表示」; the status row is read by VoiceOver | Added to T2. |

**Found while checking, outside this design:** the existing toolbar items (the note, Star, open the original page) have no commands in the menu bar. By the same rule they should. This is a small separate change; it is not part of the translation work.

## 11. Decisions

Answered by the owner on 2026-10-12; the results are in the specification 3.6.

1. The engine is the Translation framework (section 3).
2. The default target is the language of the app (section 4).
3. Translation is not sticky: each article opens in its original language.
4. The key is `t`.
5. Links in the translated text are left out in the first version.
6. Version 1 translates the reader text only; the button is disabled while the original page is open.
7. The scope is three pull requests, in the order of section 10; the extras under "Later" are not built.
