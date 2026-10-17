# 0060 Language settings and UI localization

- Status: valid (approved by the owner; built; product acceptance is separate)
- Date: 2026-10-17
- Decider: the owner (PdM), in the chat about #154. The owner left the open points of the review of PR #269 (the target change while a translation is shown, when the display language applies, how languages are matched, Match System, how the work is split, disclosure) to the agent, to be decided by the vision; they are confirmed when that PR is merged.
- Replaces in part: [0005](0005-v1-product-decisions-2026-10-04.md), point 1's exclusion of an in-app display-language setting. Time zones are unchanged.
- Revises: the target-language choice in the [translation design](https://github.com/ojiman/unagi-reader/blob/78b5dc5cbfb625bcbc89f54409da3ff3056e0bca/docs/superpowers/plans/2026-10-12-translation-design.md); [0054](0054-translation-on-the-mac-not-stored.md)'s on-device and storage rules stand.

## Decision

1. **The article translation target is a setting.** The article keeps one translate/original action, with no language menu. The target follows the Mac's preferred languages until the person chooses one.
2. **The app's own text can be shown in seven languages**, chosen in Settings and following the Mac until the person chooses. The display language is the same value as the app's language in System Settings and applies at the next launch, as it does for any Mac app.
3. **The two choices are independent.** A person can use the app in English and translate articles into Japanese.
4. **UI translations are prepared with AI**, using [Axiom's localization guidance](https://github.com/CharlesWiltgen/Axiom/blob/b0b4b03f5dedaede00132095a5dd0f333c2bb1ff/axiom-codex/skills/axiom-integration/skills/localization.md) (read at that commit) to check terminology, context and locale rules. It is development guidance, not an app dependency or a guarantee of quality. The owner reviews English and Japanese. The user guide says that the other five were prepared with AI and not reviewed by a person; errors are corrected as they are reported.
5. **The work is three issues**: the target in Settings (#154), the English source with Japanese and the display-language setting (#271), the five other languages (#272).

What the person sees is in specification 3.6 and 3.7.

## Why

A remembered target keeps reading to one press, and the button is where the action is used (vision, question 1). The target is chosen rarely, like the text size, so it sits in Settings with it, not on the button.

**The cost of the default, accepted.** The target follows the Mac's preferred languages. A person whose Mac is in English and who reads English feeds, the person of the vision, gets English as the first target: the first press on an English article says 「すでに英語です」, and they choose their language in Settings once. The earlier design (2026-10-12) chose the app's language as the target for this reason. It is replaced because the app's language is now a choice too, and a target derived from it would change when the person changes the display language. A one-time choice that never changes by itself is less to manage than a value that moves with another setting (question 2). The same-language sentence names the target, so the person sees what to change.

**The vision's four questions.**

| Question | Answer |
|---|---|
| Does it make the loop smoother? | Translation: yes, one press with a fixed target. The display language: not the loop itself; it lets a person who does not read Japanese use the app at all. |
| Does it add something to manage? | Two choices in one pane, both with a default that needs no action; a person who never opens the pane is not asked anything. |
| Can it make the reader wait? | No. Nothing translates without a press, and the display language changes nothing until the next launch. |
| Can text leave the Mac? | No. Article translation stays on the Mac (0054); UI translations are made before release, and the running app has no AI. |

The display language applies at the next launch because that is how macOS changes an app's language, and the app's menus come from the system. Changing it at once would need the app's own text lookup and a rebuilt menu bar, for a choice made once.

The initial UI languages widen access while limiting the first translation and layout checks. Right-to-left languages can be considered later, with their layout work.

## Not included

No new translation engine, runtime AI service, automatic article translation, original-page translation or claim of reviewed quality in all languages. Axiom has not been installed or verified in this project by this documentation change. Product acceptance and release permission are unchanged. #154 and #271 are in the Beta, because some beta participants do not read Japanese (the owner, 2026-10-17); #272 is before 1.0.
