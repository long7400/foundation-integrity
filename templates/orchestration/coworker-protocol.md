# External coworker protocol

Status: **opt-in pilot; advisory; inert until a user explicitly requests external
coworkers and `HERDR_ENV=1`.**

## Canonical invariant

One root owns dispatch, validation leases, acceptance, release, and teardown.
Transport status and pane metadata attract attention; they never approve work.

## Rules

1. **Use one personnel control plane.** During this pilot, disable native subagents.
   Coworkers do not spawn or supervise other workers.
2. **Keep topology at the root.** A coworker receives the task, safety scope,
   evidence requirement, and stop condition. It does not receive Herdr commands,
   department structure, or backend policy. This is prompt/context isolation, not a
   same-user security boundary; the launcher also removes inherited `HERDR_*`
   variables to avoid accidental topology disclosure.
3. **Ask an open question.** State the requested outcome and claims to falsify, not
   the root's preferred answer. Hear independent evidence before challenging it.
4. **Keep authority tied to evidence.** A scout can locate a high-impact seam but
   cannot settle a difficult architectural, security, or durable-contract claim.
   Read-only peers never accept or release work. Implementers never approve their own
   durable change.
5. **Separate attention from acceptance.** `working`, `idle`, `done`, `blocked`,
   terminal text, context percentage, compact count, and cache hints are observations.
   Root reads the response and validation evidence before deciding.
6. **Submit visibly.** Type a task packet once, press Enter, and verify a runtime
   transition. If submission races, retry Enter only; never duplicate the prompt.
7. **Wait boundedly.** Inspect current status before waiting. Treat `idle` and `done`
   as possible turn completion, surface `blocked`, and time out rather than freezing.
8. **Serialize expensive evidence.** Before coworkers start, root creates a random
   validation capability. Heavy or flaky validation requires that capability and one
   lease shared across Git worktrees. Record revision, cwd, command, exit status, and
   output. A green test is evidence, not acceptance.
9. **Isolate writes.** Read-only work may share a checkout. A writer gets a worktree
   or a serialized bounded path and an acceptance contract.
10. **Use fresh sessions for independent review.** A session reference is continuity,
    not identity or authority. Resume remains unaccepted until model, instructions,
    permissions, cwd, worktree, and task contract are re-attested.
11. **Preserve before teardown.** Read the response, keep disagreement and decisive
    evidence, then mark it accepted, rejected, or cancelled. Close only sessions this
    run created.
12. **Do not create a hidden workflow engine.** No coworker hierarchy, watcher fleet,
    task state machine, model matrix, automatic profile rewrite, or FirstMate install.

## Roles

- **root** — sole controller and decision owner;
- **peer** — read-only discovery or independent challenge;
- **implementer** — bounded writer after the foundation route is accepted.

Profiles reduce repeated prompting by fixing a capability envelope. They are not
access control or proof of the effective launch. Model strength never changes role
authority.

## Task packet and receipt

Start from [`task-packet.md`](./task-packet.md). Include the outcome, open question,
foundation claims, source snapshot, scope/access, primary-evidence requirement,
expected response shape, and stop conditions. Do not include a preferred conclusion.

A useful coworker response separates observations, hypotheses, and conclusions; cites
exact evidence and reproduction commands; records counterevidence and unknowns; names
the strongest alternative; and requests a root decision without claiming acceptance.

Use [`pilot-run-receipt.md`](./pilot-run-receipt.md) only when comparing the pilot to
a simpler baseline. Live text may remain in its session or an explicit `$TMPDIR`
chosen by the root. Promote only accepted decision-lossless evidence to the project's
durable owner. The pack does not create a repository task-state directory.

## Named failure modes

- **Balloon** — adding wrappers, locks, caches, synchronization, or exceptions to make
  a feature pass on a weak owner or wrong system archetype.
- **Brake** — building the visible feature before a missing load-bearing safety or
  lifecycle primitive exists.
- **Pre-solve delegation** — solving first, then asking a peer for confirmation.
- **Scout-as-judge** — promoting discovery directly into a difficult conclusion.
- **Dual control plane** — native and external personnel controllers in one run.
- **Done-is-correct** — treating liveness as semantic acceptance.

Names are shorthand, not findings. Each needs a falsifiable claim and evidence.
