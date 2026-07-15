# Experimental coworker protocol

Status: **opt-in pilot; advisory; not installed by setup**.

This template is for a harness that opens independent, top-level agent sessions. It does not create a new agent hierarchy and does not make a terminal multiplexer the workflow engine. The session backend is replaceable transport; the root session owns the task graph and accepts or rejects evidence.

## Canonical invariant

One root owns global task state and acceptance; transport statuses can attract attention but can never complete, approve, or release work.

The root selects the runtime and role envelope from [`role-model-matrix.tsv`](./role-model-matrix.tsv) according to the task. There is no fixed coworker count and no model tier may bypass the claim-authority rules below.

## What is invariant

1. **One global authority.** Exactly one root owns objective changes, dependency changes, dispatch, acceptance, release, and teardown. A peer may reason independently but does not create or supervise coworkers unless a future, separately specified negotiation contract grants a bounded subgraph.
2. **One control plane per run.** Do not mix harness-managed top-level coworkers with native subagents in the same pilot. This is an experiment-control rule and prevents split authority; it is not a universal claim that one mechanism is always superior.
3. **Transport is attention-only.** `working`, `blocked`, `idle`, `done`, pane text, and terminal labels are observations. Authoritative task state comes from the root's durable record plus worker artifacts and validation evidence.
4. **Direct accountability without false provenance.** A coworker is instructed to answer the decision owner directly and is not burdened with the department topology. It still receives the local contract it needs: task scope, trust boundary, write capability, artifact shape, stop condition, and escalation path. A relayed root message must not be presented as an exact user directive unless it is one.
5. **Open hypothesis, closed safety envelope.** The task packet states the question, foundation claims, allowed scope, permissions, evidence requirements, and stop conditions. It does not include the desired architectural answer or reduce an open design problem to true/false confirmation.
6. **Authority follows claim class, not model tier.** Reproducible mechanical observations may be accepted locally. Hypotheses remain hypotheses. Architectural, security, and durable-contract conclusions require corroboration and independent review. Release decisions stay with the root.
7. **One task, one owner, one write scope.** Read-only research may share a checkout. Any writing task gets an isolated worktree or an explicitly serialized path scope. Overlapping writes are sequential unless an external lock proves ownership.
8. **Events and current state stay separate.** Workers return append-only receipts or events; the root preserves a read-only worker's response at the contract artifact path without presenting it as root-authored evidence. Only the root updates the current task record. Monitoring is a root/harness concern, not a worker role; it may enqueue attention hints but never turns liveness into semantic success.
9. **Canonical validation is leased.** Heavy or flaky evidence execution has one named lock owner at a time. The root grants or revokes the lease. Evidence records revision, cwd, exact command, exit status, and artifact pointer. Workers and reviewers may add counter-tests or request a versioned amendment; they cannot silently lower the acceptance contract.
10. **Session references are continuity pointers only.** Resume only when task, role, repository/worktree, revision, and acceptance contract still match. A session ID is not worker identity, authority, correctness, or completion proof. Use a fresh thread for clean-room challenge; use a fork only when inherited history is intentionally part of the experiment.
11. **Park before teardown.** When transport reports `idle` or `done`, collect the artifact, preserve disagreement, reconcile evidence, and mark accepted/rejected/cancelled before archive or close.
12. **Monitoring remains bounded and root-owned.** Inspect current state before waiting. Treat both `idle` and `done` as possible turn completion, distinguish `blocked`, bound every wait, and fall back to polling when event delivery is unavailable. A root-side monitor/harness may propose policy changes from metrics; it must not become a coworker, rewrite profiles, or change authority automatically.
13. **Runtime adapters preserve one contract.** Codex uses profile overlays; Claude uses explicit CLI launch envelopes. Both disable native subagent control, preserve project instruction discovery, bind a role prompt, and record the effective model/effort/permission envelope. The run contract binds every actor to a checked runtime/profile row, requires a root-owned controller lock, fresh sessions, and content-digested artifacts; adapter syntax may differ, but authority must not.
14. **Ignored state is not durable acceptance.** `.foundation/` may hold live current
    state, worker artifacts, transcripts, and locks. Once the root accepts or rejects
    the run, promote the decision-lossless receipt and stable evidence pointers into
    `docs/foundation/receipts/` or an ADR; never cite ignored runtime state as the only
    canonical decision record.

## Minimal roles

- **root** — global authority, synthesis, evidence-lock grantor, final acceptance.
- **worker** — bounded observations and reproducible artifacts; no high-impact claim promotion.
- **peer** — independent problem-space expansion and strongest-alternative work; no coworker control.
- **implementer** — bounded write scope and acceptance contract; cannot approve its own high-impact change.
- **reviewer** — read-only independent attack on claims/evidence/route; cannot edit the implementation under review.

Do not create roles merely to reduce prompting. Monitoring is deliberately not a coworker role: keep it in the root or harness. A role is useful only when capability, write scope, epistemic status, and conflict-of-interest boundary are explicit.

## Task packet

Every worker receives canonical text containing:

- `task_id` and parent decision or plan reference;
- requested outcome and open question;
- foundation claims to try to falsify;
- repository/worktree, revision, and read/write scope;
- role and capability boundary;
- primary-evidence requirements;
- artifact path or expected response shape;
- stop/escalation conditions;
- acceptance-contract version;
- facts already known, without the root's preferred conclusion.

For review work, provide the receipt and source snapshot, not the author's persuasive narrative.

## Worker receipt

A decision-lossless receipt includes:

- observations separated from hypotheses and conclusions;
- exact evidence pointers and reproduction commands;
- counterevidence and unknown load-bearing facts;
- artifact revision/snapshot identity;
- impact if the observation is true;
- strongest competing explanation or design;
- requested root decision, if any;
- no claim of acceptance.

## Named orchestration anti-patterns

- **Pre-solve delegation** — the root solves the design, then asks a worker to confirm the answer. Repair with an open hypothesis and a closed safety envelope.
- **Scout-as-judge** — a low-trust or uncorroborated artifact is promoted directly into an architectural decision. Repair with claim classes and explicit promotion evidence.
- **Dual control plane** — native subagents and external coworker sessions both mutate the same task graph. Repair by choosing one control plane for the run.
- **Role-as-security** — a profile sentence is treated as access control. Repair with sandbox, worktree, credential, branch, and external-gate enforcement.
- **Done-is-correct** — terminal liveness becomes semantic acceptance. Repair by separating attention events, artifacts, current state, and acceptance.
- **Black-box setup** — a bundled workflow changes profiles, hooks, state, or harness behavior without an effects ledger. Repair by listing every file, process, environment variable, lifecycle owner, and removal step.

## Declaration-lint boundary

[`run-contract.tsv`](./run-contract.tsv), [`role-model-matrix.tsv`](./role-model-matrix.tsv), and [`scripts/check-run-contract.sh`](./scripts/check-run-contract.sh) mechanically lint the declared run shape: one root, an exact runtime/profile binding for every actor, a current-state path bound to the root artifact, native subagents declared disabled for the pilot, transport status declared attention-only, unique actors and canonical repo-relative artifact paths, one validation-lock owner, and typed implementer scopes. A write scope is either `path:<canonical-repo-relative-path>` or `worktree:<id>`; path scopes may not be absolute, root-wide, traversal/glob expressions, or ancestor/descendant overlaps.

It does not inspect the effective process argv, Codex profile, Claude tool state, runtime feature state, sandbox, worktree, filesystem/symlink resolution, artifact existence/content, prompt openness, reasoning quality, real independence, evidence truth, or whether the root synthesized honestly. Contract artifact paths are canonical preservation targets, not worker write grants, and implementer path scopes may not enclose them. A green result proves only declaration syntax and matrix consistency. Runtime observations, worker receipts, validation artifacts, and the root's current-state artifact remain separate evidence; do not turn a green contract into an orchestration verdict. The checker does require a fresh-session policy, root-owned validation lock, root-side monitoring, and content-digest provenance.

## Pilot and removal condition

Start with one real, read-only foundation decision and two coworkers: a claim falsifier and a strongest-alternative reviewer. Add a short-lived evidence executor only when a decisive fact is disputed. Compare the result to the simplest available baseline using [`weak-foundation-benchmark.md`](./weak-foundation-benchmark.md), without changing the requested mechanism inside the pilot. For every run, fill [`pilot-run-receipt.md`](./pilot-run-receipt.md) with the baseline, incremental finding or recovery value, coordination cost, provenance failures, fresh-session result, and root decision; use [`scripts/check-pilot-run-receipt.sh`](./scripts/check-pilot-run-receipt.sh) to bind the contract, current state, worker output, transcript, and baseline/pilot artifacts by digest.

Keep this template only if those receipts show that dedicated sessions produce material counterevidence, traceability, or recovery value that justifies their coordination cost. The maintainer chooses and records the review window before each evaluation series; no score auto-promotes it. Remove the pilot templates if that window adds no material finding over the simpler baseline, loses provenance, misroutes messages, requires status-as-truth, or cannot preserve the launch authority envelope across resume.
