# 0038 Find the feed from a site address

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) agreed to the plan of three changes (the live check, the folder at registration, and this one). The details below are the Product Owner's.
- Refines: [0036](0036-check-the-feed-as-you-type.md) (a Web page was reported as "not a feed").

## Decision

1. **A site address can be added.** When the address is a Web page, the app looks for the feed the page announces with `<link rel="alternate" type="application/rss+xml|atom+xml|rdf+xml" href="…">` and checks that feed. The line under the field shows 「✓ feed name」 and a small second line, 「ページのフィード：<feed address>」, so the person sees what will be subscribed. The subscription is the feed's address, not the page's.
2. **One step, the first feed.** The first announced feed whose address is usable is taken. The announced address is read as a feed and is never searched again. A choice screen for several feeds is not built; the first one is usually the main feed (comment feeds come later on the page). Other `alternate` links (stylesheets, languages, oEmbed, JSON Feed) are ignored.
3. **The announced address is checked like any address:** `http(s)` only, no user name or password, relative addresses resolved against the page, and a secure page never leads to plain `http://`. The second request is the same plain GET with no user data. A link that leads to a missing feed shows the real reason (for example 404); a link that leads to another page, or a page with no announcement, shows 「このページにはフィードが見つかりませんでした。フィードのURLを入れてください。」.
4. **Only a new subscription does this.** Refreshing a saved subscription still treats a page as a page: a subscription never moves to another address by itself.
5. **An address that is already subscribed** is detected for the feed that was found (the line says 「すでに購読しています」, as in 0036).
6. The HTML is read with SwiftSoup, which the app already uses (no new dependency). The page counts toward the 2 MB limit of one response.

## Not in this change

A choice among several feeds. Finding a feed from sites that do not announce one (guessing `/feed`, `/rss`). JSON Feed.

## Not verified

Japanese pages in other encodings (the page is read as UTF-8 for the links only; the links are ASCII in practice); a page larger than 2 MB shows the size message instead of a feed. Run in a synthetic copy of the app (own bundle identifier and data folder): a public site address showed the feed's name and its address; a public page with no announcement showed the sentence above. Unit tests cover the link rules, the client (page to feed, feed as it is, no feed, a link to another page, a link to a missing feed) and that refresh is unchanged.
