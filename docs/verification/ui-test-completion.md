# UI test completion (issue #133)

Result: PASS. Both controlled regressions changed from fail to pass; 20 consecutive filtered runs and full runs with both build systems completed and passed the log check.
Scope: test-helper change at f3cb9e6a6aae1e9c7a0dbc91841b3ff2a8594a15, based on `main` 91a2c01; synthetic views and temporary databases only. No product code changed.
Environment: macOS 27.0.1 (26A434), arm64, Xcode 27.0 (27A266a), Swift 6.4, Swift Testing 2084; default build system `swiftbuild` unless stated otherwise.

## Reproduced failure and change

`NoteReaderTests.settle` pumped a nested run loop without suspending its MainActor task. A view update queued on that actor could not run before the helper gave up. On a bare view, its 100 iterations ended in about 34 ms. After the timeout, `#expect` recorded a failure but returned normally, so callers could continue with a missing required view.

Two tests pin down those behaviors:

- `theWaitLetsQueuedViewUpdatesRun`: queue a MainActor task that makes a view visible, then wait for it. Before: the wait failed. After: the queued update runs and the wait succeeds.
- `aMissingRequiredViewStopsTheTest`: a view that never becomes ready must throw. Before: the helper recorded a failure and returned; the expected error was absent. After: the helper throws, so the caller cannot continue.

The helper now sleeps asynchronously between checks and throws a descriptive error at timeout. The chevron test also checks the captured button count immediately before subscripting it. The retained report `swiftpm-testing-helper-2026-10-14-140307.ips` names `Array._checkSubscript`, `Array.subscript.getter` and `NotePanelTests.theChevronsMoveBetweenTheNotesArticlesAndStopAtTheEnds`. The patch removes this unsafe continuation path. It does not establish that every historical early exit had the same cause.

## Fixed-source verification

| Check at `f3cb9e6` | Result |
|---|---|
| `--filter NoteReaderTests`, 20 consecutive runs | PASS. Every run: 10 tests in 3 suites, exit 0, one passing summary and log checker exit 0 |
| Default full run | PASS. 124 UI tests in 25 suites, then 234 core tests in 37 suites; both summaries, exit 0 and log checker exit 0 |
| `--build-system native`, full run, stdout and stderr saved separately | PASS. 358 tests in 62 suites, exit 0 and log checker exit 0 on the complete streams joined after the process ended |

The filtered command selects `NoteReaderTests`, `NotePanelTests` and `MarkdownCopyTests` from the same file. No tests were skipped to obtain these results. The log checker was not weakened.

## Baseline and other termination evidence

| Check | Result and limit |
|---|---|
| Unchanged `91a2c01`, 20 default filtered runs | All finished: exit 0, 8 tests in 3 suites and one summary each; every log check passed. This did not reproduce the reported failure |
| Unchanged `91a2c01`, default full run | Finished: 122 UI tests in 25 suites, then 234 core tests in 37 suites; both summaries and the log check passed |
| Unchanged `91a2c01`, native full run with merged streams | Rejected log: the deprecated-option warning split the final summary between two lines. This was output interleaving, not evidence of early termination. Log SHA-256: `640a800a79a22bbca4cc27d5a4abf85ca59e0bff20fcaab0dcccc6ec82c01a33` |
| Native full run under the debugger | A summary for 356 tests appeared before `Testing.__swiftPMEntryPoint` called `exit(0)` |
| [Green CI before #117](https://github.com/ojiman/unagi-reader/actions/runs/38277123444), `2dd9670` | Retained log: 365 tests started, 364 ended, no summary. The current checker exits 1; an old layout test also failed |
| [Current main CI](https://github.com/ojiman/unagi-reader/actions/runs/38723527500), `91a2c01` | A summary appeared: 356 tests in 62 suites, one failure. The filter took 59.343417 ms against a 50 ms assertion. Separate issue: [#230](https://github.com/ojiman/unagi-reader/issues/230) |

[PR #117](https://github.com/ojiman/unagi-reader/pull/117) already records a different debugger trace: `CFRunLoopStop` inside `NSButton.performClick`, then the async main loop ending with exit 0. Its mitigation uses key handlers instead of clicks. Temporary comparisons here restored that call in current source (10 filtered runs and one full UI run) and ran the pre-#117 source with both build systems. None reproduced a missing summary. The old native full UI run failed its already-fixed layout wait and the log check; it did print a summary.

The warning also split an end line in a fixed-source native run, although its final summary said all 358 tests passed. The checker correctly rejected that corrupted log too. Saving stdout and stderr separately removed the interleaving; the complete raw streams then passed the unchanged checker. No warning-stripped or otherwise repaired log was counted as passing verification.

The helper fix is supported by the controlled regressions and the array-crash report. This investigation does not assign a single cause to every historical early exit. Keep the log check for local runs as well as CI. Never infer a pass from exit code 0 alone.

## Repeat and preserve a failure

Use the checked local command in [AGENTS.md](../../AGENTS.md#commands), adding `--filter NoteReaderTests` before the redirection for the filtered check. The filter selects the three suites in the file, not just the `NoteReaderTests` type. Use a separate scratch path when another writer is running tests. Keep SwiftPM sandboxing enabled; use `--force-resolved-versions --disable-keychain --disable-netrc` for the CI dependency options.

Write stdout and stderr directly to a fresh log, not through `tee` (#186). Preserve both the SwiftPM exit code and the checker result. The checked command runs the checker only after SwiftPM succeeds, so neither failure becomes a pass.

For a new incomplete run, preserve the complete log, last started test, source commit, OS and Swift versions, build-system choice, command and process exit code before retrying. A rerun cannot explain the first failure. Raw logs, checksums and temporary comparison sources for this investigation are outside the repository at `/private/tmp/unagi-reader-133.iQhCHi`.

Not checked: exact macOS 27.0, a new macOS 26.6 CI run, interactive app behavior, input methods or VoiceOver. Opt-in store fixtures were not supplied; passing test-process totals do not establish those compatibility checks.
