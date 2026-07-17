# Personal Operating Rules

This project uses Foundation Integrity to stop locally correct work from hardening
the wrong owner, source of truth, lifecycle, trust boundary, dependency direction,
or system shape.

## Priority and claim preservation

- Follow instruction hierarchy and scope; an explicit user command outranks skills,
  playbooks, defaults, and doctrine.
- Preserve every requested outcome, mechanism, tool, model, workflow, and property.
  An adjacent mechanism is not fulfillment; if the required one is unavailable,
  state the exact blocker and offer (without implementing) a reduced alternative.
- If parallel agents are required, use the Herdr-only rule below and launch
  independent units concurrently up to capacity; report capacity/overlap blockers.
- Preserve a reviewed base-instruction override while its recorded upstream issue or
  removal condition remains unresolved; remove it only after a verified fix or owner
  acceptance.

## Foundation gate

- Before non-trivial feature, mechanism, migration, refactor, security, reliability,
  or performance work, read `foundation-audit/SKILL.md` and try to falsify ownership,
  source of truth, lifecycle, trust boundaries, dependency direction, invariants,
  intended/observed behavior, and the simpler established archetype. Skip only work
  that is clearly mechanical/local and say why.
- Record exactly one classification (`FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or
  `FOUNDATION_BLOCKED`), one outcome (`PROCEED`, `RESEARCH_ONLY`, or `NO_GO`), and
  one route (Foundation-first, Bounded compatibility, or Feature-first). Only
  `PROCEED` permits dependent implementation; unknown load-bearing facts block.
- Contain active harm first. Stop before creating a second authority, bypassing an
  owner/trust boundary, repeating exceptions, or freezing a known mismatch into a
  durable contract.
- Acceptance must exercise the architectural property at risk. After a foundation
  surface or mismatch changes, obtain a fresh independent adversarial review; the
  implementer cannot approve its own durable work.

## Workstream authority and handoffs

- Use this section only when multiple workers are explicitly requested and the
  required delegation mechanism exists; ordinary single-session work stays single.
- Each worker owns its workstream. Mutation scope limits writes, not evidence it may
  inspect, challenge, or recommend. User claims and hard invariants bind it; root
  diagnoses and provisional ordering remain hypotheses unless binding.
- Root owns task state, validation leases, acceptance, release, teardown, and final
  authority. Workers cannot self-approve durable work.
- Reports are concise but decision-lossless: preserve outcome, decisive evidence and
  counterevidence, validation, uncertainty, deviations, unlocked dependencies,
  absorption, and downstream implications. Never request hidden chain-of-thought.
- Keep canonical instructions, decisions, criteria, and exact evidence as text.

### Herdr-only coworker spawning

- Any request for external coworkers, parallel agents, or “spawn agent” requires
  `HERDR_ENV=1` and Herdr. If absent, report the blocker. Never substitute a manual
  terminal command, native subagent, or background agent.
- Use Herdr for creation, task delivery, bounded waits, output inspection, and
  teardown. Never mix native subagents/background agents with Herdr coworkers.
- Root may invoke applicable skills progressively while coworkers run, but must not
  bulk-load unrelated skill bodies. In a team, specialists report only to the Tech
  Lead; only the Tech Lead synthesis enters root context.
- A root-started `wait-coworker-team` relay may fan in immutable specialist artifacts
  outside model context. It wakes root once, only after synthesis is ready and root
  becomes idle; it never interrupts an active root turn or accepts work.
- If Herdr is unavailable, report the exact blocker and do not substitute another
  mechanism without explicit user acceptance.

## Task graph and reconciliation

- Plan with a dependency-and-absorption graph, not a priority queue. Order by user
  sequence/containment, dependency unlocks, foundation leverage, durable shape,
  absorption/supersession, risk, reversibility, and evidence.
- A lower-labelled foundation may precede a higher dependent task only with recorded
  evidence of the unlock and durable benefit.
- Reconcile after each wave (about three or four tasks) and whenever evidence changes
  dependencies or acceptance. For ambiguous high-impact ordering, ask one
  independent reviewer for the strongest alternative; root decides explicitly.
- If one change fully covers another's criteria, mark the latter absorbed/superseded.
  Close external work only when its workflow authorizes that state change.
- Run independent units in parallel, dependent units sequentially, and overlapping
  writes sequentially or with explicit ownership. Avoid ceremony for trivial work.

## Installed ownership

- Create this file only when `AGENTS.md` is absent; existing `AGENTS.md` and
  `CLAUDE.md` remain project-owned and byte-for-byte untouched.
- Runtime projections live under `.agents/skills/` and/or `.claude/skills/`; hooks
  under the matching runtime path. Optional orchestration is inert under
  `.orchestration/foundation/`; ignored runtime state and transport status are never
  task authority or acceptance evidence.
- Keep local review receipts under ignored `docs/foundation/receipts/`. Promote only
  accepted decision-lossless evidence that must be shared into an explicitly tracked
  project owner.
