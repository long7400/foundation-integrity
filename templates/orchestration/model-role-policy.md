# Dual-runtime role and model policy

Status: **user-approved pilot policy; opt-in; not installed by setup**.

## Invariant

One root/lead owns coordination and final acceptance. Model selection changes the expected work shape and evidence burden; it never transfers workflow or claim authority.

The machine-readable mapping is [`role-model-matrix.tsv`](./role-model-matrix.tsv). The root chooses how many coworkers to launch from the dependency graph and may launch none. Do not fill a predetermined team chart.

## Selection rules

- **root-lead** — always the strongest designated root model/effort for its runtime. Owns task graph, open delegation, validation leases, synthesis, acceptance, and teardown.
- **worker-medium** — bounded read-only scouting, exact-file/mechanism discovery, reproduction setup, and artifact production. It may point to high-impact seams but cannot settle difficult architectural, security, or durable-contract claims.
- **implementer-medium** — mechanical or well-specified implementation in an isolated worktree or explicit write scope. It cannot change acceptance criteria or approve itself.
- **peer-max** — independent strongest-alternative, foundation, architecture, security, or evidence challenge. Read-only by default.
- **implementer-max** — ambiguous or high-coupling implementation that benefits from a stronger independent session. Still bounded by write scope and independent review.

If the task does not fit one of these shapes, root writes a new task packet; it does not silently reinterpret a role. More capability is not a substitute for missing foundation evidence.

## Shared launch properties

Every runtime adapter must preserve:

- one root and disabled native subagent control;
- project instruction discovery (`AGENTS.md` or `CLAUDE.md`);
- role-specific instruction overlay without worker access to backend commands/topology;
- explicit model, effort, permission/read-write posture, cwd/worktree, and task scope;
- open hypothesis, primary-evidence requirements, artifact target, stop conditions, and acceptance-contract version;
- fresh-session-only pilot policy for every accepted role; resume/continue/fork is rejected until a full-envelope attestor and controlled smoke exist;
- root-owned controller/validation lock plus SHA-256-bound current-state, worker-output, transcript, and benchmark artifacts.

## Honest boundary

The matrix and run-contract checkers prove only that checked-in mappings and declared actor/profile bindings match the approved policy. They cannot prove availability, effective runtime selection, permission enforcement, prompt independence, or output quality. Each run receipt binds the contract and matrix hashes and records the observed launch envelope; the root rejects work when it cannot reproduce that envelope.
