# 0044 Smaller routine regression fixture

- Status: implementation authorized by the owner; Draft PR review pending
- Date: 2026-10-12
- Decider: the owner asked to shorten the feedback loop and approved a smaller routine fixture with an opt-in large check.

## Decision

`BenchmarkFixtureTests` uses 1,000 articles across 100 feeds by default. Setting the existing `UNAGI_READER_BENCHMARK_DIRECTORY` keeps the original 10,000-article fixture and its formatted bodies. Both modes check article and unread counts, feed filtering, selection retention and stored content. Use a new, empty directory for the large fixture; run it for library/index changes and before release.

Local development reuses its scratch path and can filter the affected suites. The full suite still runs before publication and in code-change CI. CI cache changes, new jobs, historical test removal and the separate test early-exit issue are outside this change.

## Reason and limits

Two recent PR logs spent 74–86 seconds building and reported 39–47 seconds for the large-library case. MainActor contention means those case times do not measure isolated work. A smaller fixture can reduce routine execution work; it does not remove cold-build time or prove 10,000-article behavior in every PR.

The application, schema, dependencies and data policy do not change. The opt-in large check retains the large-data coverage; it is no longer part of every routine run.
