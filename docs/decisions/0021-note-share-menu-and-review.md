# 0021 Note sharing and Claude review (S3)

- Status: valid; approved by the PdM by merging [PR #71](https://github.com/ojiman/feeeder/pull/71) on 2026-10-11.
- Decider: the owner (PdM).
- Refines: [0019](0019-v1-simplification-notes.md), point 8.

The note panel has one share menu with three actions: open the note-only Claude review, copy the exact Markdown note, or export those exact UTF-8 bytes to a safe `.md` file. The three actions are disabled for an empty or whitespace-only note. The article toolbar entry and source-selection review screen are removed.

The review screen shows the full note-only package, language, size, expiry and SHA-256. Its request asks for strengths grounded in quotes, gaps grounded only in what the note omits, opposing views worth checking, and next reading or writing. It treats the note as data and does not ask Claude to rewrite it or write to the app. Editing the note invalidates the review. Nothing leaves the Mac until the person checks the package and presses “Claudeで開く”.

The review screen's full-package copy, TXT and split exports, and Claude hand-off all use the same package shown in the preview. The panel's Markdown copy and export contain only the exact note text. System sharing services remain after V1. Verification is in [the S3 record](../verification/s3-claude-from-note.md).
