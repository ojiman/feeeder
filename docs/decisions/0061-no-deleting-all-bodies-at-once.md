# 0061 No action deletes all article bodies at once

- Status: valid (built; no action deletes all bodies at once)
- Date: 2026-10-18
- Decider: the owner (PdM), in the chat of 2026-10-18. The agent proposed removing the action; the owner agreed, and chose the new pane layout of Settings with it.

## Why

Settings ▸ 「保存」 had 「記事本文・RSS要約」 「削除…」: it deleted every article body and RSS summary at once, after a confirmation. It was a way to free disk space while the app stored pages it had extracted. Since [0056](0056-the-feed-text-only.md) the app keeps only the feed's text, which is small, and the retention period already removes old text. The action could not be undone and stayed in Settings for a need that is gone.

| Question of the vision | Answer |
|---|---|
| Does it make the loop smoother? | Removing it changes nothing in reading or the note. |
| Does it add something to manage? | It took away one destructive choice. |
| Can it make the reader wait? | No. |
| Can text leave the Mac? | No. |

## Decision

1. **Nothing deletes all article bodies and RSS summaries at once.** The retention period (7, 30, 90 or 365 days) removes them. Shortening the period still shows what will go and asks first.
2. **The note, Stars, titles and URLs are not affected**; they were never part of this action.

With the action gone, the 「保存」 pane would hold one choice. Settings therefore become three panes, 「一般」, 「記事」 and 「ショートカット」 (specification 3.7). That layout is in the specification only.

## Not included

No change to the retention choices or how they are counted. No 「ノート」 pane, and no choice of how 「記事をノートに送る」 formats its text, until there is a concrete need. The code is #292.
