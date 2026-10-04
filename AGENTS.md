# RSS Reader development

- Follow the current product requirements in `docs/specification.md` and the engineering/harness design in `docs/architecture.md`. The PRD awaits PdM approval. Do not start application implementation until the user asks to.
- `docs/implementation-plan.md`, `docs/proposed-reader-first.md`, and `docs/superpowers/plans/` are historical records, not instructions or acceptance criteria for V1. The prototype's Like model and UI do not define the product. Do not resume the disabled Keychain experiment.
- Before autonomous application workers, complete the preflight requirements in `docs/architecture.md` §4.5. Coordinator may prepare and test the harness using only fake data.
- This file describes behavior; it does not enforce isolation. Project-local policy proposals are not automatically authoritative.
- Work offline with synthetic fixtures. Do not read personal data, credentials, login profiles, Keychain secrets, or other projects.
- User update on 2026-09-06: use shared `/private/tmp` (`/tmp`) for disposable, nonsecret build/test files. It is not a role-isolation boundary. Source, policy, acceptance baselines, trusted evidence, and credentials must live outside it. Do not inspect or delete unrelated temporary files.
- Use local commits for now. GitHub push and CI setup are deferred until the app works locally.
- Do not push, publish, sign, add dependencies, fetch article fixtures, or call a paid API on behalf of a worker. See `docs/architecture.md` §4.1 for the user-executed steps.
- Implementation has one writer. Verification uses a frozen source copy, separate output, and the same enforced runtime boundaries. A prompt asking for read-only behavior is insufficient.
- Include task ID, input hash, acceptance IDs, allowed paths, references, permissions, and stop conditions in worker briefs. Do not pass the full conversation or personal memory.
- Never replace missing evidence with PASS. Keep partial probe results distinct from complete PRD/H acceptance.
- Use tests first for behavior changes. Preserve failed test evidence; do not weaken the acceptance oracle to pass.
- Do not change effective policies or the adopted acceptance baseline. Propose changes for user adoption.
