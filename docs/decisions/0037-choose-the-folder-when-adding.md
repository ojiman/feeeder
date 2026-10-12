# 0037 Choose the folder when adding a subscription

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) asked whether the folder chooser of 「フォルダへ移動…」 could also appear at registration. The details below are the Product Owner's.
- Refines: [0032](0032-simple-add-subscription.md) (point 2: "there is no folder field") and [0036](0036-check-the-feed-as-you-type.md) (the sheet that checks the address).

## Decision

1. **After the feed was read, a folder field appears under the status line**, with the candidates of the chooser of [0034](0034-move-to-folder-chooser.md) (the existing folders; typing narrows them; a name that is not a folder yet offers 「「…」を作って追加」). It is not a drop-down: it is a text field and a few rows, the same parts as 「フォルダへ移動…」 (`FolderCandidateList`).
2. **The fast path is kept.** Nothing is highlighted until a name is typed or ↑↓ is pressed, so paste, Return adds the subscription as unfiled, as before. Typing a name highlights the best match, so typing and Return goes there. ↑ from the first row goes back to "no folder" while nothing is typed. A click on a row puts its name in the field and highlights it; Return or 「追加」 adds. Return in either field adds. Up to six rows show, the rest scroll.
3. **The field is shown only when it can help:** after a feed was read and is not subscribed yet, when the sheet was not opened with the + of a folder row (that + already decided the folder, and the heading says it), and when at least one folder exists. With no folder the field would only invite a new name; the first folder is still made by 「フォルダへ移動…」 or the chooser later. It is not shown while typing the address, so the sheet stays short and quiet until there is something to choose.
4. **The sheet grows downward when the field appears.** The title and the address field keep their size.

## Not in this change

Finding the feed from a site address. Making the first folder from the add sheet.

## Not verified

Japanese input in the folder field; VoiceOver for the field and the rows; ↑↓ and Return in a real window (the key tool could not send them, so the highlight logic is covered by unit tests of `FolderPicker` only); whether the sheet moving as it grows feels right on the owner's Mac. Run in a synthetic copy of the app (own bundle identifier and data folder, three synthetic folders, a public https feed): the field and the three rows appeared after the check, typing narrowed to one folder plus the "make it" row with the folder highlighted, and Add put the subscription into that folder (its count rose by 20).
