# Reading budgets (issue #164)

Result: W1 PASS; W2 FAIL while reading and refreshing; W3 FAIL. These are measurements, not product acceptance. The budgets in specification 2.1 are unchanged.
Scope: main `6123a6d` plus instrumentation at `5fff2b3f2576940cc44b0c4bace1cd2d81b02799`, Release, macOS 27.0.1 (26A434), arm64 Mac14,2, Xcode 27.0 (27A266a), Swift 6.4, display at 60 Hz. One clean replay on 2026-10-17; no UI inspection, build or tests during it.

| Budget | Measured result | Status |
|---|---|---|
| W1: p95 ≤ 100 ms, maximum ≤ 200 ms | 100 `j` / `k` events; nearest-rank p95 72.200 ms; maximum 82.796 ms | PASS |
| W2: no scheduling delay over 100 ms | Reading: 5 gaps, longest 121.913 ms. Typing: 0 gaps. Refresh: 1 gap, 264,999.531 ms | FAIL: [reading #249](https://github.com/ojiman/unagi-reader/issues/249), [refresh #252](https://github.com/ojiman/unagi-reader/issues/252) |
| W3: launch to list ≤ 1,000 ms | 4,763.954 ms | FAIL: [#250](https://github.com/ojiman/unagi-reader/issues/250) |

The replay uses a fresh copy of `BenchmarkFixtureTests`: 100 subscriptions, 10,000 articles, 80 Japanese paragraphs per body, with the fixture's links and quote formatting. The ordinary startup path runs with the fixture's source-less feeds. W1 is 51 `j` and 49 `k` events, including the initial selection; each must produce a display-start result before the next event, followed by a 300 ms pause. Typing inserts 60 committed ASCII characters through the actual note editor at 50 ms intervals and checks the saved text exactly. Note opening and setup are not W2 phases.

For refresh, setup assigns each synthetic feed its own URL and saves through the existing store path. In-memory HTTP responses then supply 100 existing entries per feed, through the ordinary parser and save/reload code. All 100 feeds finish without errors and the library retains 10,000 articles. The refresh phase stays open through the final yielded screen/layout pass. Heartbeat counts were reading 1,445, typing 193 and refresh 56; the long refresh interval delayed the heartbeat, rather than producing thousands of callbacks during the stall.

The reported pane bounds, in points, are reading: sidebar 185, list 400, article 654, note 0; note open: sidebar 0, list 0, article 1,240, note 400. These are the helper's AppKit bounds readings, not assumed defaults or a measurement of visible pixels.

The replay completed, wrote all three phases, produced exactly 100 display-start samples and no motion records, and quit normally. Raw output SHA-256: `9eadcfbf035c396e6d93d4fb8e332d64c43a77fe8a7aaa2606921fe2ef4f8a7a`. Executable SHA-256 before the synthetic copy's ad hoc re-signing: `b0cbd93846ec40383cc67b15d2d455eaafe0e38e0c63f8a1eeacc19f37c3863e`.

The kernel timestamp is for this process only (`proc_pidinfo`, `PROC_PIDTBSDINFO`). W3 ends after the first visible, nonempty table draw, so it includes loading the store and process initialization. It excludes Launch Services work before process creation and does not measure the render server's first visible pixel. W1 keeps the existing meaning of display start: entry into installing the article's nonempty text, before all its layout has finished. W2 is a 20 ms main-actor heartbeat; it records interval minus 20 ms when that delay is over 100 ms. It is a scheduling-delay measurement, not a full thread trace or a motion-frame measurement.

The first development trial was stopped after 5 minutes 44 seconds. It used an earlier startup sequence and included accessibility inspection, so none of its timing results are used here. A one-second sample showed its main thread inside `FeedRefreshController` → `applyRefresh` → `importFeed`, mostly scanning SwiftData articles and memberships. This is a lead for investigation, not a proven cause of every observed stall.

## Repeat

Build and export a new fixture, with the completion guard:

```sh
budget_fixture=$(mktemp -d /private/tmp/unagi-reader-budgets-fixture.XXXXXX)
budget_log=$(mktemp /private/tmp/unagi-reader-budgets-test.XXXXXX)
UNAGI_READER_BENCHMARK_DIRECTORY="$budget_fixture" swift test --scratch-path /private/tmp/unagi-reader-ci-build --force-resolved-versions --disable-keychain --disable-netrc --filter BenchmarkFixtureTests > "$budget_log" 2>&1 &&
    bash scripts/check-test-log.sh "$budget_log"
bash scripts/build-app.sh release
bash scripts/make-synthetic-copy.sh
```

Use the app path and new data directory printed by the last command. Copy the fixture into that empty directory with `ditto "$budget_fixture" <printed-data-directory>`. Replace `--seed-demo` in the printed launch command with `--performance-output <new-output.json> --reading-benchmark`, keeping `open -n -W` and `--data-directory`. Verify the process arguments and synthetic subscriptions as in AGENTS.md. The app performs the replay and quits; the full refresh can take several minutes. Start each repeat from a fresh fixture copy, because typing, read history and refresh change it.

Reject a missing file, a `readingBenchmarkError`, a false or missing `readingBenchmarkComplete`, anything other than 100 selection samples, a missing launch value, or missing reading/typing/refresh heartbeat counts. An empty or incomplete measurement is never a pass. For W1, sort the samples and use element `ceil(0.95 * count) - 1`; compare the maximum separately. For W2, check the aggregate and each phase's gaps, without averaging them away. For W3, compare `launchMilliseconds` to 1,000.

Not verified: other Macs, macOS 27.0 exactly, first launch after boot, Japanese input composition, VoiceOver, long use, live network timing, or CI performance. CI runs regression tests on macOS 26.6; it does not run the macOS 27 app or accept these budgets. No performance fix is included.
