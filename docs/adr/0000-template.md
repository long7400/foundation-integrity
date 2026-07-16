# ADR-NNNN: <short title of the decision>

- **Status:** proposed | accepted | superseded by ADR-NNNN
- **Date:** YYYY-MM-DD
- **Foundation route:** Foundation-first | Bounded-compatibility | Feature-first
- **Classification at decision time:** FOUNDATION_OK | FOUNDATION_SUSPECT | FOUNDATION_BLOCKED

## Context

What work prompted this decision, and what foundation it load-bears on. State the foundation claim(s) at stake — the things assumed true about existing code.

## Counter-evidence

What the `foundation-audit` tried to break, and what it found. Cite primary evidence (exact diff, commit, decision record, runtime observation) — not summaries. If a claim survived, say what was tried and couldn't break it.

## Decision

The route chosen and why this one over the alternatives. For **Bounded-compatibility**, describe the seam: where translation is centralized, what it keeps from leaking, and its contract tests / ownership / observability.

## Lifecycle (Bounded-compatibility only)

- **Temporary or permanent?**
- If **temporary**: the migration path and the **removal condition** — the concrete signal that says "this seam can now be deleted."
- If **permanent**: explicit acceptance of its ongoing architectural cost.

## Canonical invariant

The one invariant this decision preserves, in a single plain sentence. (If you can't write it, the decision isn't ready.)

## Consequences

Blast radius, reversibility, and the recurring debt interest — the ongoing cost of living with this decision.
