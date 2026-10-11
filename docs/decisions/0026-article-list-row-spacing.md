# 0026 More room in the article list rows

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) found the middle pane too tight and chose option B from three renders (96, 108 and 116 points) on 2026-10-11.

## Decision

The row height goes from 96 to **108 pt**. The space above and below the text is 14 pt (was 10 and about 12), the gap between the source line and the title is 6 pt (was 4), and between the title and the summary 4 pt (was 3). The text block is 56 pt high next to the 52 pt thumbnail. The numbers are in `NativeArticleList.Metrics`, which is the only place that sets the row height and the cell layout. Nothing else changes: the same lines, fonts and thumbnail.

## Why

At 96 pt the four lines were stacked with almost no gap, and rows ran into each other. 108 pt is a 12% increase: about one article fewer on a screen. 116 pt looked airy but shows fewer articles, which works against finding the few important ones among many (vision).

## Not verified

How it feels in the real window with real feeds and long use; very large type settings.
