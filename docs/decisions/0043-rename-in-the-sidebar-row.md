# 0043 Rename in the sidebar row

- Status: valid for subscriptions. The renaming of notes is replaced by [0049](0049-one-note-and-no-ai-of-its-own.md) (one note, no name).
- Date: 2026-10-12
- Decider: the owner (PdM) agreed to the Product Owner's advice in a discussion of note management: say the same things in the same way for notes and subscriptions. The details below are the Product Owner's.
- Refines: 0035 (Git history) (the note's name was asked for in an alert) and [0032](0032-simple-add-subscription.md) point 3 (a subscription's name was edited in a sheet).

## Decision

1. **A note's or a subscription's name is edited in its sidebar row.** The name becomes a text field in the row, with all of it selected. Return finishes; Esc cancels; moving away (a click on another row) finishes, as in the Finder. An empty name, or a name that did not change, saves nothing (`NameEdit.result`). The field starts empty for an untitled note: 「新規ノート」 is a label, not a name.
2. **Two ways in, the same words in both menus:** the context menu item 「名前を変更」 (no dots: it starts the edit at once; the dots meant that more input is asked), and Return while the keyboard is in the sidebar and a note or a subscription is selected. The context menus now read alike: a subscription has 「この購読を更新」, 「名前を変更」, 「フォルダへ移動…」, 「購読を解除…」; a note has 「名前を変更」, 「削除…」.
3. **The edit sheet of a subscription and the rename alert of a note are gone** (less code, one way). The add sheet only adds.
4. **A note's name is still its first line** (0019, 0035): renaming rewrites it, and the note moves to the top as the most recently edited.
5. **A folder is renamed as before, with the question** (「名前を変更…」, with the dots): a folder name that already exists means merging, an empty name means unfiled, and a field in a row cannot ask. Only the words of the menu item were aligned.

## Not in this change

Note folders (the notes stay one flat list). Inline rename of a folder row.

## Not verified

The test tools cannot open context menus or send a real Return key to the sidebar, so neither the context menu item nor Return starting the edit was exercised in a window; please try both. Checked in a synthetic copy of the app (own bundle identifier and data folder) with a temporary build that opened the edit at launch: the field appeared in the subscription's row with its name selected, a new name could be typed, and moving to another row finished the edit and showed the new name in the sidebar. Not checked in a window: Esc, Return inside the field, the note row, Japanese input while composing (a half-composed name is not committed by moving away: not verified), VoiceOver. The rules of the typed name are covered by unit tests.
