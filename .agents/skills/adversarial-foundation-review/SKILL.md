---
name: adversarial-foundation-review
description: In a fresh independent session, try to refute a triggered foundation decision, its evidence, route, and cheapest fake-pass before durable work is accepted.
disable-model-invocation: true
---

The `foundation-audit` gate has one structural weakness: the same session that wants to complete the work also decides whether the foundation is sound. That's a conflict of interest. This skill is the fix — an **independent reviewer with no stake in shipping**, whose success condition is *finding the flaw*, not approving the plan.

## Run this in a separate session — ideally a different model

This must not run in the session that produced the audit. Open a fresh one — a new tab, a new agent, a teammate. The reviewer should not carry the original session's momentum toward completion. If you're driving multiple sessions (e.g. via a harness), spin up a dedicated one for this and give it only the receipt plus read access to the code.

When a harness supplies an external top-level coworker session rather than a native subagent, keep its transport and orchestration mechanism outside this skill. Do not treat a transport status such as `idle` or `done` as proof that a review completed or was accepted.

Two things sharpen the check against self-preference bias:

- **Prefer a different model.** The bias is strongest when the reviewer is the same model that wrote the code — it recognises its own low-perplexity output as "good". A different model (or at least a different session with no memory of writing it) doesn't get that familiarity discount.
- **Don't feed the reviewer the original session's justification.** Give it the receipt and the code, not the persuasive narrative for why the plan is fine. The reviewer's job is to reach its own verdict, not to be talked into the author's.
- **Default posture is refute.** The reviewer starts from "this decision is wrong until it survives an attack." Burden of proof sits on the claim, not on the refutation — so "it looks familiar and reasonable" is never enough to pass.

## When to run — triggered by observable facts, not by the self-rating

This is the fix for the gate's deepest hole. The naive trigger is "run this when the
audit self-rated SUSPECT/BLOCKED" — but that's circular: an agent with completion bias
rates its own work `FOUNDATION_OK` precisely so it can proceed, and then the review
never fires. There's a measured mechanism behind that bias, not just laziness: LLM
judges score their own familiar output higher because lower perplexity reads as
"better." A fresh session matters because familiar output is easier to approve than to refute;
that is a review-risk, not a reason to load an external paper or repository template.
A model grading its own fresh wrapper is grading the most familiar thing it has seen.

So the trigger is **an observable condition**, independent of what the audit rated
itself:

- The change touches a **foundation surface** — a public API, schema, migration, auth
  boundary, core-domain model, or a widely-shared module. (A file changed is a fact;
  the surface-guard hook detects it mechanically.)
- A **mismatch signal** appeared in the change — a new wrapper layer, a duplicated
  domain type, a synchronized write, cross-layer leakage.
- A wired **fitness check regressed** — a new cycle, a dependency pointing the wrong
  way, a broken layer.
- The audit self-rated `SUSPECT` or `BLOCKED` (still a valid trigger — just no longer
  the *only* one).
- The audit felt too easy — the claims survived without a fight.

Any one of these fires the review, regardless of the self-rating. The self-grade can
lower confidence; it can never *suppress* the review.

Skip it only for changes that touch no foundation surface, raise no mismatch signal,
and regress no fitness check — genuinely low-impact, easily reversible work. There the
gate alone is enough.

## Your job is to break the decision

You are handed a foundation receipt. Do **not** re-run the original audit sympathetically. Attack it:

1. **Attack the claims.** For each foundation claim marked "survived", construct the input, state, or sequence that breaks it. If you can't break it, say specifically what you tried — that's the evidence it holds.

2. **Attack the evidence.** Is the "decisive evidence" a primary source (exact diff, commit, decision record, runtime observation) or a summary / release note / rollup standing in for one? Downgrade any claim resting on a summary.

3. **Attack the route.** For the chosen route, argue the strongest case for a *different* one:
   - If **Feature-first**: show where it creates a second authority, bypasses ownership, or adds a compensating exception.
   - If **Bounded-compatibility**: show where legacy semantics leak past the seam into the new domain; challenge "temporary" seams that have no real removal condition.
   - If **Foundation-first**: challenge whether the repair is scoped right — too broad (unnecessary blast radius) or too narrow (leaves the mismatch half-fixed).

4. **Attack the stop/go.** If the audit said proceed, argue for stop. If it said stop, argue whether the containment is actually the smallest necessary — or whether it's over-reaching.

5. **Construct the fake pass.** Describe the cheapest plausible implementation that
   could make the stated feature tests or acceptance checks green while preserving the
   wrong owner, wrong archetype, duplicated authority, or compatibility residue. Name
   the exact proof gap that lets it pass. If no fake pass survives, state what blocks
   it; that is stronger evidence than saying the plan looks complete.

Judge the solution before the paperwork. A complete receipt, plan, or checklist is not
evidence that the target architecture is correct. Keep document/readiness defects
secondary unless they hide a real owner, boundary, lifecycle, evidence, rollback, or
removal-path gap.

## Output

A verdict, plainly stated:

- **Upholds** — the decision survives the attack. Name what you tried to break and couldn't. This is now stronger evidence than the original audit.
- **Overturns** — the decision fails. Give the specific claim, evidence gap, or route flaw, and the concrete failure it leads to.
- **Amends** — the decision mostly holds but the route or seam needs a named change (tighter boundary, added contract test, a removal condition, a different classification).

Include the strongest fake-pass construction attempted and the proof that blocks it or
the gap that permits it.

Hand the verdict back to the originating session. Do not implement the fix yourself — you are the check, not the builder.
