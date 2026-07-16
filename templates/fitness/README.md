# Fitness functions — the measurement layer

The foundation gate (`foundation-audit`) is a *reasoning* check. Its weak point is
self-attestation: the same session that wants to finish the feature can rationalize
its own compensating design and rate the foundation `FOUNDATION_OK`.

Fitness functions close *part* of that hole. They are **machine-measured** signals of
architectural health — they need no good faith and nobody has to read the code. A
bent dependency (wrong-direction import, a new cycle, a broken layer) **mechanically**
trips a rule. This puts the hidden variable (architectural health) *into the objective*
instead of trusting a self-grade.

Know the boundary, though: these tools measure **structure**, not **intent**. A
wrapper that stays *within* an allowed dependency direction, a duplicated domain
concept expressed as two "legal" types, or a foundation built on the wrong archetype
can all pass every structural rule while being exactly the bent-logic the pack warns
about. So fitness checks are a floor, not a verdict — they catch the violations that
are cheap to catch and free the reasoning gate to focus on the ones that aren't. See
"The honest boundary" below and "Residual limits" in
`../why-foundation-integrity.md`.

## Three tiers

Read top-down. Every repo gets tier 1 and tier 2 for free; tier 3 is opt-in when a
real code stack exists.

Before choosing a concrete test or check, use
[`proof-surface-selection.md`](./proof-surface-selection.md). It maps the claim under
review to the evidence surface most capable of falsifying it; "write a unit test" is
not a universal answer.

### Tier 1 — Intent (tech-neutral)

*What* to enforce, independent of any tool or language. This is the only tier that
belongs in a `SKILL.md`; it never names a tool. The intents:

- **Dependency direction holds.** Inner/domain layers don't import outer/adapter
  layers. No module imports "up" or "in" against the declared direction.
- **No new cycles.** Modules/packages don't form import cycles.
- **No duplicated domain type / state / control flow.** One canonical definition per
  concept.
- **Complexity stays under a ceiling per unit.** A function/class that blows past the
  ceiling is a review trigger.
- **No new change-coupling across module boundaries.** Two modules that must always
  change together are secretly one module — see tier 2.
- **Layering / ownership is respected.** Handlers don't reach into repositories,
  features don't reach into each other's internals, etc.

A fitness function is just one of these intents made executable and put where nobody
can skip it (CI, a hook, a test suite).

### Tier 2 — Git-only generic ([`git-only.md`](./git-only.md))

Portable to **every** repo — any language, even one with no compiler or parser
available, even a pre-code docs repo (where it simply finds nothing yet). Computed
from `git log` metadata alone: change-coupling, churn hotspots, blast radius. This is
the tier that directly answers *"nobody reads 100% of the agent's code"* — the machine
reads the history instead. These signals are **cumulative**, so they live in
`foundation-health` (run periodically), not in a per-edit hook.

### Tier 3 — Per-stack adapter ([`adapters/`](./adapters/))

Names a concrete tool per ecosystem to enforce tier-1 intents structurally, per change,
in CI. This tier is stack-specific **by definition**, so it lives in this optional
fitness guidance directory — never in a `SKILL.md`. The maintainer wires the matching adapter explicitly; no
setup workflow silently detects or changes the stack:

| Stack | Tool | Enforces |
| --- | --- | --- |
| JS / TS | [dependency-cruiser](./adapters/js-ts.md) | dependency direction, no cycles, layering |
| JVM (Java/Kotlin) | [ArchUnit](./adapters/jvm.md) | same, as unit tests in the normal suite |
| Python | [import-linter](./adapters/python.md) | layered contracts, forbidden imports |
| Go | [go-arch-lint](./adapters/go.md) | component dependency rules |

If your stack isn't listed, the intent tier still applies — wire the equivalent
architecture-rule tool for your ecosystem and point it at the same intents.

## The honest boundary

Tier 3 catches structural violations mechanically. It does **not** decide whether a
foundation *claim* is sound — that's still `foundation-audit` + `adversarial-foundation-review`.
Green fitness checks are necessary, not sufficient: they prove no rule was broken, not
that the design is right. Don't let a green board substitute for the reasoning gate.
