# Unagi Reader development

Instructions for coding agents (Codex, Claude Code) and for the person reviewing them. Keep this file short: it says where things are, how to verify, and where the boundaries are. Details live in the linked documents.

## Where things are

| Path | Role |
|---|---|
| docs/vision.md | The owner's statement of the value, the user, the promises and the questions to ask when in doubt. Above the specification. |
| README.md | English public overview: concept, status, how to try it. Derived from the spec; it does not define product behavior. |
| docs/user-guide.md | Operations, data retention and backup, using the note with another AI, verification steps. English only; app labels are quoted in Japanese with an English gloss. |
| docs/specification.md | V1 product source of truth (PRD). The user's PdM approval is still required before V1 is accepted. |
| docs/spec-style.md | How to write the specification so that a person or an AI reads it right: layers, rules as lists and tables, status marks, names. |
| docs/architecture.md | Technical choices and the four-axis agent harness (§4). |
| docs/decisions/ | Dated decision records: who decided what, and why. Start here to learn why something is the way it is. |
| docs/review-checklist.md | Lens for independent review of a fixed commit. |
| docs/verification/ | Evidence logs per change. Logs, not specs. |
| docs/roadmap.md | The order of work (stages S1 to S5, then the real-device check, the rename, the beta). A stage's plan lives in docs/superpowers/plans/ only until the stage is merged. |
| Sources/ReaderCore | Models, store, parsing, retention, handoff. No UI. |
| Sources/UnagiReader | SwiftUI/AppKit app. |
| Tests/ReaderCoreTests, Tests/ReaderUITests | Tests. Synthetic data only. |
| scripts/ | `build-app.sh`, `prepare-v1-store-fixture.sh`, `fetch-ci-app.sh` (tested by `test-fetch-ci-app.sh`), `ci-gate.sh` (the `check` job; tested by `test-ci-gate.sh`), `check-test-log.sh` (fails CI when the test run did not finish; tested by `test-check-test-log.sh`). |

## Commands

```sh
swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build          # local tests
swift test --scratch-path /private/tmp/unagi-reader-ci-build --force-resolved-versions --disable-keychain --disable-netrc   # as CI runs them
bash scripts/build-app.sh release                                        # ad hoc signed .build/Unagi Reader.app (debug is the default)
bash scripts/fetch-ci-app.sh <PR number>                                  # a PR's CI-built app without a browser, so no quarantine attribute (needs macOS and gh)
bash scripts/test-fetch-ci-app.sh                                         # control-flow tests for that script with stubbed tools (no macOS, network or gh needed)
open -n '.build/Unagi Reader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo   # synthetic run in a NEW instance, never the user's library
git diff --check
python3 scripts/check_docs.py                                          # documents: links, decision numbers (add --online for the issues in the status marks and the roadmap; needs gh)
bash scripts/test-check-docs.sh                                          # tests of that check
```

Use `open -n` for the synthetic run. Without it, `open` can reuse an Unagi Reader that is already running and drop `--args`; the data directory is read only at launch, so you would be operating on the user's library. Before touching anything, confirm the instance is the synthetic one: a `UnagiReader` process whose arguments include the temporary `--data-directory` (for example `pgrep -fl UnagiReader`), and a window that shows the synthetic subscriptions. A separate-Bundle-ID copy is also fine if it can be told apart from the user's app by the same checks. This procedure has not been re-run on macOS since it was written down.

Opt-in store compatibility check (skipped unless `UNAGI_READER_V1_FIXTURE_DIR` is set; not part of CI during beta; `UNAGI_READER_PRE0019_FIXTURE_DIR` is the same for a fixture made from commit `52429b4`, the build before decision 0019):

```sh
bash scripts/prepare-v1-store-fixture.sh /private/tmp/unagi-reader-v1-fixture-new
UNAGI_READER_V1_FIXTURE_DIR=/private/tmp/unagi-reader-v1-fixture-new swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build
```

CI runs two macOS jobs on macOS 26 / Xcode 26.6 / Swift 6.3.3. `regression` (the tests) runs for every change that touches code. `release` (the optimized build, ad hoc signature and packaged app) is the slow one, so a pull request runs it only when it changes `Package.swift`, `Package.resolved`, `ThirdPartyNotices.md`, `scripts/build-app.sh`, `Assets/*` or `.github/workflows/*`; every push to `main` and every manual run builds it. A third job, `check`, always runs on a pull request (it also tests and runs the documents check: a broken link, a decision number used twice, or a status mark or roadmap line that names a closed issue fails it) and is the one status the `main` ruleset requires: for a PR that touches only `docs/**` or Markdown it skips both macOS jobs and passes; otherwise it passes only when every job that was due passed (`scripts/ci-gate.sh`, tested by `scripts/test-ci-gate.sh`). A PR run therefore usually has no packaged app: `fetch-ci-app.sh` needs the `release` artifact, so run the workflow manually on the branch or build locally with `scripts/build-app.sh release`. The local toolchain is macOS 27 / Swift 6.4 and is the only place the support floor (macOS 27.0, decision 0007) is exercised; CI verifies only the build floor (macOS 26.6) because no macOS 27 runner exists yet. Do not use APIs that need the macOS 27 SDK until CI can build them.

## Where work is tracked

- `docs/roadmap.md` is the **order** of the planned work toward the beta and 1.0: the stages, what is next and why. It stays short, points to issues and decisions, and marks a stage `Done (#PR)`. It does not hold the details of a task.
- **GitHub issues** hold the **units of work**: bugs, features, tech debt, decisions that wait for the owner, and checks that need a real Mac (template "Unverified check"). Write Problem, Acceptance Criteria, Constraints and Out of scope, not an implementation script, so that Claude Code, Codex or a person can take it. Close it from the pull request (`Fixes #n`). When the roadmap schedules something, it names the issue.
- **Decisions** go to `docs/decisions/`; a plan for work that takes several pull requests goes to `docs/superpowers/plans/` until it is merged.
- **An idea** (not decided, and nobody can say when it is done) is one line in the roadmap's candidates. A unit of work that someone can start today and know when it is done is an **issue**. A bug, tech debt or a decision that waits for the owner is an issue at once, scheduled or not.
- Label an issue `area:reader-view` when it touches `ReaderView.swift` (one at a time) or `area:no-screen` when it touches no screen (can run beside anything). The labels are the list; the roadmap does not keep one by hand.
- Work that is in neither the roadmap nor an issue is not tracked. Open an issue instead of only mentioning follow-up work in a chat or in a pull request.

### Working together

- **Take one issue at a time.** Say that you take it (assign yourself, or comment). One issue, one pull request, `Fixes #n`. Before you start, look at the open pull requests and issues that touch the same files.
- **An issue with an open question for the owner** waits: ask in the issue and do not start until it is answered.
- **A bug found on the way** that is not part of the issue becomes a new issue, not a bigger pull request.
- **Where pull requests collide:** `Sources/UnagiReader/ReaderView.swift` (its long modifier chain: one change at a time; see the known gotchas), the index in `docs/decisions/README.md` (one line per decision, added at the end), the long lines of `docs/specification.md`, and decision numbers. Take the next free decision number when you open the pull request; if `main` moved, renumber before the merge.
- The milestone **Beta** holds what must be done before the beta and is closed to new issues: only the owner adds to it. The beta is done when every issue in it is closed.

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
- `docs/vision.md` is the owner's words. Do not change it without the owner's instruction. When you propose or judge a feature, check it against its questions (does it make the loop smoother, does it add something to manage, can it make the reader wait, can text leave the Mac without the person copying it themselves).
- Adding or changing a dependency (SwiftSoup is pinned to an exact version) needs the user's instruction.

## Definition of done

1. One theme per PR. Fix user-reported bugs before polish. State what the PR does not include.
2. For a bug, reproduce it with a failing test first, then fix it, and record both results.
3. Run the checks relevant to the change (tests; the release build when UI or packaging changes; `git diff --check`). Report what passed, what was not run, and the environment (OS, Xcode/Swift) of each result.
4. For UI changes, also exercise a synthetic app instance with its own data directory. Say which behaviors stay unverified on macOS.
5. Never turn unverified behavior into PASS without evidence (macOS 27.0 support floor, IME, VoiceOver, Reduce Motion, long-running use). List what this change leaves unverified in the PR, and link the existing verification record or issue. Open a new issue (template: "Unverified check") only for items that need ongoing tracking, and only within what the user has allowed, since it is an external write.
6. A change in product behavior or policy updates the spec/architecture in the same PR. **A decision record is added only when a policy, or what a person can do or rely on, changes**: what the product does or never does, data, privacy, a new dependency, how the work is done. Layout, sizes, timings, wording and motion are not decisions: change the specification and say it in the PR text. When unsure, ask whether a future developer would ask "why is it so?" and the PR text could not answer. Do not edit an "approved" header to imply an approval that did not happen.
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

The project is meant to be used and read worldwide. Many readers are not native English speakers, so write plain English: short sentences, common words, no idioms, and the same term for the same thing.

- **The chat with the owner is in Japanese. Everything else is in English** (the owner, 2026-10-14): code comments, commit messages, pull request titles and bodies, issues, decision records, the specification, the user guide, the issue and pull request templates, and every other document.
- **The app's labels are Japanese.** Quote a label as it appears, in quotation marks, and add a short English gloss when it helps. Changing the app's language is a product decision and needs the owner's instruction.
- **Existing Japanese text is translated step by step, not at once.** The specification is translated one section per pull request (an issue tracks it); while a section is still Japanese, edit it in Japanese and do not mix two languages inside one section. Old decision records, old commits and old pull requests stay as they are (they are history). Do not rewrite Git history.

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
- A hosted UI test must not call `NSButton.performClick`. It runs a nested event loop that can stop the main run loop, and then the test process ends with exit code 0 and no summary line; `swift test` looks like a pass. Move through the app with the key handlers instead (`NativeArticleList.Table.keyHandler`). `scripts/check-test-log.sh` fails the `regression` job when the summary line is missing or a started test did not end. Run a changed UI suite several times, not once: the early end showed in about half of the runs.
- Hosted tests that fold the split view's columns must run one after the other: two windows that fold at the same time disturb each other (the sidebar of one stays open). Put such a suite under `SplitViewFoldTests` (`Tests/ReaderUITests/ReaderLayoutTests.swift`).
- Three problems appeared only in CI, not on the local toolchain: SwiftData rollback on macOS 26 (PR #10), the app signature of the packaged app (PR #12), and the compiler crash above (PR #14). Treat local success as necessary, not sufficient.
