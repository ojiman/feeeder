# S4 clean-up verification
Result: core and individual UI suites PASS; the combined local UI runner did not print a completion summary. Independent review PASS; CI results are attached to [PR #75](https://github.com/ojiman/feeeder/pull/75/checks).
Environment: macOS 27.0.1 / Xcode 27.0 (27A266a) / Swift 6.4.0.34.1. Synthetic stores only.

Base: `c32eb47` (PR #74). Runtime under test: `4d43483`. One combined run and one explicit `--no-parallel` run returned exit 0 with core 187/35 PASS, but their UI output stopped mid-test. They are **not** recorded as a complete UI PASS. Each UI suite then completed separately. No interactive app or user library was opened.

Commands use `CLANG_MODULE_CACHE_PATH=/private/tmp/feeeder-clang-module-cache`, `--disable-sandbox` and `--scratch-path /private/tmp/feeeder-s3-review`. Full runs also use `--force-resolved-versions --disable-keychain --disable-netrc`; individual runs use `--skip-build --filter <suite>`.

| Check | Result |
|---|---|
| Golden baseline, before production changes (`d729cb6`) | 1 PASS; exact package bytes, literal hashes and split headers/hashes. |
| NoteInsertionTests / NoteTests | 29 PASS; build PASS. |
| AIPackageTests / AIHandoffFixtureTests / golden | 11 PASS. |
| ClaudeHandoffTests | RED: 18 assertions; GREEN: 16 PASS. Legacy keys, note deletion, expiry, unsafe files. |
| Combined core | 187 tests in 35 suites PASS; two opt-in compatibility tests skipped. |
| SidebarTitlebarTests alone | 1 tests / 1 suites PASS. |
| OriginalKeyboardTests alone | 9 tests / 2 suites PASS (filter also selects companion suites). |
| ShortcutResponderTests alone | 3 tests / 1 suites PASS. |
| SendToNoteTests alone | 7 tests / 1 suites PASS. |
| NativeArticleTextTests alone | 9 tests / 1 suites PASS. |
| ReaderLayoutTests alone | 1 tests / 1 suites PASS. |
| NativeArticleListTests alone | 9 tests / 1 suites PASS. |
| NoteReaderTests alone | 14 tests / 3 suites PASS (filter also selects companion suites). |
| NotePanelTests alone | 5 tests / 1 suites PASS. |
| HandoffEntryTests alone | 5 tests / 1 suites PASS. |
| ReaderLayoutTests repeat | Three independent runs PASS. |
| Release app / signature | PASS: `bash scripts/build-app.sh release` and strict bundle signature verification. |
| git diff --check | PASS. |

The note-only split already omitted `Source IDs:` on the base commit: no golden exception was needed. Schema and stored columns are unchanged. Searches leave only the live send destination picker, legacy `themeID` decoding/tests and old fixture manifest fields; none of the removed APIs remains.

Safety ruling: damaged metadata and symlink folders retain their existing error report and are not deleted without proof of ownership. Independent valid copies still expire on repeated passes. This interprets the plan's "none fails maintenance forever" as no obstruction of other copies, rather than silent deletion of an unsafe folder. Manual repair can still be needed.

Deleted or rewritten tests (exact names; alive behaviors remain covered):

| File | Tests | Reason / retained coverage |
|---|---|---|
| NoteInsertionTests | `adoptingUsesTheEndOfTheSelectionAndTheEndOfTheNoteWithoutOne`, `anEmptyNoteBecomesTheBlock`, `atTheEndTheBlockFollowsAfterABlankLine`, `atTheStartTheBlockComesFirstThenABlankLineThenTheText`, `crlfNotesKeepTheirLineBreakStyle`, `emojiAndCombiningMarksAreNotSplitAndTheOffsetCountsCharacters`, `inTheMiddleOfALineTheTextAroundIsSeparatedAndNeverChanged`, `theCursorIsRightAfterTheBlockInTheNewText` | Removed cursor adoption; summary block, heading, append, CRLF and long text remain. |
| NoteTests | `creatingWithAnArticleIsOneAtomicSave`, `toggleAddsThenRemovesAndNamesTheNote` | Removed toggle and combined picker creation; send/undo atomicity and failed-save tests remain. |
| AIPackageTests | `anEditOfTheNoteDoesNotInvalidateAReviewThatDoesNotIncludeIt`, `anEmptyNoteIsNotIncludedAndANoteWithoutOneCannotBeSentWithoutSources`, `lifetimeShortensWithoutExtendingOrReviving`, `mixedSourcesUseTheEarliestExpiry`, `noteSummaryAndTheArticleItselfCannotBeMixed`, `noteSummaryIgnoresOriginalExpiryAndFollowsMembership`, `reviewClearsWhenRetentionShortensOrContentIsDeleted`, `reviewInvalidatesWhenSourceExpiresOrChanges`, `splitPreservesEveryUTF8ByteAndSourceMapping`, `theNoteIsIncludedOnlyWhenAskedAndNoGoalIsEverMentioned`, `wholeSourcesLanguageCoverageAndHashArePreserved` | Removed article sources, optional note exclusion and source expiry; note inclusion, empty/missing note, language, edit/deletion, fixed expiry, markers and lossless splits remain. |
| ClaudeHandoffTests | `aCopyOfARetainedArticleIsRemovedWhenThatArticleLeavesTheNote`, `aCopyWithTheNoteIsRemovedWhenItsNoteOrASourceIsDeleted`, `aCopyWithoutTheNoteIsRemovedWhenItsNoteIsDeleted`, `aCopyWrittenBeforeTheRenameStillFollowsItsNote`, `aCopyWrittenBeforeTheRenameToNotesIsRemovedWithoutFailingMaintenance`, `copiesFromOlderVersionsStillReconcile`, `generatedFilesInvalidateAfterDeletionWithoutChangingExports`, `generatedLifetimeShortensAndNeverExtends`, `legacyScrapMetadataIsDeletedInsteadOfFailingEveryMaintenance`, `savedSourcesAndOldMetadataReconcile` | Removed source invalidation/shortening; legacy fields rewritten to note/expiry compatibility. Launch retry, validation, path safety, independent cleanup and note deletion remain. |
| AIHandoffFixtureTests | `storedLargeSourceExportsLosslessUTF8Parts`, `storedLongJapaneseAndSummarySourcesProduceCompletePackage` | Rewritten as stored-note fixtures; long Japanese text and lossless exports remain. |

Production diff: 40 added / 269 removed lines (net 229 fewer); no model file changes.

The recovery matrix in `ReaderStoreTests` drops only removed methods; `PreNoteStoreUpgradeTests` uses create + add for its opt-in fixture, without changing the fixture baseline.

Independent fixed-commit review: `c32eb47..359d045`, no Critical/Important/Minor findings. Separate targeted rerun: 27 tests / 4 suites PASS; diff check PASS. No fix pass needed. CI uses macOS 26 / Xcode 26.6 / Swift 6.3.3. Its result is recorded in [PR #75 checks](https://github.com/ojiman/feeeder/pull/75/checks), independently of the local evidence above.

The reviewer did not rerun fresh compilation, whole/UI suites, Release/signature or archives; local evidence above stands without claiming independent execution. The reviewer also did not verify external approval/status, opt-in fixtures, future migrations, adversarial concurrent filesystem replacement or OS-level isolation. These remain outside this cleanup's claims. The subsequent decision index and result-only evidence edits do not change runtime code.

Not checked: opt-in beta fixture preservation, interactive Claude launch/attachment/read, IME, VoiceOver, Reduce Motion and long-running use. Existing [S3 limits](s3-claude-from-note.md) still apply. S5 and schema changes are excluded.
