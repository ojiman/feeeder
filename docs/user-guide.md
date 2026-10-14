# Unagi Reader user guide

How to start Unagi Reader, how it keeps your data, and how to use it. The app is Japanese only; a label is shown here in Japanese with its meaning, for example 「全文を取得」 (Get full text). If this guide and the app differ, the [specification](specification.md) decides; please tell us.

## 1. Start the app

You need macOS 27.0 or later and the Swift toolchain from Xcode. From the project folder:

```sh
bash scripts/build-app.sh release
```

This makes `.build/Unagi Reader.app`; open it from Finder. It is ad hoc signed, not signed with a Developer ID and not notarized.

To look around without your real library, start a separate copy with synthetic subscriptions:

```sh
open -n '.build/Unagi Reader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo
```

Use `open -n`: without it, macOS can reuse a running Unagi Reader and ignore the arguments. Check that the window shows the demo subscriptions (their addresses end in `.example`) before you do anything.

## 2. Your data

- The library is `~/Library/Application Support/UnagiReader/Reader.store`. A new library starts empty. Restarting the same version keeps everything.
- **During the beta, a new version may not open an older library.** The app then shows 「ライブラリを開けませんでした」 (Could not open the library) and never deletes or recreates it by itself. From 1.0, data is kept across updates.
- Builds before the one-note version kept themes, daily and weekly notes, or several notes. The first start of a newer build keeps your subscriptions, articles, read times and Stars, keeps only the note you edited last, and deletes the rest. This cannot be undone.

### Back up the library by hand

Do this before you update a beta, or when the app cannot open the library and you want to start again empty. These steps have not been tried on a real Mac yet.

1. Quit Unagi Reader (⌘Q).
2. In Finder choose Go ▸ Go to Folder (移動 ▸ フォルダへ移動) and open `~/Library/Application Support/`.
3. Rename the whole `UnagiReader` folder, for example to `UnagiReader-backup-20261014`. Keep `Reader.store`, `Reader.store-shm` and `Reader.store-wal` together; do not copy only one file.
4. Start Unagi Reader. It makes a new, empty library. Keep the renamed folder until you have checked the new one. A backup is not a promise that the data can be converted back.

## 3. Using the app

### The screen

The window has four areas: the sidebar, the list, the article and the note. Normally you see the first three. `v` shows the original page (the sidebar folds away and the page takes its place). `n` shows the note beside the article (the sidebar and the list fold away); the layout button next to the note button in the toolbar brings the list back beside them, and hides it again. Appearance (system, light or dark) is in Settings.

### Subscriptions and folders

- **Add:** click ＋ at the top right of the sidebar and type an RSS or Atom address, or a site's address (the app finds the feed the page announces). An `http://` address is checked as `https://`. When you stop typing, the line under the field shows 「✓」 and the feed's name, or why it could not be read. 「追加」 (Add) works only when the feed was read; Return also adds.
- **Folder when adding:** if you have folders, a folder field appears once the feed is read. Press Return to add it unfiled, or type to choose a folder; a new name offers 「作って追加」 (make it and add). The ＋ on a folder row adds straight into that folder.
- **Import from another reader:** File ▸ 「OPMLを取り込む…」 (Import OPML). The subscriptions appear at once and their articles follow. Existing subscriptions do not change. Folders are one level deep.
- **Manage:** right-click a subscription to refresh, rename (in the row; Return on the selected row too), move to a folder, or unsubscribe. 「フォルダへ移動…」 (Move to folder) opens a chooser: type to narrow, or type a new name and choose 「作って移動」; 「未分類」 (unfiled) moves it out. You can also drag a subscription onto a folder, or onto the 「購読元」 heading to unfile it.
- Right-click a folder to rename it; a name that already exists joins the two folders.
- Hold ⌥ (Option) while you click ＋ for the troubleshooting tools (feed XML by hand, a synthetic sample).

### Refresh

The app refreshes at launch, when you come back to it, and every 30 minutes; the toolbar button refreshes by hand, and its arrow turns while it works. New articles slide in at the top of the list; if you have scrolled down, the list stays where you are. If a download fails, the saved articles can still be read.

### Reading and keys

| Key | Action |
|---|---|
| `j` / `k` | Next / previous article |
| `m` | Read / unread |
| `s` | Star on / off |
| `n` | Open or close the note (also the toolbar button and `⌥⌘I`) |
| `t` | Translate the article into Japanese, on your Mac; again shows the original (also the toolbar button and 表示 ▸ 翻訳). The first time, macOS may ask to download the language |
| `/` | Narrow the list: type words from the titles or summaries (also the magnifier next to the list title). `Esc` in the empty field closes it |
| `b` | Open the original page in your browser |
| `v` | Open the original page in the app. The ✕ at its top left, `Esc` or choosing another article closes it |
| `Esc` | Back to reading: closes the original page, or the note |

- Keys do not act while you type in a field or compose Japanese text. `j`, `k`, `s` and `n` also work on the original page.
- An article becomes read when its text is shown, not when you scroll past it in the list.
- The app shows the feed's own text (or its summary). 「全文を取得」 (Get full text) takes the text from the original page; parts of the page's menus may come with it. The end of the text says what you have: 「フィード提供本文」 (the feed's text), 「抽出本文 · 全文保証なし」 (extracted, may be incomplete) or 「RSS要約のみ」 (summary only). The app never gets around paywalls or logins.
- The in-app browser does not keep you signed in to sites.
- `s` or the button at the top right stars an article; the Star list shows them again.

### The note

There is one note and nothing to manage: no list, no names, no delete.

- `n`, `⌥⌘I` or the toolbar button opens it beside the article in a short move; the same again, or the ✕ at the top left of the note, closes it and returns you to where you were. It is the same note on every screen.
- It is plain Markdown in your own words, saved as you type, exactly as typed. A line starting with `#` is shown as a heading; a line starting with `-`, `*`, `+` or `1.` as a list item. Only the look changes, never the saved text. Paste adds plain text only.
- `j` / `k` change the article while the note stays open (not while you type in the note). While you write, `⌥⌘↓` and `⌥⌘↑` change the article, and so do the two arrows above the note.
- Drag the panel's edge to change its width; the width is kept.
- 「Markdownをコピー」 (Copy Markdown) at the top of the note copies its exact text. It is disabled for an empty note.

## 4. AI

The app has no AI of its own. It does not summarize, suggest or write, and it never talks to an AI service.

- **While you write:** on a Mac with Apple Intelligence, select text in the note and right-click for the system's Writing Tools (proofread, rewrite, summary, list, table and more).
- **To ask another AI:** press 「Markdownをコピー」 and paste the note into the AI you like. Nothing leaves your Mac unless you paste it yourself.

## 5. How long data is kept

- Article texts and summaries: 30 days by default; 7, 30, 90 or 365 days in Settings. For an unread article the days count from when it arrived, for a read one from when you first read it. A Star does not extend them.
- When the text expires, the title, the link and the Star stay.
- Shortening the period, or deleting all texts at once, asks you first.
- **The note is never deleted by the app.**

## 6. For developers

Commands, tests, CI and the rules for contributors are in [AGENTS.md](../AGENTS.md); how the app is built is in the [architecture](architecture.md).
