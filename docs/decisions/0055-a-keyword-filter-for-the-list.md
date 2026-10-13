# 0055 A keyword filter for the article list

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-14
- Decider: the owner (PdM), in issue #129 (comment of 2026-10-14). Where the icon sits and "feed text" = the feed summary are the agent's reading, listed below for the owner to confirm.

## Decision

1. **The person can narrow the list of the current scope with a keyword.** The filter stays when the scope changes and is not kept across launches. `/` opens it. Nothing is saved: no saved filters, no tags (vision, question 2).
2. **Only the title and the feed summary are searched**, not bodies, not the text the app fetched, not the note. It runs on the Mac, in memory, and never waits on the network.

What the person sees is in the specification, 3.1.4.

## Read by the agent (for the owner to confirm)

- **The icon is on the title line, not in the toolbar band.** A SwiftUI search field or toolbar item goes to the window's trailing end, over the article, whatever column it is attached to (measured in a hosted window). A control drawn in the band may not get clicks there (the titlebar takes them); that could not be checked without a real Mac. So the magnifier sits at the right of the list title, and the field takes the title's place.
- **"The feed's text" is the feed summary**, the text the list row shows. The feed's body is replaced by 「全文を取得」 and can expire, and reading it for thousands of articles would make typing wait.
