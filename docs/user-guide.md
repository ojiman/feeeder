# Unagi Reader user guide

This guide explains how to start Unagi Reader, how it handles your data, and how to use it. For a short overview, read the [README](../README.md) first.

This is an English translation of the [Japanese user guide](user-guide.ja.md). The app itself is Japanese only. In this guide, an app label is shown in Japanese with an English meaning after it, for example "新しいノート (New note)".

If the two guides differ, check the Japanese guide and the [specification](specification.md), then tell us.

## 1. Start the app

You need a Mac with macOS 27.0 or later and the Swift toolchain from Xcode. From the project root, run:

```sh
bash scripts/build-app.sh release
```

SwiftPM downloads the pinned version of SwiftSoup (2.13.9). The build creates `.build/UnagiReader.app`. Open it from Finder.

- The app is ad hoc signed for local development. It is not signed with a Developer ID and it is not notarized.
- The release build writes temporary files to `/private/tmp/unagi-reader-v1-release`. The debug build writes to `/private/tmp/unagi-reader-debug`. For the debug build you can leave out the argument.

## 2. Your data and updates

### Where the data is

A normal start begins with an empty library. The library is stored in `Application Support/UnagiReader/Reader.store`. If you restart the same version of the app, your subscriptions, articles, read times, stars, and notes are kept.

### Updates during the beta

- **Compatibility between beta versions is not guaranteed.** An older database may fail to open. We have not verified how SwiftData behaves with an incompatible schema.
- If the library cannot be opened, the app shows an error ("ライブラリを開けませんでした", "Could not open the library"). The app never deletes or recreates the library by itself.
- From 1.0 onward, saved data will be kept across updates.
- Release notes for beta versions will state this limit. A check that data survived in one past version does not promise the same for later beta versions.
- There is no migration of data from the earlier prototype.
- **The daily notes, weekly notes, and scraps of the older version are not moved to the note-based version. They are deleted the first time this version starts, and this cannot be undone.** Back up your data before you update (see below).
- **Earlier "themes" are not carried over.** The learning goal, theme names, notes, recorded articles, and the questions, answers and 「いまの理解」 (Current understanding) of the builds that still had themes are not moved to this version. Your subscriptions, articles, read times, and stars stay. **The first time this version starts, the old theme content is gone, and this cannot be undone.** Back up the `UnagiReader` folder first (see the steps below).

### Back up the library by hand

Do this before you update a beta version, or if the app cannot open the library and you want to start again with an empty one. We have not yet tested these steps on a real Mac.

1. Quit Unagi Reader with ⌘Q.
2. In Finder, choose Go > Go to Folder (the Japanese menu is 移動 → フォルダへ移動) and open `~/Library/Application Support/`.
3. Rename the whole `UnagiReader` folder, for example to `UnagiReader-backup-20261007-2100`. Keep `Reader.store` together with `Reader.store-shm` and `Reader.store-wal` if they exist. Do not copy only the database file. The folder also holds note data and hand-off management data.
4. Start Unagi Reader. It creates a new `UnagiReader` folder and an empty library. Keep the renamed folder until you have checked the new one. A backup is not a promise that the data can be converted or restored.

### Try the app with synthetic data

To look around without touching your real library, start a separate instance with its own data directory and demo subscriptions:

```sh
open -n '.build/UnagiReader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo
```

- `--data-directory <path>` is for development checks. It sets where the app stores its data.
- Use `open -n` so that a new instance starts. Without it, `open` can reuse an Unagi Reader that is already running and drop the arguments.
- Before you do anything, check the process arguments (for example with `pgrep -fl UnagiReader`) and check that the window shows the demo subscriptions.
- The demo URLs end in `.example`. No real pages exist there. Do not add real subscriptions, articles, or notes to Git. See [AGENTS.md](../AGENTS.md) for details. We have not re-run this procedure on macOS since it was written down.

## 3. Using the app

### Layout

The window has three columns. In Settings you can choose the appearance: follow the system, light, or dark.

| Column | What it shows |
|---|---|
| Left | Choose what to read. Feeds (すべての記事 all articles, 未読 unread, Star), Notes (the most recently edited first), and Sources (folders and subscriptions). |
| Middle | The list of articles. For a note it is the articles you put into that note. |
| Right | The article. For a note, the note opens beside it as the standard inspector (it opens at once when you select a note; the toolbar button or `⌥⌘I` closes and opens it). |

### Subscriptions and folders

- Click "＋" at the top right of the left column and enter an RSS or Atom URL (an address that starts with `http://` is checked as `https://`; the address of a site works too: the app looks for the feed the page announces, uses the first one, and shows its address under the field). When you stop typing (right away after a paste), the app checks the address and shows "✓" with the feed name under the field, or the reason it could not read it. "追加" (Add) is enabled only when the feed was read (Return also adds). If you have folders, a folder field appears once the feed was read: do nothing and press Return to add it unfiled, or type a name to narrow the folders (a name that is not a folder yet offers "作って追加", make it and add), and use ↑↓ to choose. When you open the sheet with the + of a folder row, the subscription goes into that folder and there is no field. While you type, an address whose host does not look finished is not sent. If the feed is already subscribed, the app says so and does not add it again. The + that appears when you point at a folder row adds to that folder; the other + buttons offer the folder field described above. Right-click a subscription and choose "フォルダへ移動…" to open a small chooser with a text field: type to narrow the existing folders, or type a new name and choose "作って移動" (make it and move into it). Use ↑↓, Return and Esc; "未分類" moves it back to unfiled. You can also move a subscription by dragging it onto a folder row in the sidebar. The row glides to its new place and the folder opens to show it (no motion with Reduce Motion) (drag it onto the "購読元" header to unfile it). The refresh button is next to it. Hold ⌥ (Option) while you open "＋" to get the trouble-shooting tools: typing feed XML by hand and a synthetic sample.
- Right-click a subscription to rename it, put it in a one-level folder, move it, or unsubscribe.
- When you select a folder, the list shows the articles of all subscriptions in it. Right-click a folder to rename or merge it.

### Refresh

The app refreshes on launch, when it returns, and every 30 minutes while it runs. You can also refresh from the toolbar. While it works, the arrow of the refresh button turns. New articles slide in from the top of the list and push the older rows down; if you have scrolled down the list, it stays where you are reading. The motion is the same for manual and automatic refresh, and it is off when Reduce Motion is on. If a download fails, you can still read the articles already saved.

### Reading and keys

Focus the article list, then use these keys:

| Key | Action |
|---|---|
| `j` / `k` | Next / previous article |
| `m` | Mark read / unread |
| `s` | Add or remove a Star |
| `n` | Send a summary to a new or recent note (the icon at the top right does the same) |
| `b` | Open the original page in your browser |
| `v` | Open the original page inside the app |
| `Esc` | Go back to reading |

- Scrolling the list does not mark an article as read. The first read time is saved when the body or the RSS summary is actually shown.
- The in-app browser contacts the site you chose and does not keep you signed in. `j`, `k`, `s`, and `n` also work on the original page. The app gives priority to text fields and to keys used with modifier keys.
- When you open an article, the app shows the text the feed provides (or the RSS summary) as it is. For more, press "v" (the original page in the app) or "b" (your browser). "全文を取得" (Get full text) takes the text from the original page and shows it (menus of the page may be mixed in). When you send a summary to a note and the feed text is short, the AI reads the text of the original page (it is neither saved nor shown). Bodies that earlier versions took from pages are removed at the first start of this version (including ones you fetched on purpose); the feed text comes back for articles that are still in the feed, and "全文を取得" fetches it again.
- Text extraction is best effort. The app labels the text as one of 「フィード提供本文」 (body provided by the feed), 「抽出本文・全文保証なし」 (extracted body, not guaranteed to be complete), or 「RSS要約のみ」 (RSS summary only). If the body cannot be fetched, you still get the summary and a link to the original. The app does not try to get around access limits.
- The list shows favicons and, when available, article thumbnails. The article shows images in the text. Images are best effort. While an image loads or if it fails, the frame keeps its height. The image cache is 64 MiB. Successes are kept for 7 days and failures for 10 minutes. At most 4 images load at the same time.

### Stars and notes

- Press `s` (or use the button at the top right) to star an article. You can read starred articles again from the Star list.
- Press `n` (or 「ノートに要約を送る」 at the top right). Choose 「新しいノート」 (New note) or one of the 8 most recently edited notes. Use ↑/↓, Return to send, and Esc to close. A new note starts with the article title; an existing note receives the summary and source line at its end. The article is linked once; sending again appends again.
- The result offers 「取り消す」 (Undo) for 8 seconds. It restores only what the send made, and refuses if you edited the note. During AI generation, 「中止」 (Cancel) writes nothing. You can keep reading while it runs.
- In a note's article list, right-click 「このノートから外す」 (Remove from this note) to remove the link. It does not change the note text or Star. There is no separate linking picker or `t` key.
- A Star and a note are separate. If you remove the Star, the article stays in its notes.
- When you add an article to a note, the app records its title, URL, and the RSS summary it has at that time. It does not copy the full body.
- Create a note with 「新しいノート」 (New note) in the sidebar. It is empty and opens at once. Right-click a note and choose 「削除…」 (Delete…) to delete it. Deleting a note does not delete its articles or Stars.

### The note

Select a note in the sidebar (the most recently edited is first). The middle column shows the articles you put into it and the right column shows the article you select. The note panel opens beside the article when you select the note. Press the note button in the toolbar, or `⌥⌘I`, to close it and open it again (a note you closed stays closed while the app runs). The button is greyed out when no note is selected.

- A note is one Markdown document. You write plain text in your own words. A line that starts with `#` (up to six, then a space) is a heading and is shown bold and larger. A line that starts with `-`, `*`, `+` or a number such as `1.` is a list item: its mark is coloured and a wrapped line lines up with the text. This changes only how the text looks, never the saved text, and pressing Return does not continue a list. Pasting or dropping text from another app adds plain text only. While you are composing Japanese text, the look waits until you confirm or cancel. There is no length limit. It is saved as you type, exactly as you typed it. A note has no name: **its title is its first line** (without the leading `#` marks and spaces; an empty note is called 「新規ノート」). To change the name, right-click the note in the sidebar and choose "名前を変更…": it rewrites the first line (its `#` marks stay). Only when the window is narrow (under about 1,300 pt), opening the note folds the sidebar away to give room; the small button at the left, above the article list, shows it again or folds it again. Closing the note brings the sidebar back. You can drag the edge of the panel to change its width, and the app keeps the width for the next launch (this is still being checked in a real window).
- The top of the note panel has a share button and two small arrows for the previous and next article. The share menu offers 「Claudeで開く…」 (Open in Claude…), 「Markdownをコピー」 (Copy Markdown), and 「Markdownとして書き出す…」 (Export as Markdown). All three are disabled when the note is empty or has only whitespace.
- Keys: `j` and `k` move between articles in the list, and `s`, `n`, `b`, `v`, `m` work as in the article list, but only when you are not typing in the note or in a field, and never while you compose Japanese text. While you write, `⌥⌘↓` (next article) and `⌥⌘↑` (previous article) work inside the note too.
- **AI writes a summary only when you choose to send it.** It never rewrites your own text.

## 4. On-device AI

The AI runs on your Mac only. Nothing is sent out. Settings → 「要約」 (Summary) holds 「AIで要約する（この Mac の中だけ）」 (Summarize on this Mac), length (1 / up to 3 / up to 5 sentences), format (prose / bullets), and an optional one-line instruction of up to 200 characters. Its words are yours; fixed accuracy rules still apply. The app does not download missing model assets.

AI output is marked 「（AI要約）」 on its source line. When the feed text is short, the AI first reads the original page (up to 10 seconds more). With AI off, unavailable, failed, blank or timed out after 20 seconds, the app sends the retained RSS summary and source, or only the title and URL, without the AI mark. The message tells you what was sent. Turning AI off while a request runs cancels the write. Save or reload errors are shown as failures; after a successful save, a reload failure can leave the write committed, so check the note before sending again.

## 5. How long data is kept

- Article bodies and RSS summaries are kept for 30 days by default. In Settings you can choose 7, 30, 90, or 365 days.
- For an unread article the 30 days start when it is first received. For a read article they start at the first read.
- Shortening the period, or deleting all bodies at once, asks you to confirm what will be removed.
- **The record in a note is never deleted automatically.** This means the article title, link, and the summary saved at that time, and your notes.
- A Star or adding an article to a note does not extend the life of its body.

## 6. Hand-off to Claude Desktop

The share button at the top of the note panel is the only entry point. It offers three actions:

- 「Claudeで開く…」 (Open in Claude…) opens a review screen. It always contains the note only: the full text, the request, output language, byte size, expiry and SHA-256. The request asks Claude to quote what is already solid, identify gaps only from what the note does not say, suggest opposing views worth checking, and suggest what to read or write next. It asks Claude to treat the note as data and not to guess, rewrite it, or write into Unagi Reader. There is no article or source selector.
- 「Markdownをコピー」 (Copy Markdown) copies the note's exact text. 「Markdownとして書き出す…」 (Export as Markdown) saves those same UTF-8 bytes to a `.md` file using a safe version of the note title. The save panel handles an existing file. Neither action adds a newline or sends the text to Claude.

On the review screen, 「全文をコピー」 (Copy all), TXT export, split export, and the file passed to Claude all use the exact review package shown in the preview. Editing the note while this screen is open invalidates the review. Rebuild it before copying, exporting or opening Claude. Nothing leaves your Mac until you press 「Claudeで開く」 on this confirmation screen.
Facts you should know:

- **What was checked:** Claude Desktop 2.19675.0 with Pro and Cowork. Automatic attachment to normal Chat, other versions, and other plans have not been checked.
- The app passes a short request text and the path of a TXT file in a launch link. The note text stays inside the TXT file.
- **You must confirm the attachment in Claude and send the message yourself.** After you send, Claude may ask for permission for another folder. That permission lets Claude read and change files in the folder. Files that are used in the cloud leave your Mac. Unagi Reader puts only the generated package and its management data in a folder of its own. A warning may appear for a request that comes from a link.
- A successful launch does not mean the file was attached, the message was sent, or the file was read.
- If you cancel or the launch fails, you can try again with the same review. You can also copy the full text or export it as a TXT file. If there is a size limit, you can export UTF-8 files split to 1 MiB or less. This split size is not the limit of Claude.
- The copy that the app manages is deleted when its note is deleted or 24 hours after creation. Editing the note keeps the copy as a snapshot until that deadline. Article retention and removal do not affect the copy. Older copies follow their note when its id is present and expire within 24 hours; obsolete article and question fields are ignored.
- A place that you chose for an export, and what has already gone to Claude, are not removed by this.
- You paste a reply into your note by yourself. There is no automatic sending and no automatic writing of replies.

## 7. For developers: tests, CI, and compatibility checks

Run the tests:

```sh
swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build
```

- **CI** runs two jobs in parallel during the beta: regression tests and a release build. A change that touches only `docs/**` or Markdown skips CI.
- **The CI app** is an ad hoc signed development build. It is not signed with a Developer ID, not notarized, and not published as a release. It is different from a ZIP of a released beta.
- **To try a CI build on a Mac,** do not save it with a browser. Run `bash scripts/fetch-ci-app.sh <PR number>`. It needs macOS and a recent, signed-in `gh`. A file saved by a browser gets a quarantine attribute, and macOS blocks an app that is not notarized for every new build. A download with `gh` does not get the attribute. The script also checks that the build matches the head of the PR, verifies the signature, and prints a launch command for synthetic data.
- If macOS blocks an app that you saved with a browser, open System Settings > Privacy & Security and choose "Open Anyway". It needs an administrator password.
- **Compatibility between beta versions is not checked by CI.** A normal `swift test` skips the compatibility test when no fixture is given. To run it by hand:

```sh
bash scripts/prepare-v1-store-fixture.sh /private/tmp/unagi-reader-v1-fixture-new
UNAGI_READER_V1_FIXTURE_DIR=/private/tmp/unagi-reader-v1-fixture-new swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build
```

The fixture directory must not exist yet. The script builds a synthetic database with a fixed commit of a released beta, opens it with the new schema, and checks that the data is kept. When 1.0 ships, the schema will be frozen as `VersionedSchema`, and a check that starts from the 1.0 release tag will be added to CI.

Tests use synthetic RSS and HTML and temporary databases. The [specification](specification.md), the [architecture](architecture.md), and the latest acceptance record (Git history) hold the requirements, the results, and the open items. The final acceptance of the whole V1, and the product owner's decision on the feel of the controls, are not finished.
