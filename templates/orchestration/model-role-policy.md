# Dual-runtime role and model policy

Status: **user-approved pilot policy; opt-in; copied but never activated by explicit full-opt setup**.

## Invariant

One root owns coordination and final acceptance. There are only three authority
roles: `root`, `peer` (read-only), and `implementer` (write-capable). Model choice
selects a work class; it never promotes claim or workflow authority.

The checked mapping is [`role-model-matrix.tsv`](./role-model-matrix.tsv). Root
chooses zero or more coworkers from independent dependency units, not from a fixed
team chart.

## Work classes

- **control** — root-only task graph, validation leases, synthesis, acceptance,
  release, and teardown.
- **scout** — bounded discovery, exact-file/mechanism inventory, reproduction setup,
  and artifacts. It may point to a high-impact seam but does not settle a difficult
  architecture, security, foundation, or durable-contract claim.
- **challenge** — independent strongest-alternative, architecture, security,
  foundation, or evidence review.
- **mechanical** — well-specified bounded implementation inside an isolated worktree
  or explicit write scope.
- **ambiguous** — difficult or high-coupling implementation that must challenge
  load-bearing assumptions before editing.

For Codex, the approved capability order is explicit:

1. `gpt-5.6-sol` at `xhigh` is root.
2. `gpt-5.6-sol` at `medium` handles `challenge` and `ambiguous` work.
3. `gpt-5.6-luna` at `max` handles `scout` and `mechanical` work.

Do not infer strength from the effort label alone. The matrix binds task class,
model, effort, and access as one envelope; launch failure must not silently fall back
to another row.

## Shared launch properties

Every runtime adapter preserves:

- one root and disabled native subagent control;
- project instruction discovery;
- backend commands only in the root profile;
- explicit model, effort, permission posture, cwd/worktree, work class, task scope,
  artifact target, stop conditions, and acceptance contract;
- fresh sessions until a full-envelope resume attestor exists; and
- root-owned controller/validation locks when the run uses them.

## Honest boundary

The matrix and contract checkers validate declarations and bindings. They do not
prove model availability, effective permissions, independence, reasoning quality, or
correctness. Runtime observation and acceptance remain separate evidence.
