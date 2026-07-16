# Foundation Integrity project guide

This project has adopted the Foundation Integrity gate. The gate protects
ownership, source of truth, lifecycle, trust boundaries, and the simplest valid
system shape before a locally-correct change hardens the wrong foundation.

## Before non-trivial work

- Read the installed `foundation-audit` skill and try to falsify the load-bearing
  claims before design or implementation.
- Record exactly one classification, one outcome, and one route. Unknown
  load-bearing facts are research blockers, not assumptions.
- Acceptance must prove the architectural property at risk, not only feature
  behavior.
- When a foundation surface changes, obtain an independent
  `adversarial-foundation-review` before durable work is accepted.

## Installed ownership

- The project's existing `AGENTS.md` or `CLAUDE.md` remains authoritative. This
  file is created only when `AGENTS.md` is absent; any existing instruction file is
  left byte-for-byte untouched, and later edits belong to the project owner.
- Selected runtime projections live under `.agents/skills/` (Codex) and/or
  `.claude/skills/` (Claude).
- Runtime hook scripts live under `.codex/hooks/scripts/` for Codex and
  `.claude/hooks/scripts/` for Claude. Git hooks resolve the selected runtime
  scripts and remain runtime-neutral.
- Optional orchestration policy is inert under `.orchestration/foundation/`.
  Runtime state belongs under `.foundation/` and is never a decision authority.

Keep durable decisions and accepted evidence in an explicitly tracked project
owner such as `docs/adr/` or `docs/foundation/receipts/`; do not treat ignored
runtime state or transport status as acceptance evidence.
