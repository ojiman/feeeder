# Native preflight experiment

This is harness preparation, **not an approved worker launcher**. It does not launch an LLM, read credentials, modify the user's Codex config, connect to the network, or access a real Keychain item. No third-party dependencies.

The coordinator runs Python 3.11+ and Apple's clang. It creates synthetic source, output, protected canaries, an empty `CODEX_HOME`, and a compiled C probe. The trusted parent launches `codex sandbox -P probe` with an allowlisted environment. The child process reads/writes only the specified synthetic files and emits outcomes/errno, never contents. The unconstrained positive control intentionally modifies only its synthetic canary; the coordinator resets that canary before each role.

Run preparation tests from the repository root:

```sh
python3 -m unittest discover -s harness -v
```

Run the native probe from a normal macOS terminal. The output path must be new and outside shared `/private/tmp`:

```sh
python3 harness/preflight.py --output .harness-runs/shared-temp-recheck
```

The current desktop sandbox cannot itself apply another Seatbelt profile (`sandbox_apply: Operation not permitted`). Native probes must be launched by the user or with explicit command approval. Do not disable the worker sandbox to resolve this.

Read `report.json`, the generated role TOML, and each role's stdout/stderr. Exit 0 means only that this limited experiment matched its expected observations. Full H acceptance remains NOT_RUN. A positive control failure invalidates the negative result. Temporary working directories are deliberately retained for inspection; paths appear in the report. No cleanup of unrelated temp files occurs.

User-approved revision on 2026-09-06: `/private/tmp` is a shared writable disposable area, not a role boundary. The probe checks temporary read/write/delete while continuing to require denial of protected reads and verifier source writes outside that area. Placing protected role roots or evidence output beneath `/private/tmp` (including `/tmp` aliases) is rejected. Credentials, authoritative policy and evidence must never be placed there. The runtime may access the shared area, but unrelated files remain outside the task scope.

The revised native experiment passed on Codex 0.149.1 for control, writer and verifier including their child processes. This resolves the previous temporary-area blocker, not the remaining H tests. See `docs/harness-initial-results.md`. Original placement failures remain in `docs/evidence`; reproduce the original code with commit `e95919b` in a separate checkout, not by treating them as current failures.

Still required before autonomous app workers: verify actual worker tool inventory and effective policy, controlled network receivers, Keychain CLI/framework canaries, rule evaluation, immutable oracle adoption, approval matching, adversarial worker tests and independent role reviews. These probes do not stand in for those tests. No live API credential is needed for these preflight checks.
