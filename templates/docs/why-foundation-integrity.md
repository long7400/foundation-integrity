# Why foundation integrity

This is the consumer rationale, not a research archive. It keeps only the operational
claims needed to understand the gate. The distribution repository owns full source
citations and experiments in its decision records; the compact audit pointer copied
with the pack is `distribution-provenance.md`.

## The failure mode

A capable agent is usually optimized for a local outcome: make the requested feature
work and make the visible checks green. Architectural health is easy to omit from
that objective because it is slower to observe and often belongs to a dependency the
feature did not create.

When the dependency is weak, local optimization can still succeed by adding state,
locks, wrappers, retries, translation layers, duplicated types, or exceptions above
the wrong owner. The feature looks correct while the foundation becomes harder to
replace and harder to explain. Later work treats those compensations as normal and
adds more of them.

The resulting loop is:

> weak foundation -> locally successful compensation -> more concepts and coupling
> -> lower human and agent comprehension -> more local compensation

Feature correctness is therefore necessary but insufficient. The foundation claims
that the feature load-bears on must also be falsifiable before a durable interface,
schema, migration, or ownership decision is frozen.

## The response

Foundation Integrity uses two complementary layers.

The reasoning layer asks the architectural question:

- `foundation-audit` tries to falsify ownership, source-of-truth, lifecycle, trust,
  dependency-direction, invariant, and system-archetype claims before building;
- `adversarial-foundation-review` gives a fresh independent session an open challenge
  rather than asking it to approve a proposed answer; and
- `foundation-health` trends accumulated coupling, churn, exceptions, compatibility
  seams, and unresolved decisions outside the pressure of a single feature.

The measurement layer makes mechanically observable failures harder to ignore:

- fitness checks enforce selected structural properties such as dependency
  direction, cycles, and layering; and
- hooks trigger on changed foundation surfaces and run the selected checks even when
  the authoring session would prefer to move on.

Neither layer replaces the other. Reasoning can examine intent but may rationalize
its own work. Mechanical checks do not need good faith, but they can inspect only the
properties encoded in them.

## What a valid gate returns

The gate records exactly one classification:

- `FOUNDATION_OK` — the load-bearing claims survived the available probes;
- `FOUNDATION_SUSPECT` — material mismatch or uncertainty remains; or
- `FOUNDATION_BLOCKED` — an invariant, trust boundary, or unknown prevents safe
  dependent work.

It also records exactly one outcome (`PROCEED`, `RESEARCH_ONLY`, or `NO_GO`) and one
route (Foundation-first, Bounded compatibility, or Feature-first). Only `PROCEED`
unlocks dependent implementation.

Foundation-first repairs or introduces the missing primitive. Bounded compatibility
centralizes translation at a real boundary and makes its ownership, tests,
observability, migration, and removal lifecycle explicit. Feature-first is valid only
when the foundation is sound and the feature does not create another authority or
compensating exception.

## Residual limits

These are design boundaries, not TODOs that more ceremony will solve:

1. A default advisory receipt proves that a structured decision was recorded for a
   bound revision and change digest. It does not prove that an independent review ran
   or that the judgment was good.
2. Attested mode proves only that an allowed signing identity approved the bound
   change. It is meaningful only when the key, allowlist, checker, and policy are
   outside the author's write scope and protected automation re-runs the check.
3. Fitness functions measure encoded properties, mainly structure. A wrong archetype,
   duplicated concept, or semantic wrapper can remain legal under every dependency
   rule. Green fitness is a floor, not an architectural verdict.
4. Local hooks are bypassable and tier-3 tools normally inspect the checked-out tree,
   not every ref in a multi-ref push. Protected CI must own any authoritative gate.
5. A separate model is not automatically independent. Give it the original problem,
   evidence boundary, and safety scope without the author's proposed conclusion, then
   reconcile its counterevidence at the decision owner.

The irreducible question remains: is the foundation actually sound for this outcome?
The pack makes that question explicit, gives it observable tripwires, and records the
answer. It cannot replace accountable judgment.

## Context boundary

Installing files is not the same as loading them into a prompt. The adopted
instruction block and skill discovery metadata are active surfaces; full skill bodies
load when invoked; templates, orchestration manuals, and project documents remain
inert until a runtime, skill, or person reads them.

Keep this consumer rationale concise. Put project-specific evidence in an ADR or
receipt, keep exploratory research in ignored working state, and load optional
fitness or orchestration material only for the task that needs it.
