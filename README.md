# Unagi Reader

A fast, keyboard-driven RSS reader for macOS that turns the few articles that matter into your own understanding.

> **Status: beta, pre-release.** Requires macOS 27.0 or later. The app's interface is in Japanese only today. There are no prebuilt releases: you build the app from source.

## Why

More articles are written than anyone can read. The hard part is finding the few that matter and turning them into something of your own. Most readers stop at "read" and "starred", and a separate notes app or AI chat breaks the flow of reading.

Unagi Reader is for engineers in 2026 who read many feeds every day. Its value is **one loop in one app, with no waiting: read, take notes, ask AI, understand.**

- **Read fast.** Three columns and Vim-style keys. Scrolling and typing never wait on a reload, the network or AI.
- **Note it while you read.** One plain Markdown note, written in your own words next to the article.
- **Ask AI when you choose.** Copy the note as it is and paste it into any AI you like, or use the system's Writing Tools in the note editor. Nothing leaves your Mac unless you paste it.
- **Keep it yours.** No account, no backend, no sync. Everything lives in a local database.

The full statement, with the promises and the questions to ask when in doubt, is in the [vision](docs/vision.md). The current build is moving to this shape in stages ([decision 0019](docs/decisions/0019-v1-simplification-notes.md)); the target is in the [specification](docs/specification.md).

## Try it

You need a Mac on macOS 27.0 or later and the Swift toolchain from Xcode.

```sh
git clone https://github.com/ojiman/unagi-reader.git
cd unagi-reader
bash scripts/build-app.sh release
open -n '.build/UnagiReader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo
```

The last command opens a separate instance with synthetic subscriptions and its own data directory, so you can look around without touching a real library. To use the app for real, open `.build/UnagiReader.app` normally.

The app is ad hoc signed, not notarized. macOS blocks a copy that carries a quarantine attribute (for example, one saved by a browser) until you choose "Open Anyway" in System Settings > Privacy & Security. Building from source avoids this.

## FAQ

**Does it send my data anywhere?** It fetches the feeds you subscribe to, article images and favicons, and original pages when you open them in the app. The app has no AI of its own. Text leaves your Mac only when you copy it and paste it somewhere yourself. There is no backend and no account.

**Where is my data?** In `~/Library/Application Support/UnagiReader/`.

**Will an update break my library?** During the beta, compatibility between versions is not guaranteed. The app shows an error instead of deleting or recreating the library. Back up the `UnagiReader` folder before you update (see the [user guide](docs/user-guide.md#back-up-the-library-by-hand)). From 1.0, saved data is preserved across updates.

**Does it work without AI?** Yes. Everything works with AI turned off.

## Status

- Final product acceptance on a real Mac is not complete.
- CI covers only the build floor (macOS 26.6). The support floor (macOS 27.0) is exercised only on the maintainer's machine. Input methods, VoiceOver, Reduce Motion and long-running use are not yet verified. See the [verification records](docs/verification/).
- A language setting for the app's interface is planned before the public release.

## Documentation

| | |
|---|---|
| [Vision](docs/vision.md) | What the product is for, for whom, the promises, and the questions to ask when in doubt |
| [User guide](docs/user-guide.md) ([Japanese](docs/user-guide.ja.md)) | Operations, backup, using the note with another AI |
| [Specification](docs/specification.md) | Product requirements (Japanese) |
| [Architecture](docs/architecture.md) | Technical choices (Japanese) |
| [Decision records](docs/decisions/README.md) | Why things are the way they are |
| [AGENTS.md](AGENTS.md) | Development workflow, commands and boundaries |

## Development

```sh
swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build
git diff --check
```

Tests use only synthetic RSS/HTML and temporary databases. The project is developed with AI coding agents under a single supervised writer; [AGENTS.md](AGENTS.md) describes the workflow and the checks.

## License

[Apache License 2.0](LICENSE). Third-party notices are in [ThirdPartyNotices.md](ThirdPartyNotices.md). Feed content, original pages, site logos and external services remain subject to their owners' rights and terms. The repository contains no personal data, credentials or keys.
