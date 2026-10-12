# 0039 Import subscriptions from an OPML file

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) wanted OPML import. The details below are the Product Owner's.
- Why: a reader is only usable once the person's subscriptions are in it. Typing hundreds of addresses is not an option, and OPML is how every other reader leaves.

## Decision

1. **One entry: File ▸ 「OPMLを取り込む…」** (no key shortcut: it is a rare action). It opens the standard file panel for one `.opml` or `.xml` file. The item is on when the window that shows the library is the active one.
2. **The subscriptions appear at once; the articles follow.** The file is read, and all new subscriptions are added in one save (nothing is fetched first, so a large file does not make the person wait). Then an alert says what happened, and the app fetches the new subscriptions' articles in the background with the normal refresh (it waits for a refresh that is already running). An address that cannot be read shows the usual per-subscription error later; it is not checked at import.
3. **What is read.** Every `<outline>` with an `xmlUrl` (any letter case) is a feed: its name is `title`, then `text`, then the host; `htmlUrl` gives the site (for the icon). An outline without `xmlUrl` that holds feeds is a folder. The app has one level of folders, so a deeper folder is flattened into its top-level folder (Tech ▸ Web ▸ A becomes A in 「Tech」). A folder with no name, or named 「未分類」 (which is no folder), means unfiled. A feed outside any folder is unfiled.
4. **Existing subscriptions are left alone.** A feed the library already has (compared by its address, with the host in lower case) is not added again and is not moved to the file's folder. The same address twice in the file is one feed. Names of existing subscriptions are not changed. A new subscription's name is the file's until its first fetch; then the feed's own title replaces it, as when it is added by address (the person's own renames are kept as always).
5. **Only usable addresses.** `http(s)` with no user name or password. Others are counted, not imported. (A plain `http://` feed is still blocked by the system's transport security when it is fetched; see 0036.)
6. **Safe by the same rules as the feed parser.** At most 5 MB, 2,000 feeds, 64 levels. An `<!ENTITY` is refused; a `<!DOCTYPE>` alone is accepted (real files have one, and it is never loaded). A file that is not OPML, not XML, or too big gives one plain sentence, and nothing is added.
7. **The report is plain.** 「N件の購読を追加しました。」, then what was not taken (「すでに購読している…件」「読めないアドレス…件」), then 「記事は、これから順に届きます。」. With nothing new: 「新しい購読はありませんでした。」; with no feeds in the file: 「このファイルに購読は見つかりませんでした。」.
8. **If the save fails, nothing is added** and the error is shown (one transaction with a rollback, like the other store changes).

## Not in this change

Exporting OPML (the way out; a candidate for the "keep it yours" promise). Choosing which feeds to import (preview screen). Importing by dropping a file onto the window. Checking every address at import.

## Not verified

The File menu item and the file panel in a real window: the test tools could not press the menu while the owner was working, so the menu item's availability (it needs the active library window), the panel, and the alert are checked only by building the app and by reading the menu list (the item is listed under File). The logic is covered by unit tests: the parser, the one-save import with a failed-save case, the report words, and the whole flow with a stubbed file panel and stubbed feeds (articles arrive after the import; cancel does nothing; a second request while the panel is open is ignored). Not run: a real export from another reader (only synthetic files), a file with thousands of feeds, Japanese file names.
