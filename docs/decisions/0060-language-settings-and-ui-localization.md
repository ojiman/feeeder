# 0060 Language settings and UI localization

- Status: valid (approved by the owner; not built, #154)
- Date: 2026-10-17
- Decider: the owner (PdM), in the chat about #154.
- Replaces in part: [0005](0005-v1-product-decisions-2026-10-04.md), point 1's exclusion of an in-app display-language setting. Time zones are unchanged.
- Revises: the target-language choice in the [translation design](../superpowers/plans/2026-10-12-translation-design.md); [0054](0054-translation-on-the-mac-not-stored.md)'s on-device and storage rules stand.

## Decision

The owner approved display-language and article-translation settings for V1, with separate system-derived defaults and remembered manual choices. The article keeps a single translate/original action, with no language menu. Current behavior and the initial seven UI languages are defined in specification 3.6 and 3.7; they remain marked not built under #154.

UI translations are prepared with AI using [Axiom's localization guidance](https://github.com/CharlesWiltgen/Axiom/blob/main/axiom-codex/skills/axiom-integration/skills/localization.md) to check terminology, context and locale rules. This is development guidance, not a runtime app dependency or a guarantee of translation quality. The owner reviews English and Japanese; no human-review claim is made for the other languages. Errors found after release are corrected as they are identified.

## Why

A remembered target in Settings keeps reading to one press. Separate choices let a person use the app in English and translate articles into Japanese. Matching the Mac's preferred languages makes first use useful without a setup step; a same-language press explains why no translation is needed instead of leaving an unexplained disabled control.

The initial UI languages widen access while limiting the first translation and layout checks. Right-to-left UI languages can be considered later, with their layout work.

## Not included

No new translation engine, runtime AI service, automatic article translation, original-page translation or claim of reviewed quality in all languages. Axiom has not been installed or verified in this project by this documentation change. Product acceptance and release permission are unchanged.
