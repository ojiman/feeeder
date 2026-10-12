# 0040 An `http://` address is checked as `https://`

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) asked to do this next, after the OPML import changed `http://` feeds to `https://`. The details below are the Product Owner's.
- Refines: [0036](0036-check-the-feed-as-you-type.md) (the sentence for `http://`) and [0038](0038-find-the-feed-from-a-site-address.md) (the caption under the feed name).

## Decision

1. **A plain `http://` address is never sent.** The system's transport security does not let the app fetch plain `http://`, so the add sheet checks the `https://` form of the address instead. If it reads as a feed, the subscription is the `https://` address. The same rule as in the OPML import ([0039](0039-import-opml.md)): an address with its own port is left as typed (the port was meant for http), and the system's refusal is then explained as before (「http:// には接続できません。https:// のURLを入れてください。」).
2. **If the https form fails, the person sees the real reason** (for example 404 or "server not found"); nothing is added with the `http://` address.
3. **The caption under the feed name is one line for both cases:** 「購読するURL：<address>」, shown only when the address that will be subscribed is not the one typed (the https form of an http address, or the feed a page announced, as in 0038). It replaces the wording 「ページのフィード：…」 of 0038. The address field is not rewritten while the person types.

## Not in this change

Making the OPML import use the same helper (`ArticleURL.secured`): it has its own copy until the OPML change is merged, then the two are joined. Trying `http://` when `https://` fails (the system would block it anyway).

## Not verified

Sites whose https certificate is wrong (the secure-connection sentence shows). Run in a synthetic copy of the app (own bundle identifier and data folder): `http://hnrss.org/frontpage` showed the feed name and 「購読するURL：https://hnrss.org/frontpage」, and unit tests cover the address rules, that plain http is never requested, and when the caption appears.
