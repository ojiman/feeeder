# 0053 Plain `http://` feeds are not supported

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-14
- Decider: the owner (PdM), in the answer to issue #134: option (a), and the wording of the message.
- Refines: [0040](0040-try-https-first.md) (point 2: what the person sees when the https form fails) and [0041](0041-import-opml.md).

## Decision

1. **The app does not fetch plain `http://`.** A feed that exists only on `http://` cannot be subscribed. The system's transport security (App Transport Security) stays as it is; no exception is added for feeds.
2. **The sentence for that case.** When an address was typed with `http://`, the app checked the `https://` form (0040), and the connection failed, the sheet says 「HTTPSでは読み込めませんでした。HTTPには対応していません。」 (the owner's wording: "This feed couldn't be loaded over HTTPS. HTTP isn't supported."). Causes that do not depend on the scheme keep their own sentences: no network, no answer, server not found, an HTTP status such as 404, and a page that is not a feed.
3. **An address with a port** is not changed to https (0040), so https was never tried. It keeps the sentence 「http:// には接続できません。https:// のURLを入れてください。」.

## Why

In the owner's own export, 9 of 42 feeds were on `http://`; 8 answered on `https://` and one did not exist. A few lost feeds cost less than a wider security setting (an exception for all feeds, or a second network path with its own warning). This also keeps the promise that the app does not send text over an unprotected connection by default.

## Not in this change

Allowing `http://` for feeds, with an exception or a warning. If the owner wants it later, it is a new decision.
