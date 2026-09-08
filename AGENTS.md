# RSS Reader development

- Follow `docs/specification.md`. The user approved implementation on 2026-09-06.
- The user adopted `docs/proposed-reader-first.md`: the coordinator may now implement and locally commit the offline reader in this interactive session before full harness acceptance. Autonomous workers remain gated. Do not resume the disabled Keychain experiment.
- Start with harness preparation. Do not run autonomous application workers until the preflight requirements in §4.5 are accepted. Coordinator may prepare and test the harness using only fake data.
- This file describes behavior; it does not enforce isolation. Project-local policy proposals are not automatically authoritative.
- Work offline with synthetic fixtures. Do not read personal data, credentials, login profiles, Keychain secrets, or other projects.
- User update on 2026-09-06: use shared `/private/tmp` (`/tmp`) for disposable, nonsecret build/test files. It is not a role-isolation boundary. Source, policy, acceptance baselines, trusted evidence, and credentials must live outside it. Do not inspect or delete unrelated temporary files.
- Use local commits for now. GitHub push and CI setup are deferred until the app works locally.
- Do not push, publish, sign, add dependencies, fetch article fixtures, or call a paid API on behalf of a worker. See §4.1 for the user-executed steps.
- Implementation has one writer. Verification uses a frozen source copy, separate output, and the same enforced runtime boundaries. A prompt asking for read-only behavior is insufficient.
- Include task ID, input hash, acceptance IDs, allowed paths, references, permissions, and stop conditions in worker briefs. Do not pass the full conversation or personal memory.
- Never replace missing evidence with PASS. Keep partial probe results distinct from complete F/H acceptance.
- Use tests first for behavior changes. Preserve failed test evidence; do not weaken the acceptance oracle to pass.
- Do not change effective policies or the adopted acceptance baseline. Propose changes for user adoption.
