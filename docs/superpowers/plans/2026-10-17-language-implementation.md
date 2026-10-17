# Language Settings Implementation Plan

> Execute inline with superpowers:executing-plans and test-driven-development. One issue per PR; no merge or distribution is included.

**Goal:** Implement #154, then #271, then #272 from the owner-approved specification.
**Architecture:** Keep target matching pure in ReaderCore, persist choices with platform preferences, and reuse the existing translation controller and cancellation generation. Localize through an English-source String Catalog compiled into package resources; use macOS app-language preferences rather than live UI lookup overrides.
**Tech Stack:** Swift 6, SwiftUI/AppKit, Translation, Foundation, Swift Package Manager. No new dependency.
**Spec:** docs/specification.md 3.6, 3.7, PRD-18/20; decision 0060.

## Global Constraints

- Build with the macOS 26.6 SDK-compatible APIs; support macOS 27.0.
- Synthetic data and temporary preferences only; never launch the person's library.
- Keep late-result protection, non-stored translations and one action while reading.
- UI language applies at next launch and shares macOS's per-app setting.
- Keep test result summaries; exit zero alone is insufficient.

## Review Focus

- Locale/script matching and unsupported remembered targets.
- Target changes during both language detection and batch translation.
- SwiftPM resources in both test executables and the signed app bundle.
- System language overrides, fallback, and deterministic UI-test language.
- Placeholder/plural preservation and long translated UI text.

## Task 1: #154 — article target in Settings

Files: ReaderCore/TranslationTarget.swift; app ArticleTranslationView.swift, ReaderSettingsView.swift, ReaderView.swift, ArticleBand.swift; core/UI translation tests; specification, architecture, roadmap, user guide. Delete the completed translation design and repair its incoming links.

Interface: TranslationTarget.resolve(stored:preferred:supported:) returns a supported language/script match for Match System (empty stored value), otherwise the manual identifier unchanged. TranslationController.setTarget(_:supported:) cancels previous work without translating.

- [ ] Write and run failing tests for region/script matching, fallback, manual persistence, shown/in-flight target changes and removed support.
- [ ] Implement the smallest matching helper, target flow and Language pane. Use the system's language list and localized names. Observe preference/locale changes outside ReaderView's long modifier chain.
- [ ] Run checked full Swift tests and repeat changed UI suites; build Release and use synthetic UI checks where available. Remove only #154 marks and roadmap entry; retain #271/#272.
- [ ] Review a fixed commit, push a dedicated branch and create a PR with Fixes #154.

## Task 2: #271 — English source/Japanese UI and app language

Files: Package.swift; app/core localized call sites and catalog resources; app-language Settings; build/test packaging; hosted and real-app UI test language; specification, architecture, roadmap, user guide and README.

Consumes: Language pane from Task 1. Produces: bundled English/Japanese UI, missing-text English fallback, and native per-app AppleLanguages preference selection derived from bundled localizations.

- [ ] Write/run failing tests for preference persistence/reset, bundled language selection, English fallback and catalog placeholder coverage.
- [ ] Apply the pinned Axiom localization guidance from decision 0060. Replace all app-owned Japanese strings with contextual English-source localized resources; preserve user content.
- [ ] Add native next-launch app-language selection and complete Japanese resources; compile/copy resources into the app without a new dependency. Fix label-based tests to a synthetic fixed language.
- [ ] Run checked full tests, script tests, Release build/package round-trip and real-app smoke checks. Remove only #271 marks; owner wording review remains unverified.
- [ ] Review fixed commit, push and open a separate PR with Fixes #271.

## Task 3: #272 — five AI-prepared UI languages

Files: the String Catalog and documents only. Consumes Task 2's resource and language-discovery path; no code changes.

- [ ] Add complete zh-Hans, zh-Hant, ko, es and pt-BR translations, preserving all placeholders and plural rules.
- [ ] Verify completeness and resource compilation, including zh-TW to Traditional Chinese matching. Build the packaged app and inspect available language layouts; list unchecked behavior honestly.
- [ ] Add AI-translation disclosure and error-reporting instructions to README/user guide. Remove #272 marks and this completed implementation plan; update decision status.
- [ ] Review fixed commit, push and open a separate PR with Fixes #272.
