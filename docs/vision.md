# Vision

This page is the owner's statement of what Unagi Reader is for. Read it when you doubt a feature, a design or a priority. It is short on purpose. The details are in the [specification](specification.md); the reasons for each choice are in the [decision records](decisions/README.md).

Unagi Reader is the product name. The repository, the code and the app bundle still use the name Feeeder until the rename (see the roadmap, stage D).

## In one line

Find the few articles that matter in a flood of articles, and turn them into your own value.

## Who it is for

Engineers in 2026 who read many feeds every day. They know Reeder Classic, and a smooth reader is the baseline for them.

## The problem

More articles are written than anyone can read. Skimming is easy; understanding is not. Most readers stop at "read" and "starred", and the stars pile up. A separate notes app or an AI chat breaks the flow of reading, and often sends your reading history to someone else's server.

## The value: one loop, in one app, with no waiting

**Read → note → ask AI → understand.**

- **Read.** A smooth three-column reader with keys. Scrolling and typing never wait on a reload, the network or AI.
- **Note.** One button sends an article's summary to a note. The articles you sent sit beside the note, so you write in your own words while you see them.
- **Ask AI.** When you choose, show the note's full text and hand it to Claude for a review.
- **Understand.** What stays is your own note, in plain Markdown, on your Mac.

A smooth feel is part of the value. It is not polish added at the end.

## Promises

1. **Your data stays on your Mac.** No account, no backend, no sync. Text leaves the Mac only when you read the exact text and press the button.
2. **AI is a draft; you decide.** AI works on the device. Text that AI wrote is marked in the note and can be undone. Everything works with AI turned off.
3. **Honest about the input.** The app says whether it shows the full text, an extract or only the feed summary. It does not bypass paywalls, logins or robots rules.
4. **Light over many.** We add a feature only if it makes the loop smoother. We keep the number of things a person must manage (folders, tags, goals, settings) as small as we can.

## Not in V1, on purpose

Goals and learning plans. Tags and automatic sorting. AI that edits your note by itself. Sync, accounts, a server. Many other connections than Claude Desktop.

## Questions to ask when you waver

1. Does it make the loop (read, note, ask AI, understand) smoother, or only bigger?
2. Does it add something the person must manage or decide? If yes, the default is no.
3. Can it make the reader wait?
4. Can text leave the Mac without the person reading it and pressing a button?
5. Does it still work with AI off?

## About this page

The owner (the PdM) wrote the value and the target user on 2026-10-11, after dogfooding. It changes only by the owner's instruction, with a decision record. See [decision 0019](decisions/0019-v1-simplification-notes.md).
