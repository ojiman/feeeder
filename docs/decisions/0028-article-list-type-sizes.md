# 0028 Article list: the headline leads

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM): a reader decides interest from the favicon and the headline, so the source name and the summary are only supporting information and can be smaller.

## Decision

In a row of the article list the headline stays at 14 pt (semibold when unread, medium when read). The summary goes from 12 to **11 pt** and the source name from 11 to **10 pt** (the time is 10 pt as before). Colours, the row height (decision 0026) and the lines of a row do not change.

## Not verified

How 10 and 11 pt Japanese text reads on the real display over a long use, and with a larger system text size. If it is too small, the numbers are in one place in `NativeArticleList.Cell`.
