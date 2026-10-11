# 0035 Renaming a note

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) could not rename a note and found that not intuitive; he wanted the basic operations of notes to be possible like those of subscriptions. The form is the Product Owner's.

## Decision

1. **Renaming exists, and it rewrites the first line.** A note still has no separate name (decision 0019: the title is the first line that is not empty, without its `#` marks). The context menu of a note in the sidebar has 「名前を変更…」; it asks for a name (the current one is filled in) and changes only the title line: its `#` marks and its line ending stay, and so does everything else the person wrote (`NoteTitle.renamed`, `ReaderStore.renameNote`, through the same save as typing). A note without a title line gets the name as a heading in front. The alert says so: 「ノートの最初の行を書き換えます。」
2. **No separate name field.** Adding one would reverse decision 0019 and bring back a second thing to keep in step with the text, and with the title line that the AI summary and the Markdown export use. Renaming is the same action as editing the first line, with a dialog for people who look for it in the menu.
3. An empty name, or the same name, changes nothing. A note that was edited by the rename moves to the top of the list (it counts as an edit).
4. The other basic operations stay: 「新しいノート」 (the row and the header +), delete (with confirmation). Folders for notes and search remain after V1.

## Not verified

The alert in a real window (the test tools cannot open a context menu); how the open note panel shows the changed first line at once (the editor takes outside text as it does for a sent summary: covered by its tests, not seen in a window); Japanese input in the alert.
