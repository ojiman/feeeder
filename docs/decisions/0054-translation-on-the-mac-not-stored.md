# 0054 Translation runs on the Mac with the system's framework, and is not stored

- Status: valid (approved by the PdM when the PR that adds this record is merged)
- Date: 2026-10-14
- Decider: the owner (PdM), in the answers of 2026-10-12 recorded in the [translation design](https://github.com/ojiman/unagi-reader/blob/78b5dc5cbfb625bcbc89f54409da3ff3056e0bca/docs/superpowers/plans/2026-10-12-translation-design.md) (section 11). Written down by the agent with the first translation PR (#152), as the design asked.
- Refines: [0049](0049-one-note-and-no-ai-of-its-own.md) (no AI of its own) and [0019](0019-v1-simplification-notes.md) (retention).

## Decision

1. **The person can translate the open article, on the Mac, with the system's Translation framework.** The app ships and runs no model of its own and sends no text anywhere. Foundation Models is not used. Like the Writing Tools in the note, translation is a function of the system, so it fits 0049.
2. **A translation is not stored.** It is not in the library and not under the retention rules. A few recent results are kept in memory and are gone when the app closes.
3. **It starts only when the person presses, and it is not sticky.** Another article opens in its original language; a late answer for another article, language, press or body is dropped.

What the person sees is in the specification, 3.6.

## Why

The person can read a hard article in the same window, without copying text to another app (vision, question 1), and nothing new has to be managed or kept (question 2). Storing translations would add data under the retention rules for little gain: a translation can be made again in seconds.
