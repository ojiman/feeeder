# Feeeder development

- Use docs/specification.md as the V1 product source of truth and docs/architecture.md for technical choices and the four-axis agent harness. The PRD still requires the user's PdM approval before V1 is accepted.
- Work as one supervised implementation writer. Do not start unattended workers or resume the Keychain probe. A reviewer may inspect a fixed commit when the task calls for it; do not claim read-only isolation from a prompt alone.
- Use synthetic RSS/HTML and temporary databases for tests. Do not read the user's library, credentials, Keychain, browser profile, or unrelated projects. /private/tmp is disposable scratch, not a security boundary.
- Local edits, tests, builds, and commits are allowed. Review concrete URLs, dependencies, migrations, and external writes against the user's current instruction. Authorization already given in the task does not need to be requested again.
- Do not push directly to main. Use a branch and PR when GitHub publication is requested. Do not sign, submit, or publish an app without the user's instruction.
- Before committing, run checks relevant to the change and git diff --check. Report what passed, what was not run, and any unverified macOS UX behavior. V1 starts with a fresh database; prototype data migration and compatibility models are out of scope by the user's decision on 2026-10-05. Preserve data saved by V1 across reopening and subsequent model changes.
