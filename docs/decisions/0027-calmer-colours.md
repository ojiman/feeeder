# 0027 Calmer colours

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-11
- Decider: the owner (PdM) found the orange harsh and the whites too white. The points marked "PO" are the Product Owner's.

## What was measured

Pixel colours of Unagi Reader before the change (dark mode, from a screenshot):

| | Unagi Reader (before) |
|---|---|
| Body text on its background | #DDDDDD on #1E1E1E (12:1) |
| Heading | 30 pt bold, #DDDDDD |
| Sidebar item text | #FEFEFE (16:1) |
| Colour accents | `systemOrange` (saturation 0.96) on the source name of every unread row, on the buttons; the system blue on the selected row |

The pure white sidebar, the large bold heading, the loud orange and the blue selection stood out. Body text and its background stay unchanged; the decision below softens the surrounding elements.

## Decision

1. **One soft accent** (`AppPalette.accent`): about #E6A366 in dark and #C26624 in light mode. It is used for small marks only: the unread dot, the + and refresh buttons, the marks of lists in a note, the icon of the empty reading pane. The source name in the list is gray; only its dot has the accent. *(PO.)*
2. **The selected row of the article list is a quiet neutral gray** (white 13% in dark, black 9% in light mode), also when the list has the keyboard focus, instead of the system's saturated accent colour. A selected row that is read is not dimmed. *(PO.)*
3. **The headline of an article is 26 pt semibold** (was 30 pt bold). *(PO.)*
4. **Sidebar items:** icons are gray (`.secondary`) so the system does not paint them with its blue in the active window; the text is 85% of the primary colour instead of pure white. *(PO.)*
5. Body text, the colour of links and the background colours are not changed here.

## Not verified

- The look in the light appearance and with a different system accent colour; with a long use.
- The sidebar text at 85% on a selected sidebar row in the active window (checked only in a window that was not the key window).
- Contrast of the soft accent as text: it is used for marks, not for text.
