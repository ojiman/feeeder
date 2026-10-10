# 0013 A learning goal and one note per theme

- Status: replaced in part by [0019](0019-v1-simplification-notes.md) (the goal, the theme records, and the theme as a concept; the idea of one plain-text note stays)
- Date: 2026-10-10
- Decider: the owner (PdM). The direction comes from the PdM's idea in the 2026-10-10 dogfooding discussion. The Product Owner (the agent) proposed the screen, the AI budget, and the migration. The PdM chose them.
- Replaces: the questions, lenses, answers, and evidence parts of [decision 0008](0008-theme-centered-notes.md). Parts of [0011](0011-on-device-generation-defaults.md) (question proposals) and [0012](0012-claude-handoff-from-themes.md) (the questions and answers switches) change when the work below lands.

## Background

Themes now hold articles, questions with lenses, answers, evidence, and one "current understanding" text. In use, the person wants to state *what they want to learn* in a theme, and to write one body of thoughts while looking at the articles. Several small places to write (questions, answers, understanding) and AI cards for questions do not give that. The on-device model also needs a clear target to give useful help: "the essence" is only meaningful for a goal.

## Decision

1. **A theme has a name and a learning goal.** The goal is plain text of one or two lines, at most 200 characters. It can be empty. It is shown at the top of the theme.
2. **One note per theme.** The note is one plain-text document. Lines that start with `#` are headings; there is no rich text for now. The note replaces questions, lenses, answers, evidence, and the separate "current understanding" text.
3. **Migration, once, without loss.** When the version that ships the note first opens a library, for each theme the note starts with the old "current understanding" text, then one section per question: the question as a heading, the answer under it, and the evidence articles (title and link) as a list. After the conversion succeeds, the old question and answer records are deleted. If the conversion fails, nothing is deleted and the app says so. Compatibility between beta versions is still not promised (decision 0003), but this change must not lose what the person wrote.
4. **Screen (option B).** The face switch of a theme becomes [記事｜ノート] (Articles | Note). On the note face the sidebar folds away, using the standard split-view behavior (it follows Reduce Motion). The middle column is the note. The right column is the reader. The reader's top bar has previous and next article, a menu of the theme's articles, and a switch [原文｜AI要約] (Original | AI summary). A Reeder-style fade of the sidebar is a later option, not part of the first version.
5. **On-device AI helps by "actions", not by chat.** Below the note there are one-step actions, for example: what is missing for the goal, an opposing view, make this section clearer, the essence in three lines. Each action is one request that returns a card. The person adopts a card by choice; only then does text enter the note (at the cursor or in place of the selection). Nothing is written to the note automatically (decision 0009). The AI summary of one article is also one request. The existing suggestions (nearby themes, groups, theme names) stay. The lens question cards of PR 7 are removed together with questions.
6. **AI input budget.** The model's context is 4,096 tokens in total, measured on macOS 27.0.1 (Japanese is about 0.74 tokens per character). One request uses at most: instructions 300, goal 100, note 1,000, article points 1,000, output 700. The note part is the section at the cursor or the selection, not the whole note. Article points come from the saved RSS summaries and from retained text only; expired text is never used. An AI summary or an article point is **saved only when the person adopts it into the note**. It is not cached automatically.
7. **Claude hand-off** (decision 0012) sends the goal and the note instead of the questions and answers. The note is the person's own writing, so it is off by default, the same as answers are today. The rest of 0012 stays.
8. **Order of work.** Small PRs, each with its own plan: goal; note with migration; the two-pane layout with the folding sidebar; the AI summary in the reader; the actions; hand-off. The roadmap is in `docs/superpowers/plans/2026-10-10-theme-notes.md`, Part 1c. The PdM's real-device check (stage A) and the reading-size work (PR 9) are not blocked by it.

## Impact

- The specification describes what is built today. Each PR in Part 1c updates the sections it changes (AGENTS.md, Definition of done 6). Until then, the questions-and-answers text in the specification is still the current behavior.
- `ThemeQuestion` and the question screens are removed in the note PR, after the migration. The failure-injection and retention tests move to the note.
- The note editor must handle long text and Japanese input (IME). A note editor that fails with IME is not acceptable.

## Not verified

- The quality of on-device summaries and of the actions on real articles. This is checked by a small experiment on synthetic data before the AI PRs, and by the PdM's real use after.
- The migration on real libraries (it is tested on synthetic stores first).
- Whether the system Writing Tools (macOS) should be used for rewriting instead of our own action. They are not under our control and may not be available on every Mac.
- The look and feel of the two-pane layout and of the folding sidebar.

## Sources

- PdM discussion on 2026-10-10 (goal, note, two-pane reading while writing, AI by iteration); the Product Owner's replies.
- Context size and token cost measured with `SystemLanguageModel.default.contextSize` and `tokenCount(for:)` on macOS 27.0.1.
- [Decision 0008](0008-theme-centered-notes.md), [0009](0009-on-device-ai-principles.md), [0012](0012-claude-handoff-from-themes.md); the on-device AI spike record.
