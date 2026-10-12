# 0044 The original page slides out when it closes

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) saw that the original page (key `v`) slides in from the right, but pressing `j` to move to the next article made it vanish at once, and asked for the reverse motion there. The details below are the Product Owner's.

## Background

The page was meant to be a pair: it comes in with a slide from the right, and it goes out with the reverse. A check with the animation slowed to 15 seconds showed that only the way in moved. The way out (Esc, 「記事に戻る」, or selecting another article) removed the page at once, because the page is an AppKit web view and SwiftUI does not animate the removal of such a view.

## Decision

1. **The page slides out to the right when it closes**, in the same 0.22 seconds and with the same ease-out as the way in (the reverse of it). This applies to every way of closing: Esc, 「記事に戻る」, `j` / `k`, and a click on another article in the list. The page is removed when the slide is over.
2. **Selecting another article while the page is open** shows that article's reader text under the page, and the page slides away to reveal it. That is the motion the owner asked for.
3. **One motion at a time.** The reader text's own vertical motion (0.22 s, in the direction of the list) is not played while the page covers the text, so the page's slide is the only motion. Reading with `j` / `k` without the page is unchanged.
4. **The motion rules (Apple's Motion guidelines).** Brief (0.22 s); the way out mirrors the way in; the person never waits: the keys that arrive during the slide are ignored for the page (it is closing anyway), and a second request to close does nothing. **Reduce Motion:** the page closes at once, as before.
5. **The spatial model stays:** horizontal is depth (list, then page: in from the right, out to the right); vertical is sequence (next and previous article).

## Not in this change

The note panel's open and close. It is the system's inspector with no motion set by the app; whether it moves, and whether it should feel like the page, is to be seen on a real Mac first.

## Not verified

The motion at its real speed (0.22 s) was not watched. It was checked with the animation slowed to 15 seconds in a synthetic copy of the app (own bundle identifier and data folder, articles with an address) and a temporary build (not committed) that opened the page at launch: after clicking another article the page was seen sliding out to the right, and later the next article's text was shown under it. Not checked: Esc and 「記事に戻る」 (the same function), the `j` key itself (the test tools send no keys; a click on the list uses the same code), Reduce Motion, the feel on the owner's Mac. The state rule (the page closes only for another article) is covered by a unit test.
