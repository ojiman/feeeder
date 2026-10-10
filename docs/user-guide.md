# Feeeder user guide

This guide explains how to start Feeeder, how it handles your data, and how to use it. For a short overview, read the [README](../README.md) first.

This is an English translation of the [Japanese user guide](user-guide.ja.md). The app itself is Japanese only. In this guide, an app label is shown in Japanese with an English meaning after it, for example "未整理のStar (Unsorted Stars)".

If the two guides differ, check the Japanese guide and the [specification](specification.md), then tell us.

## 1. Start the app

You need a Mac with macOS 27.0 or later and the Swift toolchain from Xcode. From the project root, run:

```sh
bash scripts/build-app.sh release
```

SwiftPM downloads the pinned version of SwiftSoup (2.13.9). The build creates `.build/Feeeder.app`. Open it from Finder.

- The app is ad hoc signed for local development. It is not signed with a Developer ID and it is not notarized.
- The release build writes temporary files to `/private/tmp/feeeder-v1-release`. The debug build writes to `/private/tmp/rss-reader-build`. For the debug build you can leave out the argument.

## 2. Your data and updates

### Where the data is

A normal start begins with an empty library. The library is stored in `Application Support/Feeeder/Reader.store`. If you restart the same version of the app, your subscriptions, articles, read times, stars, and themes are kept.

### Updates during the beta

- **Compatibility between beta versions is not guaranteed.** An older database may fail to open. We have not verified how SwiftData behaves with an incompatible schema.
- If the library cannot be opened, the app shows an error ("ライブラリを開けませんでした", "Could not open the library"). The app never deletes or recreates the library by itself.
- From 1.0 onward, saved data will be kept across updates.
- Release notes for beta versions will state this limit. A check that data survived in one past version does not promise the same for later beta versions.
- There is no migration of data from the earlier prototype.
- **The daily notes, weekly notes, and scraps of the older version are not moved to the theme-based version. They are deleted the first time this version starts, and this cannot be undone.** Back up your data before you update (see below).

### Back up the library by hand

Do this before you update a beta version, or if the app cannot open the library and you want to start again with an empty one. We have not yet tested these steps on a real Mac.

1. Quit Feeeder with ⌘Q.
2. In Finder, choose Go > Go to Folder (the Japanese menu is 移動 → フォルダへ移動) and open `~/Library/Application Support/`.
3. Rename the whole `Feeeder` folder, for example to `Feeeder-backup-20261007-2100`. Keep `Reader.store` together with `Reader.store-shm` and `Reader.store-wal` if they exist. Do not copy only the database file. The folder also holds theme data and hand-off management data.
4. Start Feeeder. It creates a new `Feeeder` folder and an empty library. Keep the renamed folder until you have checked the new one. A backup is not a promise that the data can be converted or restored.

### Try the app with synthetic data

To look around without touching your real library, start a separate instance with its own data directory and demo subscriptions:

```sh
open -n '.build/Feeeder.app' --args --data-directory /private/tmp/feeeder-demo --seed-demo
```

- `--data-directory <path>` is for development checks. It sets where the app stores its data.
- Use `open -n` so that a new instance starts. Without it, `open` can reuse a Feeeder that is already running and drop the arguments.
- Before you do anything, check the process arguments (for example with `pgrep -fl RSSReader`) and check that the window shows the demo subscriptions.
- The demo URLs end in `.example`. No real pages exist there. Do not add real subscriptions, articles, or themes to Git. See [AGENTS.md](../AGENTS.md) for details. We have not re-run this procedure on macOS since it was written down.

## 3. Using the app

### Layout

The window has three columns. In Settings you can choose the appearance: follow the system, light, or dark.

| Column | What it shows |
|---|---|
| Left | Choose what to read. Feeds (すべての記事 all articles, 未読 unread, Star), Themes (未整理のStar unsorted stars, and each theme), and Sources (folders and subscriptions). |
| Middle | The list of articles. For a theme, a switch at the top chooses [記事｜ノート] (Articles \| Note). |
| Right | The article. On the note face a bar above it has previous and next buttons and a menu of the theme's articles. |

### Subscriptions and folders

- Click "＋" at the top right of the left column and enter an RSS or Atom URL. Then choose "unfiled" or an existing folder, or type a new folder name. The refresh button is next to it. You can also import feed XML by hand and a synthetic sample.
- Right-click a subscription to rename it, put it in a one-level folder, move it, or unsubscribe.
- When you select a folder, the list shows the articles of all subscriptions in it. Right-click a folder to rename or merge it.

### Refresh

The app refreshes on launch, when it returns, and every 30 minutes while it runs. You can also refresh from the toolbar. If a download fails, you can still read the articles already saved.

### Reading and keys

Focus the article list, then use these keys:

| Key | Action |
|---|---|
| `j` / `k` | Next / previous article |
| `m` | Mark read / unread |
| `s` | Add or remove a Star |
| `t` | Choose the themes for the article (the icon at the top right does the same) |
| `b` | Open the original page in your browser |
| `v` | Open the original page inside the app |
| `Esc` | Go back to reading |

- Scrolling the list does not mark an article as read. The first read time is saved when the body or the RSS summary is actually shown.
- The in-app browser contacts the site you chose and does not keep you signed in. `j`, `k`, `s`, and `t` also work on the original page. The app gives priority to text fields and to keys used with modifier keys.
- Text extraction is best effort. The app labels the text as one of 「フィード提供本文」 (body provided by the feed), 「抽出本文・全文保証なし」 (extracted body, not guaranteed to be complete), or 「RSS要約のみ」 (RSS summary only). If the body cannot be fetched, you still get the summary and a link to the original. The app does not try to get around access limits.
- The list shows favicons and, when available, article thumbnails. The article shows images in the text. Images are best effort. While an image loads or if it fails, the frame keeps its height. The image cache is 64 MiB. Successes are kept for 7 days and failures for 10 minutes. At most 4 images load at the same time.

### Stars and themes

- Press `s` (or use the button at the top right) to star an article. You can read starred articles again from the Star list.
- Press `t` (or use the icon at the top right) to choose the themes for an article. Check existing themes to add the article or remove it. You can also create a new theme and add the article to it. An article can be in many themes.
- A Star and a theme are separate. If you remove the Star, the article stays in its themes. A starred article that is in no theme appears under 「未整理のStar」 (Unsorted Stars) on the left.
- When you add an article to a theme, the app records its title, URL, and the RSS summary it has at that time. It does not copy the full body.
- Create a theme with 「新しいテーマ」 (New theme) in the sidebar. The sheet asks for a name and, if you want, a learning goal (what you want to learn in this theme, up to 200 characters). The goal is shown under the face switch at the top of the theme; click it, or right-click the theme and choose 「名前とゴールを編集…」 (Edit Name and Goal…), to change the name or the goal. Right-click a theme to edit or delete it. Deleting a theme does not delete its articles or Stars.

### The note in a theme

Select a theme. Use the switch [記事｜ノート] (Articles | Note) at the top of the middle column.

- **Articles** shows the same list and reading view as a source or a folder.
- **Note** shows the one note of this theme in the middle column. You write plain text in your own words. A line that starts with `#` is a heading. There is no length limit. It is saved as you type, exactly as you typed it. When you open the note, the sidebar folds away to give room. The small button at the left of the switch shows it again or folds it again; when you go back to 「記事」 it is shown again. The right column shows an article, so you can read while you write. A bar above it has previous and next buttons and a menu of all the articles of the theme (choose one to open it). Your cursor in the note is kept when you switch to 「記事」 and back (not after you quit the app).
- Keys: `j` and `k` move between articles, and `s`, `t`, `b`, `v`, `m` work as in the article list, but only when you are not typing in the note or in a field, and never while you compose Japanese text. While you write, `⌥⌘↓` (next article) and `⌥⌘↑` (previous article) work inside the note too.
- **The AI never writes into your note.**

**Questions and answers from an older version.** Earlier versions had questions with lenses, answers, evidence articles, and 「いまの理解」 (Current understanding). The first time this version opens your library, the app moves them into the note of each theme: the old 「いまの理解」 text first, then for each question a heading line `# <question>`, your answer under it, and the line `根拠の記事:` (Evidence articles:) with a list of the article titles and links. The app checks that the note contains all of your old text. Then it saves the notes and removes the old records in one step. It tells you once with a message, 「ノートにまとめました」. The name of the lens, the "answered" mark, and the dates of questions are not kept. If something goes wrong, nothing is removed. The app says so and tries again at the next start; you can also choose 「再試行」 (Retry). **Before you start this version for the first time, copy the whole `Feeeder` folder** (see "Back up the library by hand" above), because this change cannot be undone.

## 4. On-device AI

The AI features run on your Mac only. Nothing is sent out. They never write into your note. You can turn them off in Settings under 「端末内AI」 (On-device AI). When they are off, the app does not call the model. You can also see their state there.

If the language assets are not on your Mac, the app does not download them. Suggestions just do not appear.

- **Near themes.** When you press `t`, themes with content close to the article come first and have a 「近い」 (Near) mark. Once you start typing or pressing ↑↓, the order stops moving.
- **Suggested groups.** Open 「未整理のStar」 (Unsorted Stars). A card 「まとまりの提案」 (Suggested groups) shows groups of articles with similar content. From a group you can give a name and create a theme.
- **Theme-name idea.** When you create a theme from a group, a line "案: … ［使う］" (Idea: … [Use]) appears under the name field. The field is not filled by itself.
- Ideas are made by the on-device model and stop after 10 seconds. If the model is not available or fails, nothing appears.

## 5. How long data is kept

- Article bodies and RSS summaries are kept for 30 days by default. In Settings you can choose 7, 30, 90, or 365 days.
- For an unread article the 30 days start when it is first received. For a read article they start at the first read.
- Shortening the period, or deleting all bodies at once, asks you to confirm what will be removed.
- **The record in a theme is never deleted automatically.** This means the article title, link, and the summary saved at that time, and your notes.
- A Star or adding an article to a theme does not extend the life of its body.

## 6. Hand-off to Claude Desktop

The entry point is the toolbar button 「Claudeで開く…」 (Open in Claude…), which appears when you select a theme (on both the Articles face and the Questions face). It opens the review screen. This is how the hand-off works.

1. On the review screen you choose the output language and the sources.
2. The screen separates saved RSS summaries from articles that are still stored. You review the complete text, the coverage, and the source URLs.
3. You press 「Claudeで開く」 (Open in Claude).

On the review screen you can also choose:

- The theme's note is not included yet. Your questions and answers moved into the note, so the review screen says 「テーマのノートはまだ Claude へ渡せません。」 (The theme's note can not be handed to Claude yet.). A later version will let you include the note (off by default). At least one source is required.

After you review, if the theme name or the title of an included source changes, the review becomes invalid and you must make it again.

Facts you should know:

- **What was checked:** Claude Desktop 2.19675.0 with Pro and Cowork. Automatic attachment to normal Chat, other versions, and other plans have not been checked.
- The app passes a short request text and the path of a TXT file in a launch link. The article text stays inside the TXT file.
- **You must confirm the attachment in Claude and send the message yourself.** After you send, Claude may ask for permission for another folder. That permission lets Claude read and change files in the folder. Files that are used in the cloud leave your Mac. Feeeder puts only the generated package and its management data in a folder of its own. A warning may appear for a request that comes from a link.
- A successful launch does not mean the file was attached, the message was sent, or the file was read.
- If you cancel or the launch fails, you can try again with the same review. You can also copy the full text or export it as a TXT file. If there is a size limit, you can export UTF-8 files split to 1 MiB or less. This split size is not the limit of Claude.
- The copy that the app manages is deleted when its theme or a source it includes is deleted. The copy is also deleted when an article it contains is removed from the theme. If you only rename the theme after the copy was made, the copy is not deleted; it stays as a snapshot until its time limit. The copy is kept for up to 24 hours after it is made. If it contains stored articles, the earliest expiry date of the original bodies is also an upper limit. If it holds saved summaries only, it does not expire with the original article. Shortening the retention period or deleting bodies also removes it.
- A place that you chose for an export, and what has already gone to Claude, are not removed by this.
- You paste a reply into your note by yourself. There is no automatic sending and no automatic writing of replies.

## 7. For developers: tests, CI, and compatibility checks

Run the tests:

```sh
swift test --scratch-path /private/tmp/feeeder-dogfooding-build
```

- **CI** runs two jobs in parallel during the beta: regression tests and a release build. A change that touches only `docs/**` or Markdown skips CI.
- **The CI app** is an ad hoc signed development build. It is not signed with a Developer ID, not notarized, and not published as a release. It is different from a ZIP of a released beta.
- **To try a CI build on a Mac,** do not save it with a browser. Run `bash scripts/fetch-ci-app.sh <PR number>`. It needs macOS and a recent, signed-in `gh`. A file saved by a browser gets a quarantine attribute, and macOS blocks an app that is not notarized for every new build. A download with `gh` does not get the attribute. The script also checks that the build matches the head of the PR, verifies the signature, and prints a launch command for synthetic data.
- If macOS blocks an app that you saved with a browser, open System Settings > Privacy & Security and choose "Open Anyway". It needs an administrator password.
- **Compatibility between beta versions is not checked by CI.** A normal `swift test` skips the compatibility test when no fixture is given. To run it by hand:

```sh
bash scripts/prepare-v1-store-fixture.sh /private/tmp/feeeder-v1-fixture-new
FEEEDER_V1_FIXTURE_DIR=/private/tmp/feeeder-v1-fixture-new swift test --scratch-path /private/tmp/feeeder-dogfooding-build
```

The fixture directory must not exist yet. The script builds a synthetic database with a fixed commit of a released beta, opens it with the new schema, and checks that the data is kept. When 1.0 ships, the schema will be frozen as `VersionedSchema`, and a check that starts from the 1.0 release tag will be added to CI.

Tests use synthetic RSS and HTML and temporary databases. The [specification](specification.md), the [architecture](architecture.md), and the [latest acceptance record](verification/2026-10-07-dogfooding-acceptance.md) hold the requirements, the results, and the open items. The final acceptance of the whole V1, and the product owner's decision on the feel of the controls, are not finished.
