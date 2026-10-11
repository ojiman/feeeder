# 0034 「フォルダへ移動…」 is a chooser with a text field

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) proposed it: 「フォルダへ移動」 should list the existing folders and also take typed text, so typing and moving happen together. He chose no keyboard shortcut for now (it is not used often; keep it simple). The rest is the Product Owner's.

## Decision

1. The context menu item is 「フォルダへ移動…」. It opens a small chooser beside the row: a text field (focused at once, placeholder 「フォルダ名」) and a list of candidates below it.
2. **Candidates** (`FolderPicker`): with nothing typed, 「未分類」 (unless it is already unfiled) and the other folders. Typing narrows the folders by their names (case and width insensitive) and offers 「「名前」を作って移動」 last, unless the typed name is exactly a folder already. Typing 「未分類」 (or part of it) offers unfiled; a folder cannot be named like it. The folder the subscription is in is never a candidate. Names are trimmed like every folder name.
3. **Keys** are those of the chooser of 「ノートに要約を送る」: ↑↓ choose, Return moves, Esc closes. The first candidate is chosen after every keystroke. Moving uses the same glide and folder opening as dragging (decision 0032, #89).
4. **No keyboard shortcut** opens it (the owner's choice). Drag and drop stays for the mouse.
5. The old pull-down menu of folders and the item 「新しいフォルダ…」 with its alert are removed. Only standard controls are used (`TextField`, `Button`).

## Not verified

The chooser in a real window (the test tools cannot open a context menu): how the popover sits beside a row, the focus in the field, the arrow keys while the field has focus, Japanese input in the field (composition and Return), VoiceOver. The candidate logic is tested; the window is not.
