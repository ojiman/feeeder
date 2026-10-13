# App icon production preparation

Result: PASS for image format, packaging and Finder display on macOS 27.0.1 / Xcode 27.0 / Swift 6.4. Dock display is not verified: the UI tool does not expose Dock and direct access timed out.
Scope: the PR #121 commit adding this record. This does not establish macOS 26 display or final product acceptance.

| Check | Result |
|---|---|
| Source PNG | 1024 × 1024; every pixel opaque; orange at all four corners; no baked-in corner mask |
| Release build and ZIP round trip | PASS; extracted app has the committed icon, `CFBundleIconFile=AppIcon`, and a valid strict signature |
| Synthetic launch | PASS; process arguments include `/private/tmp/unagi-reader-hig-review-121`; demo data only |
| Finder Get Info | Visually checked at a new extracted path; orange icon with OS-rounded corners, no additional silver plate |
| Download-script and CI gate tests | PASS; includes missing bundle, old bundle filename and asset-only release classification |
| `git diff --check` | PASS |
| Not checked | Dock (tool access failed), macOS 26, dark/clear/tinted icon appearances, Gatekeeper's Open Anyway prompt (no quarantine), full Swift tests |

The image was edited with ImageGen to remove the tile mask and transparent margins, then resized with `sips`. The eel motif remains; this is not a claim of byte-identical artwork. Finder was checked on a fresh ZIP extraction under `/private/tmp/unagi-reader-hig-check.qncBrb`, with a separate temporary library.
