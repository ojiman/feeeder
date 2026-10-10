# Note AI experiment: summaries and actions on synthetic articles

Updated: 2026-10-10 (Japan time). **Result in short:** the on-device model summarizes one article well enough to be a *draft*, but it makes small factual slips, and its "actions" on a note (missing points, opposing view) are weak and mostly repeat the article. Rewriting a section works. Everything fits the 4,096-token window with room to spare. Nothing here is product code.

Environment: Apple Silicon Mac, macOS 27.0.1, Swift 6.4, `SystemLanguageModel.default` (`contextSize` = 4096). Input: five synthetic Japanese articles about interest rates and households (each 208–253 characters, written for this test), one synthetic learning goal, and a synthetic two-section note. No real article, library, or credential was used. The model's output changes from run to run; each action was run twice. Quality notes are the agent's reading, not the PdM's judgement.

## What was measured

| Check | Result |
|---|---|
| Time for one request | 1.1–2.4 s for a short article, 1.6–2.3 s for an action. A 1,200-character article took 3.0 s, 2,400 chars 3.4 s, 3,600 chars 5.4 s, 4,800 chars 5.9 s. |
| Tokens (Japanese) | About 0.66–0.74 tokens per character. A 4,800-character body was 3,146 input tokens and still returned a summary. Larger input was not tried (a 5,000-character article leaves little room for the output). |
| Two steps for a long article (3 chunks of 1,200 characters, then merge) | 10.5 s in total. Slower than one request, and needed only above about 4,800 characters. |
| A note action with the goal, one section, and five article points | 558 input tokens. Far below the budget of decision 0013 (about 2,400 for input). |

## Output quality (agent's reading)

| Request | Verdict |
|---|---|
| Plain summary of one article (3 sentences) | **Usable as a draft.** Accurate on four of five. One overstated a hedged claim: the article said "there is a view that rising rates cool demand and push prices down"; the summary said it "is a factor that lowers prices". |
| Three goal-aware points per article | **Needs care.** One point inverted the meaning: the article said the repayment amount does *not* change for five years; the point said it "changes". The format is short, so a slip is easy to miss. |
| "What is missing for the goal" (3 items) | **Weak.** Items mostly restate the article points ("a base rate rise can raise repayments") instead of naming what the note lacks for the goal (income outlook, contract terms, risk tolerance). |
| "An opposing view" (2 items) | **Weak.** It repeats risks from the articles (the five-year rule) and does not argue against the note's claim. |
| "Make this section clearer" | **Good.** Reads better and keeps the meaning. One run garbled a clause ("whether I am relieved") and one changed "I cannot judge" to "a judgement is needed". The person must check the result. |
| "The essence in three lines" | **Fair.** Three short lines that follow the note; one line softened the note's uncertainty. |

## What this means for decision 0013

- **N4 (article summary): go, as a draft.** Keep the plain 3-sentence summary, label it as AI, link back to the original, and never save it unless adopted. Do not use the 3-point format as a stored digest without a check. For bodies above about 4,000 characters, cut the body (start of the article) rather than chain requests.
- **N5 (actions): narrow it.** "Make this section clearer" and "the essence in three lines" are worth building. "What is missing" and "an opposing view" give weak output from this model; build them only if the PdM wants them anyway, or offer them through the Claude hand-off, where a stronger model reads the note.
- **Budget:** the planned budget (instructions 300, goal 100, note 1,000, article points 1,000, output 700) is safe; real requests used a fraction of it.

## Not verified

Real articles (longer, English, mixed, messy HTML), more runs per prompt (each was run once or twice), different goals, and the PdM's judgement of usefulness. Prompt wording was not tuned. The script was a throwaway and is not kept.
