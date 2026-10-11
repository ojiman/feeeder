# S2 summary sending — verification
**Result: local regression, Release build and synthetic window checks pass.**
**Code: `39f8698`; macOS 26 CI and real model quality remain unverified.**

Environment: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), Apple Swift 6.4; synthetic RSS/HTML and temporary databases only. Plan approved in [PR #69](https://github.com/ojiman/feeeder/pull/69); contract in [decision 0020](../decisions/0020-summary-send-contract.md).

| Check | Result |
|---|---|
| Baseline at `8cf58a6` | 207 ReaderCore tests in 34 suites pass |
| Text rules | RED missing APIs → 11 NoteInsertion tests pass; AI mark, empty summary, folded title, CRLF, 100,000-line append |
| Settings and prompt | RED missing APIs → 9 settings/prompt tests pass; Bool-as-length reproduced and rejected; instructions separate from article text |
| Atomic send and undo | RED missing APIs → 31 note/store tests pass; save rollback, reload failure, blocked recovery, repeated send, unchanged-text guard |
| Sender | RED missing API → initial tests pass; unavailable/failed/blank output, deadline, cancellation, AI off, target deletion, undo, late answers and bounded hostile input |
| Final core regression | `swift test --scratch-path /private/tmp/feeeder-dogfooding-build`: 208 tests in 34 suites pass; deliberate corrupt-store/save-failure tests emit expected diagnostics |
| Individual UI suites | 47 distinct tests in 10 suites pass. Final affected run: SendToNoteTests, NativeArticleListTests and NoteReaderTests (including NotePanelTests and HandoffEntryTests), 27 tests in 5 suites. Other suites unchanged from `4fdac23`: OriginalKeyboardTests, ShortcutResponderTests, NativeArticleTextTests, ReaderLayoutTests, SidebarTitlebarTests |
| Release and signature | `bash scripts/build-app.sh release` and `codesign --verify --deep --strict .build/Feeeder.app` pass with the final source; ad hoc signed |
| Synthetic window | Separate bundle ID and `open -n`; process arguments confirm `/private/tmp/feeeder-s2-smoke.ZO9ccv/Library`. No selection disables send; `n` opens the menu; Return sends RSS/source to a new note; Undo removes it; repeated sends keep one source; Open shows the note; settings expose the AI toggle, length, format and instruction |
| Closed-panel regression | Independent review found Open did nothing for a closed panel. UI regression RED → GREEN; final window checks show Open reopens both the current closed note and a closed note reached from All Articles |
| Provenance regression | Independent review found AI text without title/URL lost its mark. RSS parser → store → fake model → saved-note test RED → GREEN; mark remains on its own line |
| Row-menu regression | Window check found labels intercepted right-click with the OS text menu. Hit-test regression RED → GREEN; final window shows “このノートから外す” and removes the source while preserving note text |
| Independent review | Fixed range `8cf58a6..4fdac23` reviewed against the checklist and connected parser/store/concurrency/UI paths. Two Important findings; both corrected in `39f8698` with failing regressions first. Reviewer did not run tests or window checks; writer ran them above |
| Documentation | `git diff --check` and changed Markdown links pass; spec, architecture, both user guides, decision and roadmap updated; completed stage plan removed |

A save failure rolls back. A reload failure after save reports failure but keeps the committed write; the guides warn against repeating without checking the note. No schema or dependency change.

Not verified: real model quality on real articles; Japanese composition; VoiceOver; Reduce Motion; macOS 26 CI; long-running use; the owner's library. S1 panel width and resizing limits remain in [the S1 record](s1-notes.md). Claude's new share button (S3), cleanup (S4) and editor styling (S5) are outside this PR.
