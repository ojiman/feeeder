# Feeeder

A fast, keyboard-driven RSS reader for macOS that helps you go from skimming to understanding.

Skim hundreds of articles in a smooth three-column reader. Send an AI summary of an article you care about to a note, and write the rest in your own words. Everything stays on your Mac.

> **Direction (decision 0019).** V1 is being simplified: themes, goals and the AI suggestions give way to plain Markdown notes, one button that sends an article's summary to a note, and Claude as a function of the note. The list under "What it does today" describes the current build; it changes as the stages in [decision 0019](docs/decisions/0019-v1-simplification-notes.md) are merged. The target is in [the specification](docs/specification.md).

> **Status: beta, pre-release.** Requires macOS 27.0 or later. The app's interface is currently in Japanese only; a language setting is planned before the public release. There are no prebuilt releases yet: you build the app from source. Final product acceptance is still in progress, see [Status](#status).

## Why

Many more articles are written now than anyone can read. The hard part is finding the few that matter and turning them into something of your own. Most readers stop at "read" and "starred": stars pile up and are never looked at again. Switching to a notes app or an AI chat breaks the flow of reading.

Unagi Reader is built for engineers in 2026 who read a lot of feeds every day. Its value is one loop in one app, with no waiting: **read, take notes, ask AI, understand.**

- **Read fast.** Three columns, Vim-style keys (`j` / `k`), and a UI built so that scrolling and typing do not wait on a reload, a network request, or AI. Comfort is part of the value.
- **Note it while you read.** One button sends an article's summary (made on your Mac, or just the title, link and feed summary) to a note. The articles you sent sit beside the note, so you write in your own words while you see them.
- **Ask AI when you choose.** Show the note's full text, then hand it to Claude for a review. Nothing leaves your Mac before you decide.
- **Keep it yours.** No account, no backend, no sync. Your subscriptions, articles and notes live in a local database.

## What it does today

- RSS/Atom subscriptions with one level of folders, automatic refresh (on launch, when the app returns, and every 30 minutes while it runs), and offline reading of stored articles.
- Reading: feed-provided body when available, best-effort extraction otherwise, and the feed summary plus a link to the original when neither is available. It labels which one you are looking at and does not try to bypass access restrictions.
- Keyboard: `j` / `k` move, `m` read/unread, `s` star, `t` add to a theme, `b` open in your browser, `v` open the original page inside the app, `Esc` back to reading.
- Themes: group articles, write a learning goal and one note per theme. Unsorted stars are collected in one place. Questions and answers from earlier versions move into the note the first time this version opens your library.
- On-device AI suggestions (optional, can be turned off in Settings): nearby themes for an article, suggested groupings of unsorted stars, and theme-name ideas, and, in a theme's note panel, a short summary of the open article when you ask for one, and two note actions (rewrite more clearly, the essence in three lines) that you adopt or ignore and can undo. Suggestions run on your Mac only. **AI never writes your note** (an AI summary, rewrite or essence enters it only when you adopt it, and ⌘Z takes it back), and nothing is applied until you choose it.
- Images: favicons and article thumbnails, best effort, with a bounded cache.
- Retention: article bodies are kept for 30 days by default (7 / 30 / 90 / 365 in Settings). What you recorded in themes (title, link, saved summary, your writing) is never deleted automatically.

Claude Desktop hand-off: from a theme, a toolbar button 「Claudeで開く…」 (Open in Claude…), or the note panel's 「Claudeでレビューを頼む」 (Ask Claude to review), opens a review screen. You choose the sources, the output language, and whether to include your goal and your note (the note is off by default from the toolbar; including it turns the request into a review of the note against your goal). You see the exact text first, confirm the attachment in Claude, and send it yourself. Nothing is sent automatically.

## Try it

You need a Mac on macOS 27.0 or later and the Swift toolchain from Xcode.

```sh
git clone https://github.com/ojiman/feeeder.git
cd feeeder
bash scripts/build-app.sh release
open -n '.build/Feeeder.app' --args --data-directory /private/tmp/feeeder-demo --seed-demo
```

The last command opens a **separate instance with synthetic subscriptions and its own data directory**, so you can look around without touching a real library. To use it for real, open `.build/Feeeder.app` normally.

The app is ad hoc signed for local use. It is not signed with a Developer ID and not notarized, so a copy that arrives with a quarantine attribute (for example, one saved by a browser) is blocked by macOS until you choose "Open Anyway" in System Settings > Privacy & Security. Building from source, or fetching a CI build with `bash scripts/fetch-ci-app.sh <PR number>` (needs macOS and a signed-in `gh`), avoids the attribute.

## FAQ

**Does it send my data anywhere?** It fetches the feeds you subscribe to, article images and favicons, and original pages when you open them in the in-app view (which does not keep you signed in). The AI suggestions run on-device and send nothing out. There is no backend and no account.

**Where is my data?** In `~/Library/Application Support/Feeeder/`, with the database in `Reader.store` (plus its `-shm` / `-wal` files).

**Will an update break my library?** During the beta, compatibility between versions is **not guaranteed**: an update can leave the library unreadable, and the app shows an error rather than deleting or recreating it. Back up the `Feeeder` folder before updating (see the [user guide](docs/user-guide.md#back-up-the-library-by-hand)). From 1.0 onward, the policy is to preserve saved data across updates.

**Does it work without AI?** Yes. All features, including creating and editing themes and notes, work with AI turned off. If the on-device language assets are not installed, the app does not download them; suggestions simply do not appear.

## Status

This is a beta under active development.

- Final product acceptance on a real Mac is not complete.
- CI builds and tests on macOS 26.6, which covers only the build floor. The macOS 27.0 support floor is exercised only on the maintainer's local machine. Several behaviors are unverified: input methods (IME), VoiceOver, Reduce Motion, and long-running use. See the [verification records](docs/verification/) for what has and has not been checked.
- The app's labels and messages are Japanese only today. A language setting is planned before the public release, but it is not implemented yet.

## Documentation

The user guide is available in English and Japanese. The other documents are currently in Japanese only.

| | |
|---|---|
| [User guide](docs/user-guide.md) ([Japanese](docs/user-guide.ja.md)) | Operations, data retention and backup, Claude Desktop hand-off, verification steps |
| [Specification](docs/specification.md) | Product requirements (Japanese) |
| [Architecture](docs/architecture.md) | Technical choices (Japanese) |
| [Decision records](docs/decisions/README.md) | Why things are the way they are (Japanese) |
| [AGENTS.md](AGENTS.md) | Development workflow, commands, and boundaries |

## Development

```sh
swift test --scratch-path /private/tmp/feeeder-dogfooding-build
git diff --check
```

Tests use only synthetic RSS/HTML and temporary databases. The project is developed with AI coding agents under a single supervised writer; [AGENTS.md](AGENTS.md) describes the workflow and the checks each change must pass.

## License

Feeeder is licensed under the [Apache License 2.0](LICENSE). Third-party notices are in [ThirdPartyNotices.md](ThirdPartyNotices.md). Feed content, original pages, site logos, external libraries, and services remain subject to their owners' rights and terms. No personal data, credentials, or keys are included in the repository.
