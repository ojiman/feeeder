# 0032 A simple "add subscription" sheet

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) found the sheet not simple and wanted fewer words, with the operation shown by the UI. The choices below are the Product Owner's.

## Decision

1. The sheet has a short title, **one URL field** (the placeholder is an example URL, `https://example.com/feed.xml`, so no sentence is needed) and the buttons 「キャンセル」 and 「追加」. The explaining sentences, the label 「フィードURL」 and the long button text 「取得して取り込む」 are gone.
2. **There is no folder field, and no drop-down of any kind.** The folder is decided by where the + was pressed: the + at the top left and the + in the 「購読元」 header add to unfiled; a + that appears (in place of the count) while the pointer is over a folder row adds to that folder. The title of the sheet says where it goes (「「Tech」に購読を追加」). The owner chose this ("A") over a row of flat chips ("B") after seeing both as mock-ups. A combo box was tried in between and dropped: it is still a drop-down.
3. **Moving a subscription** is done in the sidebar: the context menu 「フォルダへ移動」 (existing folders, unfiled, and 「新しいフォルダ…」, which asks for a name; a folder exists as long as a subscription is in it) and drag and drop onto a folder row, or onto the 「購読元」 header to unfile (`FeedDrag`, visible only inside this app). Editing a subscription changes only its name.
4. **The XML input and the synthetic samples** (trouble-shooting tools) are offered only when the sheet is opened with the Option key held. They are described in the user guides.
5. The standard controls are used as they are (`TextField`, `Button`, `Label`): nothing is drawn by hand.

## Not verified

The + on a folder row in a real window (the pointer cannot be moved by the test tools); VoiceOver for the + on a row; adding a feed from the sheet end to end (the demo data has no reachable feed).
