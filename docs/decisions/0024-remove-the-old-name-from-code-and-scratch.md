# 0024 Remove the old name from code and scratch paths

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) asked for it after the rename merged: future AI agents read the repository, and the old names make them guess whether Feeeder is something else.
- Refines: [0023](0023-rename-to-unagi-reader.md), whose "Not changed" list is now done except the records.

## Decision

1. **The SwiftPM package, the app target, the executable and the module are called `UnagiReader`** (`Sources/UnagiReader`, `@testable import UnagiReader`, `Contents/MacOS/UnagiReader`, the struct `UnagiReaderApp`). The test targets keep their names.
2. **Scratch paths use `/private/tmp/unagi-reader-*`** (build, demo, fixture and CI paths, the debug build directory `unagi-reader-debug`). The opt-in test variables are `UNAGI_READER_*` (for example `UNAGI_READER_V1_FIXTURE_DIR`). Test pasteboard and temporary names use the prefix `unagi-reader-`. Old `/private/tmp/feeeder-*` directories are disposable and can be deleted.
3. **Links to the repository use `ojiman/unagi-reader`** (the owner renamed it on 2026-10-11). Links in old records stay; GitHub redirects them.
4. **What still says Feeeder, on purpose:** only old decision and verification records (history), and `scripts/prepare-v1-store-fixture.sh`, which builds old commits whose app target is still `RSSReader` (a comment says so). The current docs do not mention the old name: they describe the current app only, and Git keeps the history.

## Not verified

- Anything on macOS 26 beyond what CI builds.
- Old fixtures made under `/private/tmp/feeeder-*` still work only if their path is passed through the renamed variable.
