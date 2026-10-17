# 0062 Several writers at once, each on its own issue, under the owner's review

- Status: valid (the ruleset is set; the sandbox of each agent is not verified here)
- Date: 2026-10-18
- Decider: the owner (PdM), in the chat of 2026-10-18. The agent set out the risks and the proposal; the owner agreed and changed the ruleset the same day.
- Replaces: 0002 (one supervised implementation writer at a time)

## Why

Decision 0002 (in Git history only: `git log --all -- docs/decisions/0002-*`) kept the harness simple: one writer, no unattended workers, a reviewer who reads a fixed commit. Since then the work moved into issues, pull requests and labels. Each writer works on its own issue, branch and worktree, and nothing reaches `main` without a pull request, the `check` status and the owner. The owner started to give issues to Codex with the label `codex` (2026-10-17). That is supervised work by two writers, not unattended work, so "one at a time" no longer describes what keeps it safe.

What 0002 protected stays: no unattended workers, and a reviewer reads a fixed commit. What changes is the number of writers.

## Decision

1. **Several writers may work at the same time** (today Claude Code and Codex), each on its own issue, branch and worktree. The label `codex` marks an issue that Codex writes; any other issue is Claude Code's. The owner reviews and merges; a writer does not merge its own pull request.
2. **Two writers never change the same files at once.** No second pull request on files an open one touches. `ReaderView.swift` and the store (`ReaderStore`, retention, the models) are one at a time each (labels `area:reader-view` and `area:store`). `area:no-screen` says only that no screen is touched.
3. **At most three writers' pull requests are open at once.** The owner's review is the limit, not the writers. Lower the number when reviews wait.
4. **Measurements and real-app tests run one at a time on the Mac**, with no other build or test running. A number measured while something else ran is not recorded.
5. **A change to the store, concurrency, external writes, retention or deletion is reviewed on a fixed commit by someone other than its writer** (the other agent, or the owner).
6. **The ruleset `protect-main` requires the branch to be up to date** (`strict_required_status_checks_policy`), besides a pull request and `check`. Two pull requests that are green on their own cannot meet on `main` unchecked: the second one is brought up to date and checked again first. The price is a wait after every merge.
7. **No unattended workers.** Running a writer without a person watching needs an isolated environment and negative tests, and its own decision.

## Not included

No change to what the product does. Not verified here: the sandbox and credentials of Codex; the owner sets them, and a rule in this file does not enforce them. No merge queue; consider one when the wait after a merge becomes a problem. The label `area:store` is made by the owner. A limit of three is a first guess, not a measurement.
