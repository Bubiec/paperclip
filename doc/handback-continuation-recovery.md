# Release-compatible handback and continuation recovery

## Scope

Backport of reviewed commit `d6e3251c17544218e4e194822e59dd18d355923a`
onto the source of npm `2026.824.1`:
`8e6edcdfa911151adba26be49a41cf5017b3aade`.

Only three production files change: heartbeat claim validation, continuation
summary generation, and the existing recovery service. No schema, migration,
package manifest, lockfile, scheduler, capacity policy or worker instruction changes.

- Accept the restored run's exact `recoveryActionId`, scoped to company, source
  issue, resolved handback, current assignee and return owner. Keep the original
  lost-wake timestamp path; reject unrelated old handbacks.
- Spend the existing one-retry assignment-recovery budget even when the adapter
  exits successfully but leaves a stranded `todo`; escalate rather than loop.
- Drop the exact generated review default only with its review-state header
  (`Status: in_review`, `Current mode: review`, and nonempty `Last updated by run`)
  and a sole default Next Action. Matching text alone is an explicit wait.
  Preserve specific operator instructions and ambiguous legacy summaries, including
  ones already rewritten with `Status: in_progress`; those require explicit resolution.
- At continuation claim, pending interactions, pending/revision-requested approvals
  and pending execution stages remain gates even when the summary says to resume.

This release's escalation can enqueue a source-scoped status-only wake to the same
owner. The backported test accounts for that existing behavior and asserts exactly
one assignment-recovery run plus one status-only escalation with deliverable work
disabled. No newer upstream escalation policy was imported.

## Source identity evidence

The npm registry metadata for `paperclipai`, `@paperclipai/server` and
`@paperclipai/db` has no `gitHead`. Their provenance statements link to:

- [Release run 32894745137](https://github.com/paperclipai/paperclip/actions/runs/32894745137)
- [Publish job 97957210527](https://github.com/paperclipai/paperclip/actions/runs/32894745137/job/97957210527)
- [Release tag](https://github.com/paperclipai/paperclip/tree/v2026.824.1)

The provenance `gitCommit` is `d9f759b7bc967b3837158c5eb7b9d712ddec4da0`:
that is the workflow-dispatch revision, **not the published source checkout**.
The workflow resolves `source_ref` then checks out that immutable SHA. The publish
log explicitly records checkout and `Source commit:` as
`8e6edcdfa911151adba26be49a41cf5017b3aade`; the tag and release candidate branch
resolve to the same SHA. The log records target version `2026.824.1`.

Read-only installed-payload verification:

- Registry tarball integrity and provenance subject SHA-512 agree with the
  installed lockfile for all three packages. This compares the published records;
  it is not a fresh Sigstore signature-verification claim.
- All 306 migration-directory files match the source byte-for-byte, including
  all 221 SQL files and journal/snapshots; no extra installed files in that tree.
- All 116 schema TypeScript files, emitted as ES2023/ESNext with the existing
  compiler, match the installed schema JavaScript (excluding source-map URL line).
- The unpatched source of all three production files, emitted the same way,
  matches the installed JavaScript (excluding source-map URL line).

The surrounding newer master tree is deliberately excluded. Source package
version `0.3.1` alone is not an identity proof.

## Verification

RED: the two inherited-summary tests failed before the summary fix. With corrected
backport hunk placement, four integration regressions failed before the heartbeat
and recovery changes: pre-followup handback, stale queued review instruction,
runnable summary with a pending approval, and successful unchanged-todo retry.

GREEN: **173 passed, zero failed, zero skipped across five files**:

- heartbeat-process-recovery: 110
- issue-continuation-summary: 7
- issue-monitor-scheduler: 7
- issue-recovery-actions: 44
- run-continuations: 5

No install was run. Existing Vitest 4.1.10 dependencies were reused with explicit
aliases to this release worktree's workspace sources, not newer workspace sources.
Local-only test harness accommodations (not committed): remove a dangling
`droid-local` tsconfig reference for Vite 8; direct disposable Postgres Unix sockets
to scratch `TMPDIR`; keep Vite cache outside node_modules. Both tracked temporary
edits were reverted. Final green run used a scratch `PAPERCLIP_HOME`.
Full release build, full repository tests and release typecheck remain unrun due
to the host's below-20-GiB storage gate. This is a tested source backport, not an
approved deployment artifact.

## Build and rollback route (not executed)

After capacity admission, perform release verification in a clean, disposable
checkout of the exact backport SHA, with Node 24 and Corepack/pnpm 9.15.4. Do not
build from the test worktree's reused dependency links. The release CLI's existing
managed Git installer is the packaging route:

```sh
paperclipai install --repo Bubiec/paperclip --ref <FULL_BACKPORT_SHA> --yes
```

This command is **not staging-only**: it builds and smoke-checks the payload, then
atomically switches `current` and records the previous install. Do not run it on
production before the artifact/migration gates and maintenance authorization.
For an isolated build, use a disposable HOME/PAPERCLIP_HOME/shim path first.

The installer implementation in `cli/src/commands/install.ts` pins the downloaded
source archive to SHA, runs `corepack pnpm install --frozen-lockfile`,
`bash scripts/build-npm.sh --skip-checks --skip-typecheck`, then
`corepack pnpm -r --filter @paperclipai/server... --if-present run build`, packs the
release-manifest dependency closure, installs the local tarballs into a staged
payload and smoke-checks the CLI. Its skipped checks must be run separately:
`pnpm -r typecheck`, `pnpm test:run`, `pnpm build`, plus applicable release smoke.
Validate the final packaged migration tree against the retained npm payload again
before any activation. Source equivalence does not waive artifact verification.

Retain `/home/bubala/.paperclip/cli/installs/npm/2026.824.1` and its install manifest.
Once deployment is separately authorized, the deterministic payload rollback is:

```sh
paperclipai install --version 2026.824.1 --yes
```

The installer reuses/smoke-checks the retained payload and switches the managed
pointer and manifest back. Service restart is a separate controlled operation;
no service restart is performed by the install command itself. This rollback is
schema-compatible only if artifact verification confirms no migration drift.
It does not undo issue-state changes or work performed after activation. Preserve
a fresh backup and drain active work under the operator's deployment procedure.
Never apply newer upstream migrations to make this backport run.
