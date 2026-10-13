# Vision

This page is the owner's statement of what Unagi Reader is for. Read it when you doubt a feature, a design or a priority. It is short on purpose. The details are in the [specification](specification.md); the reasons for each choice are in the [decision records](decisions/README.md).

## In one line

Find the few articles that matter in a flood of articles, and turn them into your own value.

## Who it is for

Engineers in 2026 who read many feeds every day. They know Reeder Classic, and a smooth reader is the baseline for them.

## The problem

More articles are written than anyone can read. Skimming is easy; understanding is not. Most readers stop at "read" and "starred", and the stars pile up. A separate notes app or an AI chat breaks the flow of reading, and often sends your reading history to someone else's server.

## The value: one loop, in one app, with no waiting

**Read → note → understand.**

- **Read.** A smooth three-column reader with keys. Scrolling and typing never wait on a reload, the network or AI.
- **Note.** Write your own note beside the article, in your own words. There is one note, one key away (`n`), and nothing to manage.
- **Understand.** What stays is your own note, in plain Markdown, on your Mac.

A smooth feel is part of the value. It is not polish added at the end.

## Promises

1. **Your data stays on your Mac.** No account, no backend, no sync.
2. **Honest about the input.** The app says whether it shows the full text, an extract or only the feed summary. It does not bypass paywalls, logins or robots rules.
3. **Light over many.** We add a feature only if it makes the loop smoother. We keep the number of things a person must manage (folders, tags, goals, settings) as small as we can.

## Not in V1, on purpose

Goals and learning plans. Tags and automatic sorting. An AI of the app's own. Sync, accounts, a server.

## Questions to ask when you waver

1. Does it make the loop (read, note, understand) smoother, or only bigger?
2. Does it add something the person must manage or decide? If yes, the default is no.
3. Can it make the reader wait?
4. Can text leave the Mac without the person copying it themselves?

## About this page

The owner (the PdM) wrote the value and the target user on 2026-10-11, after dogfooding. On 2026-10-13 the owner changed the note, the AI and the promises for one note and no AI of its own. It changes only by the owner's instruction, with a decision record. See [decision 0019](decisions/0019-v1-simplification-notes.md), [0049](decisions/0049-one-note-and-no-ai-of-its-own.md) and [0050](decisions/0050-the-note-screen-closes-like-the-original-page.md).
