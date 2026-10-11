# 0025 The feel of a refresh

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) described what feels good in the feed reader he uses (the arrow turns, new articles slide in from the top and push the old ones down, and automatic refresh moves the same way) and asked for it. The points marked "PO" are the Product Owner's.
- Refines: the vision (the loop must never make the person wait; comfort is part of the value).

## Decision

1. **The refresh button shows work by turning its arrow** (`symbolEffect(.rotate)`), not by swapping the arrow for a small spinner. The button stays enabled; pressing it again while a refresh runs does nothing (`FeedRefreshController.refresh` ignores a second call). VoiceOver says 「更新中」. *(PO.)*
2. **New articles slide in.** When a refresh brings new articles and they all go in front of the list that is shown, they slide in from the top and push the old rows down (`insertRows` with slide and fade). This happens only when the list is at its top, the selection did not change, and there are 1 to 20 new rows. *(PO: the limit, so a long catch-up does not push the old rows far away.)*
3. **A reader who has scrolled down is never moved.** In every other case (first load, removal, reorder, insertion elsewhere, more than 20, list not at the top) the rows are reloaded and the article the person looks at stays where it is, as before.
4. **Reduce Motion turns the sliding off** (the arrow follows the system setting). The list then changes without motion.
5. **Manual and automatic refresh move the same way**, because they use one path. Automatic refresh stays as it was: at launch, when the app becomes active, and every 30 minutes. A shorter interval is not part of this decision. *(PO.)*

## Not verified

- How the slide-in looks and feels in a real window. Tests check the decision and the result (rows, selection, position), not the animation frames.
- Reduce Motion in the system settings; a very long list (10,000 rows) while an insertion animates.
- The turning arrow in a real title bar over a long refresh.
