# S5 note editor styling verification

PASS with limits — unit and UI tests, release build and one independent review at the commit named below, macOS 27.0.1 / Swift 6.4 (local). CI (macOS 26.6 / Swift 6.3.3) is checked on the PR.
Not verified: a real Japanese input method with the candidate window, VoiceOver, a very long note in a real window, copy to the system pasteboard, macOS 26.
Review: one independent pass found 1 Critical, 3 Important, 7 Minor; the Critical and Important ones and four Minors are fixed with tests that failed first.

| Check | Result |
|---|---|
| `NoteLineStyleTests` (scanner: UTF-16 ranges, rules, 60,000 lines under 0.5 s) | 7 pass; written first (compile failure), then GREEN |
| `NoteTextEditorTests` (text exact incl. CRLF, emoji, U+2028; look; composition; undo and redo saved once each; outside text; failed save; paste; own undo history) | 23 pass |
| Each UI suite alone (NoteReader 14, NotePanel 5, HandoffEntry 5, SendToNote 7, NativeArticleList 9, OriginalKeyboard 9, ReaderLayout 1, SidebarTitlebar 1, NativeArticleText 9) | pass |
| Whole `swift test` (UI suites are not in its count) | 218 pass |
| `scripts/build-app.sh release` | built |
| Synthetic snapshot of the editor | headings bold and larger, `#` grey, list marks orange, wrapped list lines aligned |

## Review findings and what was done

| Finding | Fix | Test |
|---|---|---|
| Undo and redo were not saved (TextKit 2 posts no change notification) | The editor owns an `UndoManager` and saves on its undo and redo notifications | `undoAndRedoAreSavedOnceEach` |
| A summary sent while composing was lost; an undone send came back | The outside text waits; after the composition an append, or the removal of an earlier append, is merged, then saved | `aSummaryThatArrivesWhileComposing…`, `aSendUndoneWhileComposing…` |
| A failed save replaced the typed text with the old text | `onChange` returns whether it saved; store text is not pushed over unsaved text | `aFailedSaveKeepsTheTypedTextInTheView` |
| Undo history shared with the window and other notes | Own `UndoManager` per editor | `eachEditorHasItsOwnUndoHistory` |
| List mark stayed coloured after the last character was deleted | Clamp by hand instead of `NSIntersectionRange` | `deletingTheLastCharacterOfAListLine…` |
| Smart insert and delete on; copy wrote RTF | Both off; the view writes plain text only | `smartPasteIsOffAndCopyHandsOutPlainTextOnly` (types only) |
| Outside text replaced the whole text and the selection length | Only the differing part is replaced; the selection is kept | `anAppendFromOutsideKeepsTheSelectionRange…` |

Deferred Minors: the placeholder can show under the first composition in an empty note; a full-width `＃` or U+3000 is not a heading; `Kind.listItem(indentSteps:)` is not used by the styling.

## Known flake, not from S5

`NoteReaderTests` run alone ends without a summary line in some runs (3 of 8 on the base commit `c32eb47`, 2 of 8 on this branch), always after `HandoffEntryTests`, with exit code 0. Existing issue; a separate task is open.

## Not verified

- A real Japanese input method (candidates, caret, long composition), VoiceOver, Reduce Motion.
- The pasteboard content after Copy in a real window (the test checks the types the view offers, not a pasteboard write).
- A long note in a real window; macOS 26 behaviour (CI builds only).
