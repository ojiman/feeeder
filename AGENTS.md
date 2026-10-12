# Unagi Reader development

Instructions for coding agents (Codex, Claude Code) and for the person reviewing them. Keep this file short: it says where things are, how to verify, and where the boundaries are. Details live in the linked documents.

## Where things are

| Path | Role |
|---|---|
| docs/vision.md | The owner's statement of the value, the user, the promises and the questions to ask when in doubt. Above the specification. |
| README.md | English public overview: concept, status, how to try it. Derived from the spec; it does not define product behavior. |
| docs/user-guide.md, docs/user-guide.ja.md | Operations, data retention and backup, Claude hand-off, verification steps. English and Japanese; keep them in step. |
| docs/specification.md | V1 product source of truth (PRD). The user's PdM approval is still required before V1 is accepted. |
| docs/architecture.md | Technical choices and the four-axis agent harness (§4). |
| docs/decisions/ | Dated decision records: who decided what, and why. Start here to learn why something is the way it is. |
| docs/review-checklist.md | Lens for independent review of a fixed commit. |
| docs/verification/ | Evidence logs per change. Logs, not specs. |
| docs/roadmap.md | The order of work (stages S1 to S5, then the real-device check, the rename, the beta). A stage's plan lives in docs/superpowers/plans/ only until the stage is merged. |
| Sources/ReaderCore | Models, store, parsing, retention, handoff. No UI. |
| Sources/UnagiReader | SwiftUI/AppKit app. |
| Tests/ReaderCoreTests, Tests/ReaderUITests | Tests. Synthetic data only. |
| scripts/ | `build-app.sh`, `prepare-v1-store-fixture.sh`, `fetch-ci-app.sh` (tested by `test-fetch-ci-app.sh`), `ci-gate.sh` (the `check` job; tested by `test-ci-gate.sh`). |

## Commands

```sh
swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build          # local tests
swift test --scratch-path /private/tmp/unagi-reader-ci-build --force-resolved-versions --disable-keychain --disable-netrc   # as CI runs them
bash scripts/build-app.sh release                                        # ad hoc signed .build/UnagiReader.app (debug is the default)
bash scripts/fetch-ci-app.sh <PR number>                                  # a PR's CI-built app without a browser, so no quarantine attribute (needs macOS and gh)
bash scripts/test-fetch-ci-app.sh                                         # control-flow tests for that script with stubbed tools (no macOS, network or gh needed)
open -n '.build/UnagiReader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo   # synthetic run in a NEW instance, never the user's library
git diff --check
```

Use `open -n` for the synthetic run. Without it, `open` can reuse an Unagi Reader that is already running and drop `--args`; the data directory is read only at launch, so you would be operating on the user's library. Before touching anything, confirm the instance is the synthetic one: a `UnagiReader` process whose arguments include the temporary `--data-directory` (for example `pgrep -fl UnagiReader`), and a window that shows the synthetic subscriptions. A separate-Bundle-ID copy is also fine if it can be told apart from the user's app by the same checks. This procedure has not been re-run on macOS since it was written down.

For a short local feedback loop, keep the same scratch path and run the suites affected by the change, for example `swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build --filter 'NoteTitleTests|NoteTests'`. Run the full suite before publishing the change; CI still runs it for every code change.

`BenchmarkFixtureTests` uses 1,000 articles and 100 feeds in routine regression. To check or generate the full 10,000-article fixture, choose a new, empty output directory ([decision 0044](docs/decisions/0044-smaller-regression-fixture.md)). Run this larger check for library/index changes and before release:

```sh
UNAGI_READER_BENCHMARK_DIRECTORY="$(mktemp -d /private/tmp/unagi-reader-benchmark.XXXXXX)" swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build --filter BenchmarkFixtureTests
```

Opt-in store compatibility check (skipped unless `UNAGI_READER_V1_FIXTURE_DIR` is set; not part of CI during beta; `UNAGI_READER_PRE0019_FIXTURE_DIR` is the same for a fixture made from commit `52429b4`, the build before decision 0019):

```sh
bash scripts/prepare-v1-store-fixture.sh /private/tmp/unagi-reader-v1-fixture-new
UNAGI_READER_V1_FIXTURE_DIR=/private/tmp/unagi-reader-v1-fixture-new swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build
```

CI runs two macOS jobs on macOS 26 / Xcode 26.6 / Swift 6.3.3. `regression` (the tests) runs for every change that touches code. `release` (the optimized build, ad hoc signature and packaged app) is the slow one, so a pull request runs it only when it changes `Package.swift`, `Package.resolved`, `ThirdPartyNotices.md`, `scripts/build-app.sh` or `.github/workflows/*`; every push to `main` and every manual run builds it. A third job, `check`, always runs on a pull request and is the one status the `main` ruleset requires: for a PR that touches only `docs/**` or Markdown it skips both macOS jobs and passes; otherwise it passes only when every job that was due passed (`scripts/ci-gate.sh`, tested by `scripts/test-ci-gate.sh`). A PR run therefore usually has no packaged app: `fetch-ci-app.sh` needs the `release` artifact, so run the workflow manually on the branch or build locally with `scripts/build-app.sh release`. The local toolchain is macOS 27 / Swift 6.4 and is the only place the support floor (macOS 27.0, decision 0007) is exercised; CI verifies only the build floor (macOS 26.6) because no macOS 27 runner exists yet. Do not use APIs that need the macOS 27 SDK until CI can build them.

## Starting or resuming work

A new thread starts without the previous one's memory. Rebuild the state from Git, PRs and records, not from a summary:

1. Check the current branch, HEAD, uncommitted changes, and related open PRs.
2. Read the relevant part of the spec and the latest verification record.
3. Say what is done, what is not, and the next step before changing anything.
4. Reuse an earlier PASS only where its commit and environment match the current ones.

## Boundaries

- Work as one supervised implementation writer. Do not start unattended workers or resume the Keychain probe. A reviewer may inspect a fixed commit when the task calls for it; do not claim read-only isolation from a prompt alone.
- Use synthetic RSS/HTML and temporary databases for tests. Do not read the user's library, credentials, Keychain, browser profile, or unrelated projects. /private/tmp is disposable scratch, not a security boundary.
- Local edits, tests, builds, and commits are allowed. Review concrete URLs, dependencies, migrations, and external writes against the user's current instruction. Authorization already given in the task does not need to be requested again.
- Do not push directly to main. Use a branch and PR when GitHub publication is requested. Do not sign, submit, or publish an app without the user's instruction.
- `docs/vision.md` is the owner's words. Do not change it without the owner's instruction. When you propose or judge a feature, check it against its questions (does it make the loop smoother, does it add something to manage, can it make the reader wait, can text leave the Mac without a button, does it work with AI off).
- Adding or changing a dependency (SwiftSoup is pinned to an exact version) needs the user's instruction.

## Definition of done

1. One theme per PR. Fix user-reported bugs before polish. State what the PR does not include.
2. For a bug, reproduce it with a failing test first, then fix it, and record both results.
3. Run the checks relevant to the change (tests; the release build when UI or packaging changes; `git diff --check`). Report what passed, what was not run, and the environment (OS, Xcode/Swift) of each result.
4. For UI changes, also exercise a synthetic app instance with its own data directory. Say which behaviors stay unverified on macOS.
5. Never turn unverified behavior into PASS without evidence (macOS 27.0 support floor, IME, VoiceOver, Reduce Motion, long-running use). List what this change leaves unverified in the PR, and link the existing verification record or issue. Open a new issue (template: "Unverified check") only for items that need ongoing tracking, and only within what the user has allowed, since it is an external write.
6. A change in product behavior or policy updates the spec/architecture in the same PR and adds a decision record. Do not edit an "approved" header to imply an approval that did not happen.
7. Never report success for a save or change the user asked for when it did not happen (for example `try?` discarding a save or reload failure, or user-entered text dropped because its target is gone). Legitimate no-ops are fine and should be kept distinct: cancellation, a stale async response after the selection moved, and an optional action with nothing to act on.
8. Risky changes (store/model, concurrency, external writes) get an independent review of a fixed commit using docs/review-checklist.md. A review that finds nothing lists what it checked and what it did not.

## Proportion

Match the work to the risk. Items 1, 2, 5, 6 and 7 above always apply. Items 3, 4 and 8 apply in full to changes in the store or model, concurrency, external writes, and data retention or deletion. For other changes the short form is enough:

- UI polish, labels, and small behavior changes: tests for the changed logic, `git diff --check`, and a list of what stays unverified in the PR text. Run a synthetic instance only when a test cannot show the behavior.
- Docs-only changes: `git diff --check` and working links.

Keep evidence small, because every record has to be read and kept in step later:

- Write a verification record (`docs/verification/`) only for a risky change, or when a PASS claim needs a lasting reference. At most one record per PR. Extend an existing record instead of adding a new one on the same topic.
- Put the result in the first three lines. Use a table for the rest. If a record passes about 100 lines, ask what the reader needs and cut the rest.
- Do not commit raw logs, raw event dumps, probe patches, or generated files unless a reader needs them to reproduce a PASS that the 1.0 acceptance relies on. The PR text and Git history can hold the rest.
- A review of a low-risk change is one pass. Do not add review rounds only to produce more evidence.

The first prune pass was done in 2026-10 (old plans and records of removed features are in Git history). A second pass comes before 1.0 (see docs/roadmap.md). Do not prune existing files without the user's instruction.

## Language

The project is meant to be used and read worldwide, so new project text is written in English. Many readers are not native English speakers, so write plain English: short sentences, common words, no idioms, and the same term for the same thing.

- Write in English: commit messages, PR titles and bodies, new decision records, new documentation, and new code comments.
- Leave existing text alone. Old commits, PRs, Japanese documents, and decision records stay as they are. Do not rewrite Git history or translate old records unless the user asks. A document may be translated into a new file (for example `docs/user-guide.md` from `docs/user-guide.ja.md`); when the content changes, update both files in the same PR or say which one is behind.
- The app's labels are currently Japanese only. Quote a label as it appears and add an English gloss when it helps the reader. Changing the app's language is a product decision and needs the user's instruction.
- Issues and discussion may be in Japanese or English.

## Data policy

Decided by the user on 2026-10-05 and 2026-10-07 (see docs/decisions/).

- V1 starts with a fresh database; prototype data migration and compatibility models are out of scope.
- Data compatibility across beta versions is not guaranteed. Preserve ordinary saves and reopening within the same version.
- From 1.0 onward, preserve saved data across model changes. Before shipping 1.0, freeze its schema as `VersionedSchema` and add mandatory CI preservation checks using its release tag as the baseline.
- Do not automatically delete an unreadable store.

## Known gotchas

- macOS 26: after a failed save, registered models can keep unsaved values. `ReaderStore.rollback()` swaps in a fresh `ModelContext`, and `needsReload` blocks mutations until a reload succeeds. Resolve models by ID after a failure, and call `reloadIfNeeded()` first in any new mutating method.
- The CI compiler (Swift 6.3.3) crashed on an actor-isolated method reference passed as a `Binding` setter; use an explicit closure (PR #14).
- The CI compiler (Swift 6.3.3) gave up ("unable to type-check this expression in reasonable time") when `ReaderView`'s modifier chain grew by a few modifiers (PR #96), while the local Swift 6.4 compiled it. Add new window-level modifiers from outside the chain (`ViewModifier` applied in the wrapper `body`, as `OPMLImportPresentation`), not as more links in it.
- Three problems appeared only in CI, not on the local toolchain: SwiftData rollback on macOS 26 (PR #10), the app signature of the packaged app (PR #12), and the compiler crash above (PR #14). Treat local success as necessary, not sufficient.
