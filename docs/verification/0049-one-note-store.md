# Verification: one note (decision 0049, step 3)

**Result:** PASS for the store change and the tests on macOS 27 / Swift 6.4 (local). The screen was **not** checked in a synthetic app instance (access to the app was declined). CI (macOS 26 / Swift 6.3.3) has not run for this commit when this record was written. The independent review of the fixed commit has not been done.

Commit under test: the head of the pull request that adds this file. Baseline for the old-store check: `60da7dff8ff3741afc0707652bedea256f9e83df` (main before this change).

| Check | Result | Environment |
|---|---|---|
| `swift test` (all, as `scripts/check-test-log.sh` reads it) | 292 tests passed in two runs (206 core, 86 UI), guard passed | macOS 27, Swift 6.4 |
| Opt-in: old store with three notes and three article records (`OneNoteStoreUpgradeTests`, fixture from `60da7df`) | PASS: opens; one note is left, the one edited last, with its text and dates; the other two are gone; feed, articles, read time and Star are kept; a write and two more opens are stable | same |
| Opt-in: released V1 store (`V1StoreUpgradeTests`) and the store before decision 0019 (`PreNoteStoreUpgradeTests`) | PASS with the one-note expectations | same |
| First start with several notes, with the same edit time, with none, with exactly one | PASS (unit tests in `NoteTests`) | same |
| Synthetic app instance (own data directory) | **Not run**: access was declined | – |

## What the old-store check showed

Opening the old store removes the `NoteArticle` table. Core Data writes a log line, "Persistent History has to be truncated due to the following entities being removed", as `error:`, the same as when the five older models were removed. Nothing else in the store was lost. The old records of articles in notes are gone; this is decision 0049's point 2.

## What this leaves unverified

- How the screen looks and behaves: no note list in the sidebar, the note button and `⌥⌘I` opening the same note from Feeds, Star, a folder and a subscription. The UI tests open the panel from `.all` and `.starred` in a hosted window only.
- The store check ran on one machine and one OS. The support floor (macOS 27.0) is the local one; the build floor (macOS 26.6) is only what CI builds.
- A store that cannot be cleaned (for example a failed save at the first start) makes opening fail with an error. No test injects that failure; the code path is `keepOnlyOneNote(at:)` in `Sources/ReaderCore/Notes.swift`.
- Real data with many notes, a very large note, and the time of the first start on a large library.

## How to repeat the old-store check

```sh
bash scripts/prepare-v1-store-fixture.sh /private/tmp/unagi-reader-pre0049-fixture 60da7dff8ff3741afc0707652bedea256f9e83df
UNAGI_READER_PRE0049_FIXTURE_DIR=/private/tmp/unagi-reader-pre0049-fixture swift test --scratch-path /private/tmp/unagi-reader-dogfooding-build --filter OneNoteStoreUpgradeTests
```
