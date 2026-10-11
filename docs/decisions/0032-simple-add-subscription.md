# 0032 A simple "add subscription" sheet

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) found the sheet not simple and wanted fewer words, with the operation shown by the UI. The choices below are the Product Owner's.

## Decision

1. The sheet has a short title, **one URL field** (the placeholder is an example URL, `https://example.com/feed.xml`, so no sentence is needed), **one folder field** and the buttons 「キャンセル」 and 「追加」. The explaining sentence, the sentence under the folder field, the label "フィードURL" and the long button text 「取得して取り込む」 are gone.
2. **The folder is a combo box** (`NSComboBox`): a text field with a list. The person chooses an existing folder from the list or types a new name; empty means unfiled. This replaces a text field plus a pull-down menu 「既存から選ぶ」. Apple's guidelines say to use a combo box when the person can pick from a list or enter their own value.
3. **The XML input and the synthetic samples** (trouble-shooting tools) are offered only when the sheet is opened with the Option key held. They are described in the user guides.
4. Editing a subscription uses the same folder field; its explaining sentence is gone too. The text of the button after a partial import (some entries without an identifier) is 「取り込む」.

## Not verified

Typing in the combo box with a Japanese input method (composition, candidates); VoiceOver for the combo box; the sheet with many folders (the list shows 8 at a time).
