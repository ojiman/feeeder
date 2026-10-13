# Unagi Reader development

Instructions for coding agents (Claude Code, Codex) and the person who reviews them: where things are, how to verify, where the boundaries are. Keep it short; details live in the linked documents.

## Where things are

| Path | Role |
|---|---|
| docs/vision.md | Why the product exists, for whom, the promises, the questions to ask when in doubt. Above everything else. |
| docs/specification.md | What V1 is and is not, as the person sees it. The source of truth for behavior. |
| docs/spec-style.md | How to write the specification. |
| docs/architecture.md | How it is built, and the technical contracts a change must keep. |
| docs/decisions/ | Who decided what and why. Read when you need the reason for a rule. |
| docs/roadmap.md | The order of the work. Units of work are GitHub issues. |
| docs/user-guide.md, README.md | How to use it. They follow the specification and define nothing. |
| docs/review-checklist.md | The lens for an independent review of a fixed commit. |
| docs/verification/ | Evidence for a few risky changes. Logs, not rules. |
| Sources/ReaderCore, Sources/UnagiReader | The core (no UI) and the SwiftUI / AppKit app. |
| Tests/ | Tests, synthetic data only. A test that checks an acceptance scenario says so in a comment (`// PRD-04`). |
| scripts/ | Build, CI gate and checks; each `x.sh` has a `test-x.sh`. |

## Commands

```sh
swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build          # local tests
swift test --scratch-path /private/tmp/unagi-reader-ci-build --force-resolved-versions --disable-keychain --disable-netrc   # as CI runs them
bash scripts/build-app.sh release                                        # ad hoc signed .build/Unagi Reader.app (debug is the default)
bash scripts/fetch-ci-app.sh <PR number>                                  # a PR's CI-built app, without the quarantine attribute (needs gh)
open -n '.build/Unagi Reader.app' --args --data-directory /private/tmp/unagi-reader-demo --seed-demo   # a synthetic run in a NEW instance
git diff --check
python3 scripts/check_docs.py                                          # links, decision numbers and statuses, PRD tags (--online: closed issues in marks and the roadmap)
bash scripts/test-check-docs.sh
```

- **The synthetic run needs `open -n`.** Without it, `open` can reuse a running Unagi Reader and drop `--args`, and you would be working on the person's library. Before touching anything, check that the process has the temporary `--data-directory` (`pgrep -fl UnagiReader`) and that the window shows the synthetic subscriptions.
- **Opt-in store checks** (not in CI during the beta): `bash scripts/prepare-v1-store-fixture.sh <new dir>`, then `UNAGI_READER_V1_FIXTURE_DIR=<dir> swift test …`. The other fixtures are in architecture 3.
- **CI** (macOS 26 / Xcode 26.6 / Swift 6.3.3) has three jobs. `regression` runs the tests for any change to code. `release` (optimized build, ad hoc signature, packaged app) runs on a PR only when it changes `Package.swift`, `Package.resolved`, `ThirdPartyNotices.md`, `scripts/build-app.sh`, `Assets/*` or `.github/workflows/*`, and always on `main` and manual runs. `check` is the one required status: it runs the documents check, skips the macOS jobs for a PR of only `docs/**` or Markdown, and otherwise passes only when every due job passed (`scripts/ci-gate.sh`). A PR run usually has no packaged app; run the workflow by hand or build locally.
- **The local Mac** (macOS 27 / Swift 6.4) is the only place the support floor macOS 27.0 is exercised ([decision 0007](docs/decisions/0007-support-floor-macos-27.md)). Do not use APIs that need the macOS 27 SDK.

## How work is tracked

- **The roadmap** is the order, short, with links. **An issue** is a unit of work someone can start today and know when it is done: Problem, Acceptance Criteria, Constraints, Out of scope. A bug, tech debt or a question for the owner is an issue at once. **An idea** is one line in the roadmap's candidates. Work in none of these is not tracked: open an issue instead of leaving a note in a chat or a PR.
- **One issue, one pull request, `Fixes #n`.** Say that you take it. Before you start, look at the open PRs that touch the same files. An issue with an open question for the owner waits for the answer.
- **PR titles start with the kind:** `feat:`, `fix:`, `refactor:`, `test:`, `docs:` or `ci:`.
- **A bug found on the way** becomes a new issue, not a bigger PR.
- **Labels say what can run beside what.** `area:no-screen` touches no screen and can run beside anything. `area:reader-view` touches `ReaderView.swift` and its long modifier chain: one at a time.
- **Where PRs collide:** `ReaderView.swift`, the end of the decision index, and decision numbers (take the next free number when you open the PR; renumber if `main` moved).
- **The milestone Beta** is closed to new issues; only the owner adds to it.
- **A plan** for work of several PRs goes to `docs/superpowers/plans/` and is deleted when its last PR merges.

## Starting or resuming

A new thread has no memory of the last one. Rebuild the state from Git and GitHub, not from a summary: the branch, HEAD, uncommitted changes, open PRs, the relevant part of the specification. Say what is done, what is not, and the next step before changing anything. Reuse an earlier PASS only for the same commit and environment.

## Boundaries

- Tests use synthetic RSS / HTML and temporary databases. Never read the person's library, credentials, Keychain, browser profile or other projects. `/private/tmp` is scratch, not a security boundary.
- GitHub only through the host's signed-in `gh`; never read, copy or pass a token. An Apple ID, certificates and signing keys are never given to an agent.
- Local edits, tests, builds and commits are allowed. Check concrete URLs, dependencies, migrations and external writes against the person's current instruction; what the task already allows need not be asked again.
- Never: read credentials, a destructive `reset` or `clean`, `sudo`, turning the sandbox off, running an outside script. Do not use subagents as a habit; never give a child agent the whole conversation, the person's data or credentials.
- Never push to `main`. Never sign, submit or publish an app without the owner's instruction. A new or changed dependency (SwiftSoup is pinned exactly) needs the owner's instruction.
- Work as one supervised implementation writer ([decision 0002](docs/decisions/0002-single-supervised-writer.md)). No unattended workers, and do not resume the Keychain probe. A reviewer reading a fixed commit is not "read-only isolation" because a prompt says so.
- `docs/vision.md` is the owner's words; change it only on the owner's instruction. Check every feature against its four questions.
- Data: no compatibility between betas, saves within one version are kept, from 1.0 nothing is lost ([decision 0003](docs/decisions/0003-beta-data-compatibility.md), specification 7.1). Never delete an unreadable store automatically.

## Definition of done

Always:

1. One theme per PR. Bugs the owner reported come before polish. Say what the PR does not include.
2. A bug is reproduced by a failing test first; the PR records both results.
3. Unverified behavior is never written as PASS (macOS 27.0, input methods, VoiceOver, Reduce Motion, long use). The PR lists what it leaves unverified.
4. A change of behavior or policy changes the specification or the architecture in the same PR. A **decision record** only when a policy, or what a person can do or rely on, changes; layout, sizes, timings and wording go to the specification only.
5. A save or change the person asked for is never reported as done when it was not (`try?` that drops a failure; text lost because its target is gone). Cancellation, a stale async answer and an action with nothing to act on are legitimate no-ops; keep them distinct.
6. **A document PR removes what it replaces.** When you add a rule, delete the old wording in the same PR; do not repeat a rule that has a home (vision, specification, architecture, this file) — link to it. A PR that only adds text says why.

By risk:

| Change | Also needed |
|---|---|
| Store or model, concurrency, external writes, retention or deletion | All tests; the release build when UI or packaging changes; a synthetic app run for UI; an independent review of a fixed commit (docs/review-checklist.md); the environment of each result |
| UI polish, labels, small behavior | Tests for the changed logic; `git diff --check`; a synthetic run only when a test cannot show it |
| Documents only | `git diff --check` and `python3 scripts/check_docs.py` |

Evidence stays small: a verification record only for a risky change or a PASS that 1.0 relies on, at most one per PR, the result in the first three lines. No raw logs or probe code in the repository. A low-risk review is one pass.

## Language

The chat with the owner is in Japanese; everything else is in English (the owner, 2026-10-14). Plain English: short sentences, common words, the same term for the same thing. The app's labels are Japanese: quote them exactly, with a short gloss when it helps. Old decision records and old commits stay as they are.

## Known gotchas

- macOS 26: after a failed save, registered models can keep unsaved values. Use `ReaderStore.rollback()`, resolve models by ID, and call `reloadIfNeeded()` first in any new mutating method (architecture 3.1).
- The CI compiler (Swift 6.3.3) crashed on an actor-isolated method reference passed as a `Binding` setter; use an explicit closure (PR #14).
- The CI compiler gave up type-checking when `ReaderView`'s modifier chain grew (PR #96; local Swift 6.4 was fine). Add window-level modifiers outside the chain (a `ViewModifier` in the wrapper `body`, as `OPMLImportPresentation`).
- A hosted UI test must not call `NSButton.performClick`: its nested event loop can stop the run loop, and the test process ends with exit code 0 and no summary line. Drive the app with the key handlers (`NativeArticleList.Table.keyHandler`). `scripts/check-test-log.sh` fails CI when the summary is missing. Run a changed UI suite several times.
- Hosted tests that fold split view columns run one after another, under `SplitViewFoldTests` (`Tests/ReaderUITests/ReaderLayoutTests.swift`).
- Three problems showed only in CI (PR #10 SwiftData rollback, PR #12 the packaged app's signature, PR #14 the compiler). Local success is necessary, not sufficient.
