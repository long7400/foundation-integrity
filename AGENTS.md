# Foundation Integrity — repository guide

This repository ships a small, dual-runtime foundation gate for Claude Code and
Codex. Its job is to stop a locally correct feature from hardening a weak owner,
source of truth, lifecycle, trust boundary, or system archetype.

## Always-loaded kernel

- Preserve explicit user outcomes and required mechanisms. Do not silently replace a
  requested mechanism with an adjacent one.
- Before designing or implementing a non-trivial feature, module, mechanism,
  migration, refactor, or security/reliability/performance change, read
  `skills/foundation-audit/SKILL.md` and run a proportional foundation audit. Skip
  only work that is clearly mechanical or local, and state why.
- Falsification comes first: try to break the load-bearing claims before making the
  feature fit. Inspect ownership, source of truth, lifecycle, trust boundaries,
  dependency direction, invariants, intended versus observed behavior, and the
  simpler established archetype where that comparison is material.
- Treat code, tests, docs, ADRs, issues, and runtime behavior as evidence, not
  automatic truth. Unknown load-bearing facts are research blockers.
- Record exactly one classification (`FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or
  `FOUNDATION_BLOCKED`), one outcome (`PROCEED`, `RESEARCH_ONLY`, or `NO_GO`), and
  one route (Foundation-first, Bounded compatibility, or Feature-first). Only
  `PROCEED` permits dependent implementation.
- Stop before feature work if the path would create a second authority, bypass an
  owner or trust boundary, require repeated exceptions, or freeze a known mismatch
  into an API, schema, migration, or durable data. Foundation repair is a successful
  outcome.
- Acceptance must exercise the architectural property at risk, not only feature
  correctness. Prefer proof that can expose the cheapest fake pass and survives
  harmless internal refactors.
- When a foundation surface changes, a mismatch signal appears, or a fitness check
  regresses, use a fresh independent session to apply
  `skills/adversarial-foundation-review/SKILL.md`. The implementer cannot approve its
  own durable work.
- Keep reports decision-lossless but concise. Preserve decisive evidence,
  counterevidence, unknowns, route, reversibility, compatibility lifecycle, and
  downstream implications; do not request hidden chain-of-thought.

Detailed receipt fields, examples, pattern probes, and proof-selection guidance stay
in explicit skills and project documents; do not duplicate them into always-loaded
instructions.

## Repository invariants

- `skills/` is the canonical authoring and plugin source. `.claude/skills/` and
  `.agents/skills/` are generated standalone projections. Regenerate both with
  `sh scripts/sync-runtime-skills.sh` after any canonical skill change.
- The default distribution contains exactly 24 skills: three standalone first-party
  skills and the 21-skill commit-pinned companion. The companion requires its
  license, allowlist, upstream hashes, patch ledger, and removal test; it is never a
  source of foundation-gate or coworker authority.
- Stored payload is not a context metric. Runtime discovery metadata may be
  always-on, while full skill bodies load on invocation and ordinary docs/templates
  remain inert until read or adopted. Optimize measured active surfaces; never
  delete distribution files merely because they exist on disk.
- Skill bodies remain runtime- and stack-neutral. Concrete stack adapters belong in
  `templates/fitness/adapters/` or `templates/hooks/`.
- Reasoning claims require a measurement surface where one is possible. Hooks and
  fitness checks are supporting evidence, not proof that the design is correct.
- Runtime hooks stay proportional and dual-wired; git enforcement remains
  runtime-neutral. Default runtime posture is warn, while the explicit pre-push tier
  may block.
- `templates/` is distribution-authoring input, not a downstream layout. The adopter
  maps selected assets to `docs/`, `.foundation-integrity/hooks/`, or
  `.orchestration/foundation/` and never copies a top-level `templates/` directory.
- Runtime/process state under `.foundation/` and `tmp/` is never canonical. Local ADR
  history is ignored by default; promote only accepted decision-lossless evidence to
  an explicitly tracked owner when the project needs one.
- `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, the marketplace,
  canonical skills, and both projections must stay in sync.
- The pack obeys its own doctrine: one source of truth, explicit lifecycle, no
  unverified claim shipped as fact.

## External coworker mode — load only when requested

Do not load or apply the orchestration material for an ordinary single-session task.
When the user explicitly requests independent external coworkers and `HERDR_ENV=1`,
read `templates/orchestration/model-role-policy.md`,
`templates/orchestration/coworker-protocol.md`, and only the adapter for the active
runtime.

The always-valid boundary is small:

- exactly one root owns task state, validation leases, acceptance, release, and
  teardown;
- do not mix native subagents/background agents with external coworkers;
- transport status and session identity are attention/continuity signals, never task
  authority or acceptance evidence; and
- workers receive an open task and safety scope, not backend commands or topology,
  and cannot self-approve durable work.

## Evidence and task order

- Prefer stable primary evidence: exact diffs, commits, decision records, contract
  runs, and runtime observations. Summaries and release notes are indexes.
- Order work by containment, dependency unlocks, foundation leverage, durable shape,
  absorption/supersession, risk, and reversibility. Do not create process ceremony
  for trivial work.
- Reconcile after material evidence changes. If one change fully covers another's
  acceptance criteria, mark the latter absorbed or superseded instead of doing both.
- Run overlapping writes sequentially. Independent work may use external top-level
  sessions only through the single root control plane.

## Repository pointers

- Foundation convention: `docs/agents/foundation.md`
- Domain/evidence layout: `docs/agents/domain.md`
- Issue tracker: `docs/agents/issue-tracker.md`
- Triage labels: `docs/agents/triage-labels.md`
- ADR template: `docs/adr/0000-template.md`
- Transparent project adopter: `templates/setup/full-opt.sh`
- Repository contracts: `tests/repo-contracts.sh`
