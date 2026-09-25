# Handback and continuation reconciliation

## Failure modes

A recovery action can resolve as `handed_back` before its restored-owner run
starts. If that run succeeds without advancing the source issue out of `todo`,
the timestamp-only handback check used to exclude it from reconciliation.

A generated continuation summary can also carry the default review instruction
from `in_review` into `in_progress`. Queued continuations used to interpret that
stale sentence as a fresh reason to cancel executor work.

## Behavior

- The existing stranded-issue reconciler accepts a restored run's exact
  `recoveryActionId`, scoped to the company, source issue, resolved handback,
  current assignee and return owner. The original lost-wake timestamp path stays
  supported. An unrelated old handback does not make arbitrary successful todo
  runs eligible.
- The existing assignment recovery receives one retry. A retry that succeeds but
  still leaves an unmonitored, stranded `todo` escalates through the existing
  recovery-action path instead of being silently skipped or retried forever.
  Existing active-run, queued-wake, pause, budget and durable-wait guards remain.
- Summary refresh drops only the exact generated review default after return to
  `todo` or `in_progress`. Specific human/operator instructions are retained.
- At continuation claim, current pending interactions, pending/revision-requested
  approvals and pending execution stages still park the executor, including when
  the summary says to resume. Without a durable gate, the generated review
  default alone no longer cancels an `in_progress` continuation.
- No new scheduler, monitor recurrence, capacity policy, API contract, schema or
  migration is introduced. Monitors remain one-shot and must be re-armed by their
  owner when the awaited condition persists.

## Verification

Run from the repository root:

```sh
pnpm exec vitest run \
  server/src/__tests__/heartbeat-process-recovery.test.ts \
  server/src/__tests__/issue-continuation-summary.test.ts \
  server/src/__tests__/issue-monitor-scheduler.test.ts \
  server/src/__tests__/issue-recovery-actions.test.ts \
  server/src/__tests__/run-continuations.test.ts --maxWorkers=1
pnpm --filter @paperclipai/server typecheck
```

Observed: **185 tests passed across five files**, with no skipped tests, and
server typecheck passed. RED was observed separately for the pre-followup
handback, successful unchanged-todo recovery, inherited generated summary,
queued stale-summary cancellation, and durable approval with runnable summary.

The test host's `/tmp` socket quota prevented embedded Postgres from starting.
For these runs only, the embedded test helper received
`postgresFlags: ["-k", os.tmpdir()]` alongside its `initdbFlags`, directing sockets
to the configured scratch `TMPDIR`. That local test-only edit was reverted and
is not part of this patch. Test databases were disposable; no live DB was used.
Full repository tests and release build were not run because host storage was
below the operator's free-space gate. Server typecheck invokes its normal
runner/plugin dependency preparation.

## Deployment boundary

This patch is based on `35fca95626a04f5a7ec42cf95989c3d779a1687e`, not the separate
`fix/durable-liveness-recovery-budget` worktree. It does not include that branch's
heartbeat schema migration or broader liveness changes.

Do not overlay source files into a published npm install. Review/cherry-pick onto
the exact intended release source, reconcile any heartbeat/recovery conflicts,
run release verification and compare the complete release migration set before
activation. This patch itself needs no migration, but upgrading the surrounding
application may. Runtime compatibility with the installed `2026.824.1` bundle
has not been proven. No service restart, deployment, live issue wake, or live
migration was performed.
