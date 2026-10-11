# 0023 Rename to Unagi Reader

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) chose the name Unagi Reader on 2026-10-10 and answered the open questions for this PR in chat on 2026-10-11: the repository is called `unagi-reader`, and both the data folder and the bundle identifier change.
- Refines: the product name in [0019](0019-v1-simplification-notes.md) and the [vision](../vision.md).

## Decision

1. **The product is called Unagi Reader.** It was called Feeeder. The app shows 「Unagi Reader」 in the window title, the navigation title and the bundle's display name. Old records, old commits and old decision text keep the old name.
2. **Names without spaces are used where a space is awkward.** `UnagiReader` is the User-Agent token (`UnagiReader/1.0`, also the name matched in `robots.txt`), the data folder, the app bundle file (`.build/UnagiReader.app`), the CI artifact names and the file names of the Claude review package (`UnagiReader-review.txt`). The constants are in `AppIdentity` (ReaderCore).
3. **The data folder and the bundle identifier change.** The library is `~/Library/Application Support/UnagiReader/`, the image cache is `~/Library/Caches/UnagiReader/`, and the bundle identifier is `xyz.ojima.UnagiReader` (the reverse of the owner's domain `ojima.xyz`; the old `jp.ojiman.*` names pointed to a domain the owner does not have, and the `.Development` suffix is dropped so the identifier, which is also the key space of the settings, does not have to change again when the app is signed). The log subsystem uses the same value (`AppIdentity.bundleIdentifier`). The app does not read the old folder and does not move it. A person who has a library from the old name moves the folder by hand (steps in the user guides). Settings stored in `UserDefaults` (note panel width, appearance, summary options) start from their defaults, because the bundle identifier is the key space. This is allowed by the beta data policy (decision 0003); doing it now means the folder and the identifier are fixed before the 1.0 schema freeze.
4. **The text of the Claude review package changes on purpose.** Its first line is now `Unagi Reader reading review`, the split header says `Unagi Reader split package`, and the launch prompt says 「添付のUnagi Readerパッケージ」. The note's own bytes, the markers and the rest of the request are the same. The golden test was updated with new hashes; the first hash was checked with an independent SHA-256 of the expected bytes.
5. **The repository is renamed to `unagi-reader` by the owner, after this PR is merged.** GitHub redirects the old address. A small follow-up PR then changes the clone address and the links in the docs. This PR does not change repository URLs, so no link breaks before the rename.

## Not changed (the first two items were changed afterwards: [0024](0024-remove-the-old-name-from-code-and-scratch.md))

- The SwiftPM package, the targets and the executable keep the name `RSSReader` (they are internal; renaming them would only churn imports and the process name used in the docs).
- Scratch paths under `/private/tmp` (`feeeder-*`), the variable names `FEEEDER_*` of the opt-in fixture scripts and the pasteboard names in tests. They are disposable and not visible to users.
- Old decision records, verification records and Git history.
- `docs/vision.md` has one changed sentence: the line that said the rename was still to come. The owner asked for the rename; nothing else in the vision changed.

## Not verified

- Moving a real library by hand (steps are in the guides). Launching the renamed app on a real Mac with the old library moved in.
- Whether Claude Desktop reads the renamed package as well as before (the real launch was never verified; see decision 0021).
- The effect of the new User-Agent on any real site.
