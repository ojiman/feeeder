# S2 summary sending — verification

**Result: verification in progress. No final PASS claim yet.**

Environment: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), Apple Swift 6.4; synthetic RSS/HTML and temporary databases only. Plan approved in [PR #69](https://github.com/ojiman/feeeder/pull/69); contract in [decision 0020](../decisions/0020-summary-send-contract.md).

| Check | Result |
|---|---|
| Baseline at `8cf58a6` | 207 ReaderCore tests in 34 suites pass |
| Text rules | RED missing APIs → 11 NoteInsertion tests pass; AI mark, empty summary, folded title, CRLF, 100,000-line append |
| Settings and prompt | RED missing APIs → 9 settings/prompt tests pass; Bool-as-length reproduced and rejected; fixed instructions separate from article text |
| Atomic send and undo | RED missing APIs → 31 note/store tests pass; save rollback, reload failure, blocked recovery, repeated send, unchanged-text guard |
| Sender | RED missing API → 6 initial tests pass; availability, failed/blank output, deadline, cancellation, AI off, target deletion and undo |
| UI | RED missing screens → 6 SendToNote tests pass before the Open action; Return/Escape, 8 recent targets, send/undo, removal, input policy, settings field |
| Final regression, individual UI suites, Release and window check | Pending |
| Independent fixed-commit review | Pending |

A save failure rolls back. A reload failure after save reports failure but keeps the committed write; the guides warn against repeating without checking the note. No schema or dependency change.

Not verified: real model quality on real articles; Japanese composition; VoiceOver; Reduce Motion; macOS 26 CI; long-running use; the owner's library. S1 panel width and resizing limits remain in [the S1 record](s1-notes.md). Claude's new share button (S3), cleanup (S4) and editor styling (S5) are outside this PR.
