# 0031 Less clutter in the window

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) asked what the block at the bottom left of the sidebar was for and whether it could go, then asked for a clean-up of extras. The choice of what else to remove is the Product Owner's (the agent), under the vision: nothing is added that the person has to look at or manage.

## Decision

Two things that never did anything are removed:

1. **The block at the bottom of the sidebar** (「ローカルライブラリ」 and the note 「＋からURLで購読。30分ごとに記事を更新します。」). It was an explanation, not a control. The ways to add a source are the + at the top left, the + in the 「購読元」 header, and the text of the empty list. That data stays on the Mac is promised in the README and the user guide.
2. **The line of key hints at the bottom of the article list** (「j/k 移動 s Star n 要約を送る b/v 原文」). It was always on screen. The keys are in the user guide, and the tooltip of each toolbar button shows its key (for example 「ノートに要約を送る (n)」).

## Not verified

Whether a new person finds the keys without the hint line (the tooltips and the guide remain). If they do not, a hint can come back as a first-run help or a menu item, not as a permanent line.
