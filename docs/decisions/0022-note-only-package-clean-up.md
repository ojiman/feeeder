# 0022 Note-only packages and managed-copy cleanup (S4)

- Status: valid; approved by the PdM by merging [PR #74](https://github.com/ojiman/feeeder/pull/74) on 2026-10-11.
- Decider: the owner (PdM).
- Refines: [0019](0019-v1-simplification-notes.md), stage S4, and [0021](0021-note-share-menu-and-review.md).

Remove unreachable note helpers and article-source package paths. The note-only package keeps its exact text and hash; split parts need no source-id header. Every package and managed copy has a fixed maximum lifetime of 24 hours. The stored schema, including `NoteArticle.title`, `url` and `summary`, stays unchanged.

Old metadata is read leniently. Unknown fields, article selections and question ids are ignored; the old `themeID` maps to `noteID`. Copies follow note deletion when the id exists, or their original expiry, capped at 24 hours. Early deletion based on obsolete sources is no longer required. An edit keeps the managed snapshot. User exports and Claude-side content are never deleted by maintenance.

Existing safety checks still reject damaged metadata, symlinked folders and unrelated entries. Maintenance reports unsafe folders after processing independent valid copies; it does not infer ownership from a UUID folder name alone. No new recovery or deletion policy is introduced. Historical decisions and verification records are left unchanged.

The golden baseline and compatibility cases are in [the S4 record](../verification/s4-clean-up.md). Dropping stored columns and editor styling (S5) are separate work.
