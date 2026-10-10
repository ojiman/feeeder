# On-device AI: what we measured

What the on-device model (`SystemLanguageModel.default`, Apple Silicon, macOS 27.0.1, Swift 6.4, 2026-10-10 and 2026-10-11) can and cannot do. Synthetic Japanese input only; the agent read the outputs, not the PdM. The experiment scripts and the long records are in Git history (the records `on-device-ai-spike`, `note-ai-experiment`, `goal-review-experiment`, `ai-summary` under `docs/verification/`, before the prune PR).

## Facts to build on

| Topic | Result |
|---|---|
| Availability and language | Available, Japanese included. The context window is 4,096 tokens for input and output together. |
| Size | About 0.66 to 0.74 tokens per Japanese character. A 4,800-character body (3,146 input tokens) still returned a summary. Cut a long body to its start instead of chaining requests. |
| Time | A summary takes 1 to 6 seconds, growing with the body (1,200 characters about 3 s, 4,800 characters about 6 s). |
| Plain text output | An instruction with `maximumResponseTokens` and plain text gave clean results. A `@Generable` string field often appended stray text, and `@Guide(.pattern(...))` failed (unsupported). |
| Guardrails | A topic such as sleep was refused as "may contain sensitive content" in some runs. A refusal must be handled as "no summary", never as an error that blocks reading. |
| Embeddings | Japanese sentence and word embeddings are not available. `NLContextualEmbedding` works only after the mean vector is subtracted. Not used in V1. |

## Quality

- **Summary of one article (3 sentences): usable as a draft.** About four in five were accurate; one overstated a hedged claim. So the text must be labelled as AI and the original must be one click away. (Product rule: the note marks it 「（AI要約）」.)
- **Rewrite of a section: good, but** a run garbled a clause and another changed the meaning slightly. (The note actions were removed in decision 0019.)
- **Review of a note against a goal: not reliable.** It said "missing" for things the note says, and contradicted itself. A real review belongs to a stronger model, that is, the Claude hand-off. (The goal was removed in decision 0019.)
- Outputs change from run to run; the format instructions were followed only partly ("one line" was ignored in 5 of 6 runs), so clean the output.

## Still not verified

The summary on a real library, on real articles, on a real Mac window, and the quality of Japanese summaries that the PdM reads.
