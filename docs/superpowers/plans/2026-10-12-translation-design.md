# Translation: design

- Status: proposal. Merging this PR approves the design and the order of work; it changes no behavior. The owner's decisions are listed at the end with a recommended answer for each.
- Date: 2026-10-12
- Owner's request: a translate button at the top right; press it and the article is translated into a language of the person's choice. The owner suggested Foundation Models.
- Reading order: [vision](../../vision.md), [specification](../../specification.md), this design. A decision record (0044) is added by the first implementation PR.

## 1. What it is

A button in the article toolbar. Pressing it translates the open article (title and body) into the target language, in place, on the Mac. Pressing it again shows the original. The language can be changed from the same button.

## 2. Does it fit the vision?

| Question (from the vision) | Answer |
|---|---|
| Does it make the loop smoother? | Yes, for the target reader: an engineer who reads English feeds every day can read a hard article in the same window, without copying text to another app. |
| Does it add something to manage? | One button and one remembered choice (the target language). No setting page, no per-feed list. |
| Can it make the reader wait? | Not without a button: translation starts only when pressed. It shows the first paragraphs as soon as they are ready, and it stops when the person moves to another article. |
| Can text leave the Mac without a button? | No. Translation runs on the Mac. The only network use is the system downloading a language pack, which the system asks the person to allow. |
| Does it work with AI off? | Yes. The Translation framework does not need Apple Intelligence. |

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

Foundation Models stays for what it is good at, and is **not** used for this feature: for example a later "explain in simple words" or "summary in the target language" (the summary settings already use it).

Sources: Apple's documentation for [TranslationSession](https://developer.apple.com/documentation/translation/translationsession), the [Translation framework](https://developer.apple.com/documentation/translation) and [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), read on 2026-10-12. Nothing here was tried on a Mac yet; section 9 lists what must be checked on a real Mac.

## 4. What the person sees

- **Button.** In the toolbar group at the top right, after 「ノートに要約を送る」 and before 「元ページをブラウザで開く」. Label 「翻訳」 (help: 「翻訳する／原文に戻す (t)」). Its icon is filled while the translation is shown. It is always present and disabled when no article is open (the toolbar must not change height, as the existing comment in `ReaderView` says). The key is `t`, free since the theme picker was removed; like the other keys it does nothing inside a text field.
- **Language.** The button is a menu with a primary action: a click translates (or goes back); the menu lists the target languages, with a check on the current one. The first target is the first language in the person's system language list (for the owner: Japanese). The choice is remembered in the app's preferences. The menu has no other items.
- **While it works.** The existing status row above the article text (where 「本文を確認中」 shows) says 「翻訳中…」, or 「言語を準備しています…」 while the system downloads a language pack. The article title and paragraphs change from the top as results arrive. Reduce Motion: no animation is used.
- **When it is done.** The row says what was done in a few words, for example 「英語 → 日本語」, with a link 「原文を表示」 (the same as the button). The reading position (the paragraph at the top) is kept when the text switches.
- **What is not translated.** The note, the article list and the sidebar stay as they are. 「ノートに要約を送る」 and the Claude hand-off use the **original** text: a summary or a package is never made from a machine translation without the person asking.
- **Moving on.** Moving to another article shows that article in its original language and stops the running translation. Translation is not sticky: nothing is translated that the person did not ask for. (A per-subscription "always translate" is a later idea, section 10.)
- **Same language.** If the article is already in the target language the button says so in the status row (「すでに日本語です」) and does nothing else.

Failure messages are one short sentence each, in the style of the add sheet: the language pair is not supported, the person did not allow the download, the language pack is missing and the Mac is offline, a paragraph could not be translated (the original paragraph stays, and the row says how many).

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
| Button, key, menu | `ReaderView` | The toolbar item, the key `t`, and the language menu. Added from outside the window's long modifier chain (see AGENTS.md known gotchas). |

Why the session is created in a view: Apple documents two ways to get a `TranslationSession`. The direct initializer `init(installedSource:target:)` has no UI but throws when a language is not installed, and it is available only from macOS 26.4; the SwiftUI `translationTask` shows the system download request and is available from macOS 15. The app uses `translationTask`, because the first use of a language pair needs that request. (A later change may use the direct initializer for pairs that are already installed.)

**Data and retention.** A translation is derived data. It is **not stored**: nothing is added to the library, the model, or the retention rules. It lives in memory only (the small cache) and disappears when the app closes. This keeps decision 0019's retention rules as they are.

**Links.** The first version shows the translated paragraphs as plain text: the links of the original paragraph are not kept, because their positions change in translation. The original is one press away. A later change can translate `AttributedString` (which keeps links) and rebuild the link ranges.

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

1. **T1. The core.** `TranslationPlan`, `ArticleTranslation`, `LanguageDecision`, the cache, with a fake translator and the unit tests. Decision record 0044. No UI.
2. **T2. The button.** The toolbar item, the key `t`, `TranslationHost` with `translationTask`, the status row, the display of translated paragraphs, the default language. First end-to-end use on a real Mac (the owner tries it).
3. **T3. The language menu.** The menu with a primary action, the remembered choice.
4. **Later, only if real use asks for it** (not planned): links kept through `AttributedString`; an "always translate" choice per subscription; showing the original and the translation together, paragraph by paragraph (useful for learning); translated titles in the article list; skipping code paragraphs; Foundation Models for "explain in simple words".

## 11. Decisions for the owner (recommended answers first)

1. **Engine.** The Translation framework, and Foundation Models only for later, other jobs. Agree?
2. **Default target language.** The first language of the system language list (Japanese for the owner). Agree?
3. **Not sticky.** Each article opens in its original language; translating is an explicit press. (The other option is "stay in translation mode while moving between articles", which makes every article wait for a translation.) Agree?
4. **The key.** `t` for translate / original. Agree?
5. **Summary and Claude hand-off use the original text.** Agree?
6. **Links in the translated text** are left out in the first version. Agree?
7. **Scope of T1 to T3** above, with the extras left for later. Agree?
