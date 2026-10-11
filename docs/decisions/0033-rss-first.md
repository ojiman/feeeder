# 0033 RSS first: the feed's own text is shown

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-12
- Decider: the owner (PdM) saw a broken article in the reader (the menus and counters of a web page) while the same article was clean in another reader, and proposed to show the RSS as it is and to go to the original with the v or b key. The owner approved the first proposal of the Product Owner (the agent), who gave the points marked "PO".

## What was found

The feed (RSS 1.0, from Hatena Bookmark) was parsed correctly: 30 entries, none skipped, the title, the summary, the quoted `content:encoded` and the image all as the feed has them. The broken view came from the page extraction: on opening an article the app fetched the original page and replaced the feed's text with the paragraphs of the page's first `<article>`. On the page of one article that element holds breadcrumbs, a date, tags and counters ("トップ", "2026年", "27", "94", "ポスト", "いいね！0"), which became 102 paragraphs.

## Decision

1. **Opening an article shows the feed's text and never fetches the page.** Nothing waits, and no request goes to a third-party site just because an article was opened. *(Owner.)*
2. **Details are read in the original page** with `v` (inside the app) or `b` (browser). Both exist already.
3. **The full text from the page is a button, not a default.** 「全文を取得」 (「本文を再取得」 once extracted) fetches and extracts the page, and shows and saves the result. *(PO.)*
4. **A page of mostly page chrome is not taken as the article** (`ExtractionQuality`: more than half of the paragraphs are tiny, that is shorter than 6 characters or without a letter). This catches pages made of fragments; it does not catch every noisy page (a page of embedded posts can pass), which is why the extraction is no longer automatic.
5. **For the AI summary, a short feed text is replaced by the page text at send time.** When the person sends a summary to a note and the feed text is shorter than 1,000 characters, the page is fetched (robots rules kept, 10 seconds at most) and its text is the input of the on-device model. It is neither shown nor saved; a page that cannot be used leaves the feed text as the input. It happens only for the press of the send button, with the AI on. *(PO.)*
6. **Bodies that an earlier version extracted by itself are removed** once per library at the first start (`discardExtractedBodies`): the article keeps its summary and the next feed refresh brings back the feed's body. This deletes data that can be fetched again; it is not the person's own writing, and notes keep their own records. *(PO.)*

## Not verified

The removal on a real library (it runs once at the first start with this version); the summary quality when the page text is used (needs the on-device model); other noisy pages; the button 「全文を取得」 on a real site.
