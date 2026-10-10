# Goal review experiment: can the on-device model review a note against its goal?

Updated: 2026-10-11 (Japan time). **Result in short:** not reliably. The model is quick (1 to 3 seconds) and it spots a note that has drifted away from the goal, but its judgments of a decent note are partly wrong, and its "is this note on the goal" check contradicts itself. An always visible review would show a wrong claim often enough to mislead. Asking for *questions to write about next* is safe but generic. Nothing here is product code.

Environment: Apple Silicon Mac, macOS 27.0.1, Swift 6.4, `SystemLanguageModel.default`, called through the app's own `FoundationModelsGenerator`. Input: one synthetic goal ("choose between a variable and a fixed mortgage rate on my own") and three synthetic notes (a thin one of 38 characters, a decent one of 251 characters that covers rates, the 5-year rule, fixed-rate trade-offs and the writer's own income and child costs, and a note that drifted to central-bank meetings and exchange rates, 139 characters). Five prompts, each run twice on each note (30 runs). No real article, library or credential was used. Outputs change from run to run. The quality notes are the agent's reading, not the PdM's judgment. The probe was a throwaway test and is not kept.

## What was measured

| Check | Result |
|---|---|
| Time for one request | 0.9 to 3.2 s for notes of 38 to 251 characters (the goal is about 50 characters) |
| Following the output format | A "three points" prompt: followed in all 6 runs. A "one line" prompt: ignored (2 to 4 sentences) in 5 of 6. A "two questions" prompt: questions in 4 of 6 runs, statements in 2 |

## Quality, by prompt (agent's reading)

| Prompt | Verdict |
|---|---|
| A: three lines (done / missing / next step) | **Right on the drifted note** (6 of 6 runs said the comparison of the two rates is missing). **Partly wrong on the decent note:** one run said it is unclear whether risk is considered although the note discusses the 5-year rule and the 1.25 times increase; the other said there is no view on future income although the note has a section about the writer's income and child costs. On the thin note it was right once ("fixed-rate downsides are not written") and generic once, and it overstated "summarizes the features of both" |
| B: two sentences plus one missing point | Plausible but generic; one run was incoherent ("a view of conditions, a view of conditions"); one flagged "prepayment fees" as missing although the note said it is unconfirmed |
| C: one line | Ignored the length, wrote several sentences, mislabeled a note as an "article", and in one run gave its own *judgment* about which rate is better, which is the writer's job |
| D: two questions to write about next | Safe: a question cannot be wrong, only redundant. Mostly generic ("which rate suits my situation?"); once grounded in the note (down payment, child costs). Two runs returned statements, so the output must be cleaned to question lines |
| E: on-topic check plus one question | **Unusable:** it answered "on the goal" for the drifted note in one run while giving the reason that no mortgage information is present, and wrote both "on the goal" and "not on the goal" in the same answer twice |

## What this means for decision 0017 (point 5) and L4

- **Do not make the review automatic and always visible.** One run in three of a prompt that sounds like a review states something the note disproves. The model cannot be trusted to say "you did not write X".
- What it does well: (1) tell when a note has drifted from the goal (prompt A, drift note), and (2) offer questions to think about next. Both fit a button the person presses, with a plain label such as 「次に書くとよい問い」, not a "review" or a grade.
- If L4 is built, it should be on request only: ask for two questions, keep only lines that are questions, show them in a quiet card with the AI mark and "may be generic", and never state what is or is not in the note. The optional update after typing stops (decision 0017, point 5) is not recommended on this evidence; a stale or generic question costs little, but the model call on every pause is not free and the benefit is small.
- A real review of a note against its goal belongs to a stronger model, that is, the Claude hand-off (N6): the package would carry the goal and the note and ask for a review.

## Not verified

Real notes and goals (longer, English, messy), more runs per prompt (two each), prompts tuned further, a very short or empty goal, long notes (the notes here are under 300 characters; the budget allows about 1,300), and the PdM's own judgment of usefulness.
