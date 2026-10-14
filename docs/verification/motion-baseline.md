# Motion baseline (issue #212)

Result: the note's motions are the roughest: open, close and the layout switch show 8 to 11 frames of about 24 expected, with a longest frame of about 100 ms and 5 to 6 hitches per move. The original page's slide comes next (longest about 55 to 60 ms, 2 to 3 hitches); the filter is near the baseline. 11 to 12 main-thread stalls over 100 ms per run (budget W2 says none).
Scope: release build of `main` 8c2f3fe plus this PR's measurement code (no motion changed); macOS 27.0.1, Swift 6.4, MacBook Air M2 (Mac14,2), built-in display at 60 Hz; the 10,000-article synthetic library of `BenchmarkFixtureTests` (long bodies, 80 paragraphs); two runs of `--motion-benchmark`, 10 of each motion (20 article moves). The owner's own copy was running at the same time.

| Motion | Frames (median, of about 24) | Longest frame, ms (median / max) | Hitches per move (mean) |
|---|---|---|---|
| note open | 8 / 8 | 100.5 / 116.6 · 102.9 / 106.9 | 5.6 · 5.6 |
| note close | 10 / 11 | 82.5 / 113.3 · 81.9 / 102.2 | 5.6 · 5.4 |
| note layout switch | 9 / 10 | 86.9 / 100.6 · 83.0 / 92.0 | 6.0 · 5.4 |
| original page in | 15 / 17 | 59.7 / 67.8 · 54.6 / 83.8 | 2.7 · 3.0 |
| original page out | 21 / 21 | 62.9 / 66.7 · 57.9 / 66.7 | 1.6 · 1.9 |
| article move (`j` / `k`) | 17 / 18 | 35.6 / 84.4 · 19.0 / 28.8 | 0.9 · 0.2 |
| filter open | 20 / 20 | 37.9 / 78.6 · 36.9 / 63.5 | 0.8 · 1.1 |
| filter close | 21 / 21 | 24.3 / 33.3 · 24.8 / 33.3 | 0.7 · 0.5 |

Each cell gives run 1 · run 2 (frames: run 1 / run 2). A frame is 16.7 ms at 60 Hz; a hitch is a frame interval over 25 ms. Each motion is measured from its start to 0.15 s after its end (0.45 s for the 0.3 s folds).

How to read it:
- The display link's callbacks run on the main thread, so these numbers show frames the main thread could not serve; frames lost inside the render server are not seen.
- The link itself needs about 3 to 4 frames to start: even the light filter motion loses them, and the "start to first frame" field (about 65 to 105 ms everywhere) measures that, not the app. Compare frame counts against the filter (about 21).
- `j` / `k` selection latency (W1) in the same runs: 95th percentile 63 ms, within budget.

To repeat: `UNAGI_READER_BENCHMARK_DIRECTORY=<new dir> swift test --filter BenchmarkFixtureTests`, `bash scripts/build-app.sh release`, then `open -n -W '.build/Unagi Reader.app' --args --data-directory <dir> --performance-output <file.json> --motion-benchmark`.
