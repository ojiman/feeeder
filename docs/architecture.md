# Architecture

How Unagi Reader is built, and the technical contracts a change must keep. What the person sees is in the [specification](specification.md); why a choice was made is in the [decision records](decisions/README.md); how agents work on the code is in [AGENTS.md](../AGENTS.md). Sizes, colours and timings live in the code constants named here, not in this file.

## 1. Parts

| Part | Built with |
|---|---|
| Window | SwiftUI `NavigationSplitView` (sidebar, list, reading area) with the note as an `.inspector` of the reading area |
| Article list | AppKit `NSTableView` (`NativeArticleList`, sizes in `NativeArticleList.Metrics`) |
| Article text | AppKit `NSTextView` (`NativeArticleText`) |
| Original page | `WKWebView` (`OriginalPageView`) |
| Note editor | AppKit `NSTextView` in an `NSViewRepresentable` (`NoteTextEditor`); SwiftUI's `TextEditor` cannot set display attributes |
| Core | `Sources/ReaderCore`: SwiftData models, `ReaderStore`, feed parsing (`XMLParser`), extraction, retention. No UI |
| Network | `URLSession` on the Mac. SwiftSoup 2.13.9, pinned exactly, for extraction |
| Store | `Application Support/UnagiReader/Reader.store`. `--data-directory <path>` and `--seed-demo` start a synthetic library; a normal start never adds demo data |

There is no backend, no account and no AI proxy. The app has no AI of its own ([decision 0049](decisions/0049-one-note-and-no-ai-of-its-own.md)); the note editor is a standard text view, so the system's Writing Tools appear on their own (`writingToolsBehavior` is not changed).

## 2. Input from the network is untrusted

- Every URL is checked for its scheme; redirects are checked before they are followed. Extraction does not follow HTTP redirects.
- The feed parser and `OPMLParser` refuse XML entity declarations (`<!ENTITY`). `OPMLParser` reads at most 5 MB, 2,000 outlines and 64 levels.
- Extracted HTML is never run; `ArticleMarkup` turns RSS HTML, Atom XHTML and extracted text into paragraphs, UTF-16 link ranges (HTTP(S) only) and quote depth. A link is checked again when it is clicked.
- Extraction (`ArticleExtractor`) takes the paragraphs of `article`, then `main`. `ExtractionQuality` rejects a result made mostly of short fragments (menus, numbers). It runs only when the person presses 「全文を取得」 ([decision 0033](decisions/0033-rss-first.md)).
- Logins, robots rules (`RobotsPolicy`) and paywalls are never bypassed.

## 3. Store

`ReaderStore.schema` has six models: `Feed`, `Article`, `ContentSnapshot`, `FeedMembership`, `ReaderSettings`, `Note`.

- An article's identity, first-received and first-read times, Star and memberships are kept apart from its body (`ContentSnapshot`, which expires). `FeedMembership` joins one article to several subscriptions, so counts are not doubled.
- `Feed.folder` is a one-level string; there is no folder model, so an empty folder cannot exist.
- `Article.starredAt` non-nil means starred; starring again uses the current time; there is no history of Star changes.
- `Note` has `text`, created and updated times. There is exactly one: `ReaderStore.note`. `saveNote(text:at:)` saves the text exactly as typed, with no length limit; with no note it throws `missingNote`. When the store opens, `keepOnlyOneNote(at:)` keeps the most recently edited note (ties: the lower ID), deletes the others, or creates an empty one; a failed save fails the open.
- Data compatibility follows [decision 0003](decisions/0003-beta-data-compatibility.md): none promised between betas; from 1.0, preserved and checked in CI ([specification 7.1](specification.md)). An unreadable store is never deleted or recreated by the app.
- Opt-in upgrade tests open synthetic stores made by older builds: `V1StoreUpgradeTests` (`UNAGI_READER_V1_FIXTURE_DIR`, made by `scripts/prepare-v1-store-fixture.sh`), `PreNoteStoreUpgradeTests` (`UNAGI_READER_PRE0019_FIXTURE_DIR`, commit `52429b4`), `OneNoteStoreUpgradeTests` (`UNAGI_READER_PRE0049_FIXTURE_DIR`, commit `60da7df`; [record](verification/0049-one-note-store.md)). Opening an old store drops the tables of removed models; CoreData logs this as `error:`, which is harmless.

### 3.1 Save failure and recovery

- After a failed save, `ReaderStore.rollback()` swaps in a fresh `ModelContext` on the same container. Values from the failed context are never shown.
- `needsReload` blocks every change until `reloadIfNeeded()` succeeds. A new mutating method calls `reloadIfNeeded()` first and resolves models by ID, not by a reference taken before the failure.
- One operation is never committed in part, and a failed change is never reported as done. Every change path (read, subscription, Star, note, retention) has a save-failure and reload-failure test; a new path gets one too.

### 3.2 Indexes and late results

- `ReaderStore` keeps indexes of articles, subscriptions, unread, Star and folders; lists hold ID arrays, not all models.
- A late fetch or render is checked against the article ID and a generation number, so it never changes another article or its read state. After the person acts, the same article's body is not replaced on its own.

### 3.3 Retention

- `purgeExpired(at:)` (`ContentRetention`) runs at launch, on return to the app and every 30 minutes. Expired or deleted bodies and images do not come back when a feed is received again. Changing the period checks both the old and the new limit.
- `ContentSnapshot.bodyFormatData` (optional JSON) holds the link and quote layout; it is used only when it matches the saved text, else the plain text is shown. Deleting a body deletes its snapshot and format.

## 4. Screen contracts

### 4.1 Layout and motion

- `SidebarFold` (ReaderCore, pure) decides the columns: `folded(pageOpen:noteOpen:)` for the sidebar, `listFolded(noteOpen:listShown:)` for the list. Every fold, return and slide is one `withAnimation` of `SidebarFold.motionDuration`; with Reduce Motion nothing moves.
- `NavigationSplitView` cannot fold its middle column, so `ListColumnCollapse` finds the AppKit `NSSplitViewItem`, sets `canCollapse` for the moment, and changes `isCollapsed` inside the same `NSAnimationContext`. It remembers the list width and restores it after the return (the note panel is still there in the first frame and squeezes the list).
- After a fold the input focus goes to the article text so `j` / `k` keep working; the note editor takes focus only when clicked.
- Hosted tests that fold columns run one after another under `SplitViewFoldTests`.
- `OriginalPageState.selectionChanged` closes the original page when another article is chosen; keys and clicks share one selection path.
- Moving to the next or previous article animates the reading view's layer (`CAAnimationGroup`); the direction comes from the list order. It does not play for a body update of the same article.
- `NativeArticleList` inserts new leading rows with an animation only when `ListInsertion.leadingCount` says the new order is "new rows + old order", at most 20, the list is at the top and the selection did not change; otherwise it reloads and keeps the visible article in place.

### 4.2 The note panel

- `NotePanel` is the inspector. Its width is set by `inspectorColumnWidth` on the panel's content (on the inspector itself it has no effect). `NotePanelWidth` holds the range, the default and the saved value in `UserDefaults`, clamped on save and load.
- `NotePanelWidthMemory` measures with `onGeometryChange` and saves once the width has been still for 0.6 s. The width is not `ReaderView` state: that redrew the whole window on every drag frame and froze it.
- `ReaderWorkspaceState.noteOpen` and `noteListShown` live in memory only. `toggleNote` changes `noteOpen` and the column visibility in one animation. Dragging the edge shut reopens the panel on the next turn (`noteOpenBinding`).
- `NoteTextEditor` styles headings and list markers through `NoteLineStyle.runs(in:baseOffset:)` (ReaderCore, pure) and `NoteEditorStyle`. It changes display attributes only, in `NSTextStorageDelegate.didProcessEditing` for the edited paragraphs, never the text. It does nothing while `hasMarkedText()` is true. Paste and drop take plain text only; smart quotes, dashes, replacement and link detection are off. `textDidChange` saves once per change.
- 「Markdownをコピー」 (`ReaderView.copyNote`) writes the saved text as one `NSPasteboardItem` string; a failure shows an error. `LegacyHandoffFolder` deletes the `Handoffs` folder that older builds made (a link is removed, not followed).

### 4.3 Keys

- `ReaderKeyboardCommands` treats only an editable `NSTextView` or `NSTextField` as typing. Single-letter keys do not act while typing, while composing with an input method, or while a sheet is open.
- In the original page, keys come from a separate `WKContentWorld`; they are checked for a real key press, an input element, an input method, modifier keys and the current article.

### 4.4 Colours and the window

- `AppPalette` holds every colour. The reading surface is one fixed value (`surface`) for the list, the article, the note and the window; `textBackgroundColor` is not used because it turns vibrant inside split view columns. The toolbar background is hidden.
- `SoftRow` draws the list selection with `isEmphasized` always false (no system blue). The accent is a calm orange with light and dark values.

### 4.5 Images and icons

- One actor fetches, checks, scales (ImageIO) and caches images and subscription icons off the main actor. The same scheme and redirect checks apply. No third-party favicon service gets the subscription URLs.
- Limits: response 4 MiB, 20,000,000 pixels before decoding, longest side 1,200 px after scaling; disk cache 64 MiB; success kept 7 days, failure 10 minutes; 4 fetches at a time.
- Each result is checked for the ID, the URL and cancellation. A late image never changes a row height, the selection or the reading position: image frames are fixed, and hosted views in the text have a fixed frame.
- Image choice: enclosure, media, then images in the body. `hatena:imageurl` (checked by namespace) and HTML `entry-image` come first; images in `cite`, favicons, bookmark counters and images marked small are skipped.

## 5. Build and CI

The toolchains, the CI jobs and when each one runs are in [AGENTS.md](../AGENTS.md#commands). Two facts shape the code:

- CI builds on macOS 26.6 (the build floor); the support floor macOS 27.0 is checked only on the local Mac ([decision 0007](decisions/0007-support-floor-macos-27.md)). Do not use APIs that need the macOS 27 SDK.
- `release` makes an ad hoc signed app and checks the signature after a ZIP round trip. There is no Developer ID signing, notarization or automatic release.
