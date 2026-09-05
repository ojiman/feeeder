# Native preflight experiment

This is harness preparation, **not an approved worker launcher**. It does not launch an LLM, read credentials, modify the user's Codex config, connect to the network, or access a real Keychain item. No third-party dependencies.

The coordinator runs Python 3.11+ and Apple's clang. It creates synthetic source, output, protected canaries, an empty `CODEX_HOME`, and a compiled C probe. The trusted parent launches `codex sandbox -P probe` with an allowlisted environment. The child process reads/writes only the specified synthetic files and emits outcomes/errno, never contents. The unconstrained positive control intentionally modifies only its synthetic canary; the coordinator resets that canary before each role.

Run preparation tests from the repository root:

```sh
python3 -m unittest discover -s harness -v
```

Run the two native placement cases from a normal macOS terminal. Each output path must be new:

```sh
python3 harness/preflight.py --output .harness-runs/workspace-recheck
python3 harness/preflight.py --output .harness-runs/temp-recheck --temporary-location
```

The current desktop sandbox cannot itself apply another Seatbelt profile (`sandbox_apply: Operation not permitted`). Native probes must be launched by the user or with explicit command approval. Do not disable the worker sandbox to resolve this.

Read `report.json`, the generated role TOML, and each role's stdout/stderr. Exit 0 means only that this limited experiment matched its expected observations. Full H acceptance remains NOT_RUN. A positive control failure invalidates the negative result. Temporary working directories are deliberately retained for inspection; paths appear in the report. No cleanup of unrelated temp files occurs.

Confirmed on Codex 0.149.1: the workspace-location case passed, but the `/private/tmp` case allowed protected read/write and verifier source writes even with explicit denies. **Do not adopt these generated profiles as sufficient isolation.** See `docs/harness-initial-results.md`.

Still required before autonomous app workers: resolve this file boundary, verify actual worker tool inventory and effective policy, controlled network receivers, Keychain CLI/framework canaries, rule evaluation, immutable oracle adoption, approval matching, adversarial worker tests and independent role reviews. These probes do not stand in for those tests. No live API credential is needed to resolve the current issue.
