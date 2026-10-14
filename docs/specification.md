# Unagi Reader specification (V1)

What V1 is and is not, as the person sees it. Why the product exists is in the [vision](vision.md); how it is built is in the [architecture](architecture.md); why each rule is so is in the [decision records](decisions/README.md). How to write this file: [spec-style.md](spec-style.md). What is not written here is not a requirement.

- **Approval.** The owner approves this text as a whole in #144. Approving the specification is not accepting the product: that is a separate demo on a real Mac (PRD-07).
- **Status marks.** A rule that is not built yet ends with `[not built #issue]`. A rule with no mark is built.

## 1. Purpose and scope

- The value, the user and the questions to ask when in doubt are in the [vision](vision.md): read → note → understand, in one app, with no waiting.
- The reading baseline is Reeder Classic 5.5.1: a smooth three-column reader, a calm dark look, Vim-style keys.
- V1 runs on the person's own Mac. No backend, no account, no sync.
- A new library starts empty; there is no migration from the prototype ([decision 0001](decisions/0001-fresh-library-no-prototype-migration.md)).
- Data between beta versions is not guaranteed; saves and restarts within one version are. From 1.0, data is kept across updates (7.1). If the library cannot be opened, the app shows an error and never deletes or recreates it (how SwiftData behaves with an incompatible store is not verified). Beta release notes state this limit ([decision 0003](decisions/0003-beta-data-compatibility.md)).

## 2. Promises

- The screen and the keys stay smooth; focus, the reading position, Japanese input and the system's accessibility are kept.
- Whatever body text can be had is shown readably. When none can be had, the RSS summary and a link to the original page keep the reading going. The app shows the feed's text only and never promises the full text (decision 0056).
- Read is history, Star is "come back to chew on this", and the note is the one place for the person's own words. They are independent.
- Article text within the retention period and the note can be read offline. Nothing the person wrote is deleted by the app.
- The app has no AI of its own (section 5).

### 2.1 No waiting: budgets

The vision promises that reading and typing never wait. These are the budgets a change must not break. They are targets: none is measured on the current build yet. `[not measured #164]`

| ID | Budget | How it is measured |
|---|---|---|
| W1 | `j` / `k` to the start of the next article's display: 95th percentile ≤ 100 ms, maximum ≤ 200 ms | Release build, `--performance-output <file>` (`selectionMilliseconds`), the synthetic library of `BenchmarkFixtureTests` (100 subscriptions, 10,000 articles). An older build measured about 40 ms at the 95th percentile (PR #14) |
| W2 | No main-thread stall over 100 ms while reading with keys, while typing in the note, or while a refresh runs | The same run: `schedulingGapsOver100ms` is empty |
| W3 | Launch to a list with articles: ≤ 1 s with the same library | Not instrumented yet |

## 3. Reading and the note

### 3.0 Terms

These words mean the same thing in this specification, the user guide, the decision records and the issues. "Code" is where the term lives in the code. The areas of the screen are in 3.1.1.

**Subscriptions**

| Term | Meaning | Code |
|---|---|---|
| subscription (購読) | One feed the person follows; one row in the sidebar | `Feed` |
| source name (購読元) | The name of a subscription, shown in the sidebar and on each article in the list. 「購読元」 is also the sidebar section's heading | `Feed.title` |
| feed (フィード) | An RSS 1.0, RSS 2.0 or Atom document; its address is `Feed.sourceURL` | `FeedParser`, `ParsedFeed` |
| folder (フォルダ) | A one-level group of subscriptions. It exists only by name and disappears with its last subscription | `Feed.folder` |
| 未分類 (unfiled) | Subscriptions in no folder. Not usable as a folder name | empty `Feed.folder`, `FolderPicker` |
| scope (対象) | What the list shows: all articles, unread, Star, a folder or one subscription | `ReaderWorkspaceScope` |

**Articles and reading**

| Term | Meaning | Code |
|---|---|---|
| article (記事) | One item of a feed | `Article` |
| body (本文) | The text to read: what the feed provided (a body an earlier version extracted from the page is kept and shown the same way) | `ContentSnapshot`, `ArticleContent` |
| RSS summary (RSS要約) | The short description the feed gives an article | `Article.summary` |
| read / unread (既読・未読) | An article becomes read, and its first read time is saved, when its body or RSS summary is actually shown in the article area | `Article.firstReadAt`, `ReaderStore.markDisplayed` |
| Star | The mark "come back to chew on this" (3.2) | `Article.starredAt` |
| retention period (保持期間) | Days the body and RSS summary are kept: 7, 30, 90 or 365 | `RetentionPolicy`, `ReaderSettings` |
| expired (期限切れ) | A body or RSS summary past the period. It is deleted; the Star, title and URL stay | `Article.contentDeletedAt`, `ReaderStore.purgeExpired` |

**Fetching and adding**

| Term | Meaning | Code |
|---|---|---|
| refresh (更新) | Fetching the feeds again for new articles: by hand, at launch, on return, every 30 minutes | `FeedRefreshController` |
| add sheet | The sheet that adds a subscription from a URL | `SubscriptionSheet` |
| check (確認) | Fetching and parsing the URL being typed to see if it can be added | `FeedChecker`, `FeedCheckRequest` |
| feed discovery | Finding the feed a site's page announces | `FeedDiscovery` |
| OPML | The file format that carries a list of subscriptions. Import only (export: #130) | `OPMLParser`, `OPMLImporter`, `OPMLImportFlow` |

**The note and screen parts**

| Term | Meaning | Code |
|---|---|---|
| note (ノート) | The app's one Markdown note (3.3) | `Note` |
| 「Markdownをコピー」 (Copy Markdown) | Puts the note's text, unchanged, on the pasteboard (3.3) | `NotePanel`, `ReaderView.copyNote` |
| list title | The scope's name and count above the list (3.1.4) | `ListHeader` |
| ✕ | The button at the top left of the right column. It closes the original page, and the note | `OriginalPageView`, `NotePanel` |
| Settings (設定) | The settings window: appearance and retention | `ReaderSettingsView` |

**Word use**

- Say 「元ページ」 (original page), never 「原文」.
- Say 「一覧」 (list) for the article list; 「リスト」 only for a Markdown list.
- 「購読」 is one subscription; 「購読元」 is the section heading and the name of the subscription an article came from.
- Quote screen labels exactly; the app's labels are Japanese.

### 3.1 The screen and reading

The screen has **four areas**. Reading shows three of them side by side (sidebar, list, article); the fourth, the note, joins on the right of the article only while it is open. How the areas are arranged is a **layout**; there are four (3.1.2).

#### 3.1.1 Areas

| Area | Code | Role |
|---|---|---|
| sidebar (サイドバー) | `ReaderView.sidebar`, `SidebarRow` | Choose what to read (Feeds, folders, subscriptions) |
| list (一覧) | `NativeArticleList`, `ListHeader` | The articles of the chosen scope |
| article (記事) | `ArticleDetailView`, `NativeArticleText` | The article's body (the RSS view) |
| original page (元ページ) | `OriginalPageView` | The original web page in an in-app browser, in place of the article area |
| note (ノート) | `ReaderView.notePanel` (inspector) | The one Markdown note (3.3) |

#### 3.1.2 Four layouts

| Layout | Areas shown | Status |
|---|---|---|
| normal | sidebar, list, article | |
| original page | list, original page. The sidebar folds; the page uses the article's and the sidebar's width | |
| note beside the article | article, note. The sidebar and the list fold | |
| note with the list | list, article, note. The sidebar folds | |

```
normal                original page (v)     note beside article   note with the list
┌────┬────┬───────┐  ┌────┬─────────┐      ┌─────────┬─────┐     ┌────┬───────┬─────┐
│side│list│article│  │list│original │      │ article │note │     │list│article│note │
│bar │    │       │  │    │  page   │      │         │     │     │    │       │     │
└────┴────┴───────┘  └────┴─────────┘      └─────────┴─────┘     └────┴───────┴─────┘
(widths are rough; the sidebar is folded away in the original page and note layouts)
```

#### 3.1.3 Changing the layout

| Action | Result | Status |
|---|---|---|
| `v` | normal → original page. The sidebar folds, the page comes in from the right, the list keeps its width and moves to the left edge | |
| `Esc`, the ✕, `j` / `k`, a click in the list | original page → normal. The page slides out to the right and the sidebar returns, whichever way it was closed. With `j` / `k` or a click, the chosen article's text appears from under the page | |
| `n`, `⌥⌘I`, the note button (in the article band) | normal → note beside the article. The sidebar and the list fold; the note comes in from the right. `n` works only when no editable field is being typed in. Opening writes nothing into the note (no summary, source or heading) | |
| the same action again | Closes the note and returns to the screen before (scope, chosen article, reading position), with the reverse motion | |
| the layout button (in the note band, beside the ✕) | note beside the article ⇄ note with the list. The chosen article, the scroll position and the note's text do not change. Two layouts only; no key | |
| `Esc`, the note's ✕ (top left of the right column, where the original page's ✕ is) | Closes the note and shows the same article in the normal layout, with the list selection on it. While Japanese text is being composed, `Esc` cancels the composition first | |
| `j` / `k` (focus in the article or the list) | Next / previous article with the note still open. In the note editor they type letters | |
| `⌥⌘↑` / `⌥⌘↓`, the arrows above the note | Change only the article, with the note still open | |

- **Motion.** Folding, returning and sliding are one movement of about 0.3 s, the system's split view motion, whatever the window width. With Reduce Motion nothing moves; the layout changes at once (decisions 0044, 0046, 0049).
- Opening or closing the note and switching its layout never change the chosen article or the scroll position.

#### 3.1.4 Rules per area

**Bands** (decision 0057)

- The window has no system toolbar and no visible title bar. Each column has its own band at the top of the window, as high as the window buttons' band (52 pt), in the column's colour, with no line under it. A band folds with its column. No column has a second row of controls below its band.
- What each band holds, left to right:

| Column | Left | Right |
|---|---|---|
| sidebar | the window buttons | add subscription, refresh (as now) |
| list | | the filter's magnifier, which opens into the system's search field across the band (List filter, below) |
| article | the translation status as short text (3.6) | the note button, Star, translate, globe |
| original page (in the article band, in place of the status; the band is then only as high as its controls and the page starts right below it) | ✕, the page's host name | |
| note | ✕, the layout button | previous, next, copy |

- One style: monochrome symbols of one size and one hit area; colour only for a state (a filled Star, a filled translate). No links and no accent-coloured symbols in a band.
- Dragging an empty part of a band moves the window; a double-click does what the system setting says.
- Every band control also has a menu bar command; the keys stay as they are (3.1.5).

**Sidebar**

- Choose the scope from Feeds (all articles, unread, Star) and 「購読元」 (folders and subscriptions). Each subscription shows its site icon. The 「購読元」 section can be collapsed.
- At the top right, right-aligned: add subscription, then refresh. While a refresh runs, the refresh arrow itself turns (not with Reduce Motion) and the button stays enabled (pressing it again does nothing).
- A small orange ＋ appears at the right end of the 「購読元」 heading on mouse-over and adds a subscription. The heading stays in place however long the list is.
- No Hide Sidebar button and no folder-management button.

**List**

- The list title (scope name and count) sits below the list's band, at 17 pt (as in Reeder; decision 0048).
- A row: source name on the left and publication time on the right of the top line; title, summary and article image below. The title is the largest (14 pt); the summary (11 pt) and the source name and time (10 pt) are smaller, because the title and the favicon decide interest.
- The column's edge can be dragged wider.
- The reading surfaces (list, article, note) are one dark colour, with no separate grey bars or lines in the bands; only the sidebar is slightly lighter.
- One calm orange accent, only for the unread mark, the add and refresh buttons and the note's list markers. The selected row is a quiet grey, not the system blue.
- When a refresh brings new articles and the list is at the top, they slide in from the top and push the rows down (at most 20 per refresh; not with Reduce Motion). When the list is not at the top, the article being read does not move. Manual and automatic refreshes behave the same.
- Publication time: the time for today, date and time for earlier days, the year too for other years. An unknown time is 「—」; the received time is never used instead.
- Unread: the source name in the accent colour and brighter text. Read: the whole row a calm grey. A long source name ends in 「…」. The selected row keeps readable contrast.

**List filter** (decision 0055)

- Only a magnifier is shown in the list's band. Clicking it or `/` grows the system's search field (as high as the band's buttons) out of it toward the left in about 0.25 s, with the cursor in it (3.1.5; no movement with Reduce Motion). Any click elsewhere turns the field back into the magnifier: with text the filter stays, also across scopes, and the magnifier is filled; empty, there is no filter. `Esc` in the empty field closes it and gives the list the keyboard.
- Typing narrows the list at once to the articles of the current scope (Feeds, Star, a folder, a subscription) whose title or feed summary (the text the list row shows) contains the typed text, ignoring case, accents and full-width letters. The count under the title counts the narrowed list. Clearing the field restores the list.
- Only the title and the feed summary are searched: not the article's body, not the full text the app saved, and not the note.
- The filter stays when the scope changes. It is not kept across launches.
- The chosen article stays chosen if it still matches. `j` / `k` move through the filtered list.
- While Japanese text is being composed, the list does not change.
- Typing never waits on the network or on a reload (budget W1, 2.1).
- Not built: saved filters, search of bodies or of the note, search across scopes, "mark all as read".

**Article**

- The title is 26 pt semibold. The buttons at the top: Star and the external browser (globe). Appearance (system / light / dark) is in Settings.
- Opening an article shows the feed's body (or the RSS summary) as it is; it never fetches the original page or swaps the text (RSS first, decision 0033). For more, `v` (in the app) or `b` (the browser).
- The app never takes text from the original page (decision 0056): no full-text fetch, and no line under the article that says how much text there is.
- Links and quotes of the feed's text are kept. A link opens in the default browser. Quotes look different from the text. A saved body without layout data is shown as plain text.
- The next article comes in from below, the previous from above, short and quick (following the list order). The text area does not change height when loading ends.
- An article becomes read when its body or RSS summary is actually shown in the article area. Scrolling the list or fetching the body does not mark it read. Receiving or showing it again does not change the first read time.

**Note**

- The rules are in 3.3. The width is kept across launches; whether the note is open is kept while the app runs.

#### 3.1.5 Keys

| Key | Action |
|---|---|
| `j` / `k` | Next / previous article |
| `s` | Star on / off |
| `n` | Open / close the note (as the note button and `⌥⌘I`), when no editable field is being typed in |
| `m` | Read / unread |
| `b` | Open the original page in the default browser |
| `v` | Open the original page in the app |
| `Esc` | Close the original page or the note and return to the same article at its reading position. While Japanese text is being composed, it cancels the composition first (decision 0050) |
| `/` | Open the list filter and put the cursor in it, when no editable field is being typed in |
| `t` | Translate the open article / show the original, when no editable field is being typed in |

- `j`, `k`, `s` and `n` also work in the original page.
- In text fields (the note editor too), during input-method composition and with modifier keys, typing and the standard actions come first.
- Everything important can be done with the keyboard alone. Actions inside the external browser are out of scope.

### 3.2 Star

A **Star** is the mark "come back to chew on this". An article has a Star or not; the app saves the state and when it was given.

- `s` and the Star button change the same state.
- Starring or unstarring never changes the read time.
- Unstarring removes the article from the Star list; starring again uses a new time.
- Unstarring the chosen article keeps it shown and in place until the person moves on.
- When the body expires, the Star, title and URL stay.
- A Star never does anything to the note.
- Not built: a screen to organize Stars, a flow that makes notes from Stars (decision 0019).

### 3.3 The note, retention and deletion

The **note** is the app's **one** plain-text Markdown document ([decision 0049](decisions/0049-one-note-and-no-ai-of-its-own.md)). Opening and layout are in 3.1.2 and 3.1.3.

**Basics**

- No list of notes, no new note, no name, no folders, no delete, no undo of a delete. No goals, tags, search or nesting.
- Every change is saved; the next launch continues where the person stopped.
- The text is saved exactly as typed. A failed save is never shown as saved. Input-method composition is never disturbed.
- Nothing writes into the note without the person: not the app, not an AI, not opening, closing or a layout change.

**Editor**

- Plain Markdown text with the system's text services, undo, Japanese input and Writing Tools (5.1).
- The panel's edge can be dragged; the width is kept across launches; dragging never folds the panel.
- Width: 640 pt at first, up to 1,280 pt, at least 300 pt. In a narrow window it leaves 360 pt for the article, and 280 pt for the list in the three-column layout. A width saved by an earlier version is dropped once, at the first launch of this version.
- Display-only styling; the saved text never changes:
  - A line that starts with one to six `#` and then a space or the line end is a heading: bold and larger.
  - A line that starts with `-`, `*`, `+` or a number (`1.`, `1)`), after at most 8 spaces, is a list item: the marker is coloured and wrapped lines align with the text.
  - Return does not continue a list; quotes and dashes are not replaced.
  - Nothing is styled during Japanese composition; it is styled after the text is confirmed or cancelled.
- Paste and drop insert plain text only.
- Not in V1: bold, italic, code, tables, check lists, a preview.

**「Markdownをコピー」 (Copy Markdown)**

- In the note panel's header. Copies the note's text exactly, as UTF-8 text on the system pasteboard, the end unchanged.
- Disabled when the note is empty or only whitespace.
- The app starts no other app, makes no file, uses no network and shows no confirmation.

**Retention and deletion**

| What | Kept | Counted from |
|---|---|---|
| article body and RSS summary | 30 days by default; 7, 30, 90 or 365 in Settings | unread: first received; read: first read. Receiving or showing again does not extend it |
| Star, title, URL | after the body expires too | — |
| the note's text | until the person deletes the characters (also after an article expires, its body is deleted, or a subscription is removed) | — |

- Shortening the period and deleting all bodies at once ask the person to confirm what will go.
- An expired body or summary is deleted; the article shows that it was, and keeps the link to the original page.
- There is no way to delete the note itself.

### 3.4 Favicons and images

- A subscription's favicon and an article's image are different things.
- An article's image comes first from the RSS/Atom feed. For Hatena Bookmark, the article image metadata is used.
- The list and the article show an image when there is one.
- No image, a failed image or being offline never stops reading. A late image never changes a row height, the selection or the scroll position.
- Images are cached for reuse; the cache is not part of what the app promises to keep.

### 3.5 Adding and managing subscriptions

**Adding from a URL**

- A subscription is added from an RSS or Atom URL. The add sheet has only the URL field, 「キャンセル」 and 「追加」 (decision 0032).
- An `http://` address is checked, and subscribed, as `https://`. An address with a port number is used as typed (decision 0040). A feed that is only on `http://` is not supported: when the `https://` form cannot be loaded, the app shows 「HTTPSでは読み込めませんでした。HTTPには対応していません。」 (decision 0053).
- A site's URL works too: the app finds the feeds the page announces (`<link rel="alternate" type="application/rss+xml">` and the like), uses the first, shows its URL, and subscribes to it. A saved subscription's refresh does not do this (decision 0038).
- The URL is checked while it is typed (decision 0036):
  - About 0.8 s after typing stops (at once after a paste), the app fetches and parses it and shows one line under the field: 「確認中…」, 「✓ <feed name>」 or why it failed.
  - 「追加」 is enabled only when the feed could be read (parsed as RSS 1.0, RSS 2.0 or Atom, not only a 200 answer). The checked feed is the one added.
  - While typing, a URL whose host does not look complete (`https://exa`, `https://example.c`) is not sent. Return sends names such as localhost too.
  - A URL already subscribed shows 「すでに購読しています」 and is not added.
  - A failure has a short sentence per cause: 404, unreadable, server error, no network, no answer, server not found, no secure connection, http not usable, too large, a web page and not a feed, an XML error. When the only problem is control characters that XML forbids, they are removed and the feed is read.
- Direct XML input and the synthetic sample appear only when the sheet is opened with ⌥ held (for checking failures).

**The folder when adding**

- Opened from the ＋ that appears on a folder row, the sheet adds to that folder and says so in its heading, for example 「「Tech」に購読を追加」.
- Opened from the 「購読元」 heading or the sidebar's ＋, a folder field with candidates (the same part as 「フォルダへ移動…」) appears once the feed is read, when at least one folder exists. Paste and Return with nothing chosen adds to 未分類 (the fast path stays). Typing a name selects the closest candidate; a new name offers 「作って追加」 (decision 0037).

**Importing OPML**

- File ▸ 「OPMLを取り込む…」. No shortcut.
- Subscriptions are added at once in one save; articles arrive afterwards. Folders are one level: deeper levels go into the top folder. Existing subscriptions are neither added again nor moved. The result is one short sentence (decision 0041).

**Managing subscriptions**

- Right-click a subscription: refresh, rename (in the row itself), move to a folder, unsubscribe (decision 0043).
- A subscription moved to another folder moves smoothly to its new place, and the folder opens (not with Reduce Motion).
- Two ways to move to a folder: 「フォルダへ移動…」 in the menu (a small chooser with a field: typing filters the folders; a new name offers 「作って移動」; ↑ ↓, Return, Esc; 「未分類」 too; a folder is made by moving its first subscription into it), and drag and drop in the sidebar.
- A folder can be renamed (a name that already exists joins the two folders) and shows the articles of all its subscriptions. An article in several subscriptions and its unread state are counted once. No empty folders and no nesting: a folder disappears with its last subscription.

### 3.6 Translation

A button translates the open article into another language, on the Mac, with the system's Translation framework. How it is built, and why that framework and not Foundation Models, is in the [design](superpowers/plans/2026-10-12-translation-design.md).

**Button and key**

- A button 「翻訳」 (Translate) sits in the article band, before 「元ページをブラウザで開く」. Its help text is 「翻訳する／原文に戻す (t)」; its icon (`character.bubble`; the system's `translate` has no filled form) is filled while a translation is shown. It is always there and is disabled when no article is open (the toolbar does not change height).
- The same command is in the menu bar: 「表示 ▸ 翻訳 / 原文に戻す」, without a key.
- `t` does the same, when no editable field is being typed in (3.1.5).
- Pressing it translates the title and the body of the open article, in place. Pressing it again shows the original.

**What is translated**

- Only the article's reader text (the feed's text). The note, the list and the sidebar are never translated.
- While the original page is open the button is disabled, with the help text 「元ページの表示中は翻訳できません。記事の表示に戻る (Esc) と翻訳できます」.
- Links in the translated text are plain text. The original is one press away.
- Translation is not sticky: moving to another article shows that article in its original language and stops the running translation. Nothing is translated that the person did not ask for.

**While it works and when it is done**

- The status, as short text at the left of the article band, says 「翻訳中 3/12」 (paragraphs done of all), or 「言語を準備しています…」 while the system downloads a language pack. Title and paragraphs change from the top as results arrive. The reading position is kept. Reduce Motion: no animation.
- When done, the status says what was done, for example 「英語 → 日本語」, with a link 「原文を表示」.
- If the article is already in the target language, the status says 「すでに日本語です」 and nothing else happens.
- A failure is one short sentence in the row, never an alert: the language pair is not supported; the download was not allowed; the language pack is missing and the Mac is offline. If one paragraph fails, its original text stays and the row says how many failed.

**Language** `[not built #154]`

- The button is a menu with a main action: a click translates (or goes back); the menu lists the languages the system reports, with a check on the current one. It has no other items.
- The first target is the language of the app (Japanese), not the first system language. A choice made in the menu is remembered across launches.

**Core rules** (decision 0054)

- A late answer for another article, another language, another press or a changed body is dropped. If a feed refresh changed the body, the translation is dropped, the original shows and the button is off.
- A translation is not stored: it is not in the library and not under the retention rules. It is kept in memory for a few recently translated articles and is gone when the app closes.
- Translating never blocks the main thread, and starts only when the person presses.

**Privacy.** Text never leaves the Mac. The only network use is the system downloading a language pack, which the system asks the person to allow. It does not need Apple Intelligence.

Not built: translating the original page, an "always translate" choice per subscription, original and translation side by side, translated titles in the list, links kept in the translated text.

## 4. How to decide

Use the [vision](vision.md)'s questions first. Then, in this order:

- **Reading never breaks:** no waiting, no lost position.
- **Opening is not interest:** read is history; Star is interest.
- **The person chooses what to keep:** nothing piles up on its own.
- **Honest about the input:** show what was fetched, as it is.

Never:

- Bypass a restriction to fetch more.
- Fill a missing body by guessing.
- Depend on a server holding the person's reading history.

## 5. AI

The app has **no AI of its own** ([decision 0049](decisions/0049-one-note-and-no-ai-of-its-own.md)). It never summarizes, suggests or writes into the note, never sends text to an outside service, and never uses the network for AI. Everything works without AI.

### 5.1 Writing Tools in the note

- The note editor is a standard macOS text view, so the system shows **Writing Tools** (proofread, rewrite, tone, summary, key points, list, table, Compose and more) on a Mac with Apple Intelligence, for example from the right-click menu on selected text.
- Writing Tools act only when the person selects text and chooses them. The app adds nothing and does not promise their quality.
- On a Mac where they are not available, writing, editing and copying the note all still work.
- To summarize an article, the person pastes its text into the note and uses Writing Tools.

### 5.2 Giving the note to another AI

- The person presses 「Markdownをコピー」 (3.3) and pastes the text into any AI (Claude, Codex, Gemini and so on). Text leaves the Mac only when the person pastes it.

## 6. Limits and what V1 does not build

**Platform and policy**

- macOS 27.0 or later (the support floor). CI builds for 26.6 ([decision 0007](decisions/0007-support-floor-macos-27.md)).
- The source is Apache-2.0. LICENSE and the third-party licenses, copyright notices and NOTICE are shipped. Feeds, articles, trademarks and service terms are not under the app's license.
- Only code, the specification and synthetic samples and tests are published; never the person's subscriptions, history, articles, note or credentials. Check the diff and the history before publishing.
- Publishing the source is a separate decision after product acceptance. The App Store and a signed release are not conditions of V1. Approving a policy is not permission to publish or distribute.

**Not built in V1**

| Area | Not built | Why |
|---|---|---|
| Platform | backend, accounts, sync, server-side fetching or AI, shared notes, push notifications | [vision](vision.md) |
| Subscriptions | nested folders, empty folders | 3.5 |
| Note | more than one note; folders, levels, tags, search or goals for notes; daily or weekly notes; system sharing services | decisions 0019, 0049 |
| Fetching | taking text from the original page (decision 0056); bypassing paywalls, subscriptions, logins or captchas; a full-text guarantee | section 4 |
| AI | an AI of the app's own (summary, draft help: a new decision is needed), keys or API calls in the app, AI off the Mac (Private Cloud Compute and the like), a dedicated link to one AI app (only 「Markdownをコピー」), sending or recording automatically, a guarantee of facts | decision 0049 |
| Settings | an in-app language or time zone setting | — |
| Old data | the prototype's Like and any migration of it (Star is a new mark) | decision 0001 |

Ideas for after V1, and the order of the work, are in the [roadmap](roadmap.md).

## 7. V1 acceptance scenarios

These are the conditions for passing, not a list of what has passed. "Where it is checked" names the place a condition can be checked; what only a real Mac can show is in the checklists of #136 and #145. A test that checks a scenario names its ID in a comment (`// PRD-02`), so `grep -rn "PRD-02" Tests` lists the tests of a scenario.

| ID | Scenario | Passes when | Where it is checked |
|---|---|---|---|
| PRD-01 | Read smoothly, with subscriptions in order | The four areas, the four layouts, appearance, folders and unread counts, the keys and the note open and close as in 3.1. No wrong body, no visible stall, no scroll jump; input, input methods and VoiceOver are not disturbed. The budgets of 2.1 hold. The owner compares with Reeder Classic on a real Mac | real Mac (the owner, against Reeder Classic); parts in UI tests; 2.1 |
| PRD-02 | Open an article from the unread list | Scrolling the list keeps articles unread. Showing the body or the RSS summary saves the first read time | unit tests, synthetic app |
| PRD-04 | Write in the note | `n`, the button or `⌥⌘I` opens the note with the same motion as `v`: the article on the left, the note on the right. The layout button adds the list (three columns). `j` / `k` move between articles with the note open; `Esc` or the ✕ closes it and returns to the screen before. Works without AI; still there after a restart, offline, after unsubscribing and after the body expires. Japanese input is not disturbed | UI tests, real Mac (Japanese input, VoiceOver) |
| PRD-05 | Give the note to another AI | 「Markdownをコピー」 copies the text exactly; the person pastes it into any AI. The app starts no app, makes no file, uses no network. Disabled for an empty note | unit tests, real Mac |
| PRD-06 | (unused) | The app's own summary was removed by decision 0049; the number stays because other documents cite it | — |
| PRD-07 | Review the final demo | The owner sees this table and the product scope demonstrated and approves them explicitly. Until then the product is not accepted | the owner |
| PRD-08 | Set retention and deletion | The periods, the confirmations and "the note is never deleted automatically" of 3.3 hold. An expired body never looks readable | unit tests |
| PRD-09 | Read Stars again | The key and the button change the same state; the Star list can be read in order. Star, title and URL survive a restart and the body's expiry. Star and note are independent | unit tests, synthetic app |
| PRD-10 | (unused) | Sending a summary to a note was removed by decision 0049 | — |
| PRD-11 | Read many articles | Folders, counts without duplicates, icons and article images work; a late, failed or offline image never changes the row height, the selection or the position | UI tests, real Mac |
| PRD-12 | (unused) | Removed by decision 0019 (unsorted Stars, theme suggestions) | — |
| PRD-13 | A Mac without AI | With Writing Tools unavailable, the note can be written, edited and copied, and the app uses no network for AI | real Mac (Writing Tools off) |
| PRD-14 | Add a subscription from a URL | As in 3.5: the check runs when typing stops; 「追加」 only when the feed was read; a site URL finds its feed; `http://` is checked as `https://`, and a feed only on http says that http is not supported; each failure has its sentence; an existing subscription is not added; the folder field appears only when it should | unit tests, synthetic app, real Mac (Japanese input, #136) |
| PRD-15 | Move from another reader with OPML | File ▸ 「OPMLを取り込む…」: subscriptions appear at once, articles arrive later, folders are one level, existing subscriptions do not change, the result is one short sentence | unit tests, real Mac (the menu, a real OPML file, #136) |
| PRD-16 | Manage subscriptions | Right-click: refresh, rename (in the row; Return on the selected row too), move to a folder, unsubscribe. Moving works with the chooser and with drag and drop | unit tests, real Mac (right-click, Return, drag, #136) |
| PRD-17 | Narrow the list with a keyword | As in 3.1.4: `/` or the icon opens the filter; typing narrows the list to the articles of the scope whose title or feed summary contains it; clearing restores it; it stays across scopes and not across launches; `j` / `k` walk the filtered list; composing Japanese does not change the list | `ArticleFilterTests`, `ArticleFilterStoreTests`, `ReaderWorkspaceTests`, `ListFilterTests`; real Mac (the owner, with a library of several thousand articles; a real input method) |
| PRD-18 | Read an article in another language `[not built #154]` | As in 3.6: `t` or the button translates the open article and shows the progress and the result row; again shows the original; moving to another article shows the original; the text of the note, the list and the sidebar does not change; no text leaves the Mac | real Mac (the owner: a long English article into Japanese, a language pack download, a Mac without Apple Intelligence, VoiceOver); `ArticleTranslationTests`, `LanguageDecisionTests`, `TranslationTests`, `TranslationControllerTests` (a fake translator); the language menu: `[not built #154]` |

### 7.1 Conditions to ship 1.0

- The store schema is frozen as a `VersionedSchema`.
- CI runs a required check from the 1.0 release tag: a synthetic store with subscriptions, articles, read times, Stars and the note is opened by the new version and reopened, and nothing is lost. A skipped or not-run check is never a pass. It stays for every later model change.
- The Bundle ID, the store location, signing and the sandbox are fixed, and saving, restarting and updating are checked with them. Whether a beta store opens is checked; if it does not, the person is told how to keep it.
- The version and build numbers, the signature, the notes, the ZIP and its hash can be made again from the repository, and the release says how it differs from CI's ad hoc build.
