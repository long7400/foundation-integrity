---
name: foundation-audit
description: Audit and try to falsify the load-bearing foundation before a non-trivial design or implementation; return one classification, outcome, and route before feature work proceeds.
disable-model-invocation: true
---

A gate you pass through before building and a falsification lens when reviewing an
existing design. A capable agent, left to its own objective ("feature works + tests
green"), will bend logic and stack wrappers to make a feature fit a weak foundation.
This skill forces the opposite move: try to prove the foundation is wrong before you
commit to it, or before local success hardens the wrong archetype.

If a workflow pack is installed, run this before architecture is frozen: **foundation-audit** → `to-spec` / design → `implement` / `tdd` / `prototype`. If a spec already exists, audit it immediately and stop before design or implementation. It needs none of them to run.

## When to run

**Run it** before any non-trivial feature, module, mechanism, migration, refactor, or security/reliability/performance change. Also run it when a plan,
implementation, design, or review target looks polished but may belong to the wrong
system category, especially when wrappers, locks, async layers, caches, or
compatibility exceptions are doing most of the work.

**Skip it** only when the work is clearly mechanical or local with no plausible architectural effect (a typo, a copy tweak, a log line). When you skip, say in one line *why* the gate is safely skipped.

## The one rule that makes this work

The audit's first objective is to **falsify** the foundation claims the work depends on. A foundation repair, an explicit research blocker, or an evidence-backed no-go is a *successful* outcome. Feature completion is not the only success. If you find yourself figuring out how to make the feature fit despite a smell, stop — that's the failure mode this gate exists to catch.

## Process

### 1. Name the requested outcome and its foundation claims

State what the work is supposed to achieve, then list every claim about existing code it load-bears on. A foundation claim is anything you're *assuming is true* about what you'll build on:

- "Orders own their own status transitions" (ownership)
- "The catalog service is the single source of truth for price" (source of truth)
- "This table is append-only" (invariant)
- "Payment never calls back into cart" (dependency direction)

Each of these is a claim you can try to break.

### 2. Try to break each claim

Inspect the owning subsystem and the dependencies. For each claim, look for **counter-evidence**, not confirmation. Treat code, tests, docs, ADRs, and current runtime behaviour as *evidence*, not automatic truth — a characterization test tells you what the system *does*, not what it *should* do. For load-bearing claims, trace summaries/release-notes/rollups back to primary evidence (the exact diff, commit, decision record, or runtime observation).

**Mismatch signals** — treat each as an investigation trigger, not proof:

- multiple compensating patches at the same seam
- wrapper-around-wrapper designs
- duplicated domain types, state, or control flow
- synchronized writes to two places that must agree
- cross-layer leakage; bypassed ownership
- feature-specific exceptions in shared code
- tests that exist to preserve a workaround
- behaviour about to be frozen into a public API, schema, or durable data
- you can't state one canonical invariant for the thing

If the work you're about to do would *add another* item to this list, that is the signal.

### 2a. Challenge the system archetype

A foundation can obey every local invariant and still be the wrong kind of system for
the requested outcome. Before accepting the current shape, compare:

- **Expected category** — what class of system fits the product goal, workload,
  latency, scale, cost, and operating model?
- **Observed category** — what class of system does the current foundation actually
  behave like?
- **Established alternative** — what simpler owner, contract, or runtime shape is
  supported by primary domain evidence, and what work does it intentionally omit,
  approximate, or move elsewhere?
- **Deviation case** — which project-specific constraint makes the current departure
  necessary, and what evidence shows its cost is budgeted?
- **Complexity delta** — which locks, queues, wrappers, adapters, caches,
  synchronization, or lifecycle rules would disappear under the alternative?

Do not invent an industry standard. Comparative practice is evidence, not authority:
cite a stable primary source, a framework contract, a measured workload, or a known
reference implementation. If the comparison is load-bearing and no trustworthy
reference is available, record that as an unknown and return `RESEARCH_ONLY` rather
than making the feature fit the current category.

Optional shared names such as **Balloon** (workaround amplification) and **Brake** (a missing load-bearing safety/lifecycle primitive) are defined in `docs/foundation/foundation-pattern-language.md` when the project adopts the compact docs. They are mnemonics, not findings: never infer them from keywords, and never use a name without a foundation claim, primary evidence, a disconfirming probe, and a fitness check or explicit semantic-only limit.

### 3. Write the foundation receipt

Concise but decision-lossless. Include:

- **Requested outcome**
- **Foundation claims** (by dependency)
- **Decisive evidence and counter-evidence** — primary sources, not summaries
- **Intended vs observed behaviour**
- **Confidence and unknowns** — unknown load-bearing facts are *research blockers*, not assumptions
- **Mismatch signals** found
- **Blast radius / change amplification / coupling**
- **Public-contract or durable-data lock-in** — is this about to freeze into an API, schema, or stored data?
- **Reversibility** and **recurring debt interest** (the ongoing cost of living with it)
- **Architectural properties the acceptance checks must preserve**
- **Archetype comparison** — expected category, observed category, evidence for the
  established alternative, justified deviation, and complexity delta (or why this
  comparison is not load-bearing)
- **Outcome** — exactly one of `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`. `RESEARCH_ONLY` means the next action is bounded evidence gathering; `NO_GO` means stop. Neither permits feature implementation.

### 4. Classify — artifact over prose

Exactly one:

- **`FOUNDATION_OK`** — claims survived the attempt to break them. The change doesn't create a second authority, bypass ownership, or add a compensating exception.
- **`FOUNDATION_SUSPECT`** — at least one claim is shaky, or a mismatch signal fired and you couldn't fully clear it. Proceed only with a named seam and eyes open.
- **`FOUNDATION_BLOCKED`** — building now would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. Or a load-bearing fact is unknown and unresolved.

**The default is not OK.** A load-bearing claim rated `OK` must cite the **artifact** that broke the attempt to falsify it — the exact diff, commit, test run, or runtime observation. A claim with no attached primary evidence is `SUSPECT` by default, not OK. This is deliberate: the session's confidence is the least trustworthy input, so "I'm sure it's fine" is worthless as evidence. "It looks right" is prose; a passing contract test or a cited invariant is an artifact. Grade on artifacts.

`FOUNDATION_OK` is not an implementation permit by itself: the outcome must also be `PROCEED`, and any observable foundation-surface trigger still requires the independent review.

### 5. Choose one route, and justify it

- **Foundation-first** — repair or introduce the missing primitive when building now would deepen a systemic mismatch or make later correction materially harder. If a workflow pack is installed, this is where you hand off to an architecture/refactor skill (e.g. `improve-codebase-architecture`, `codebase-design`).
- **Bounded-compatibility** — the narrowest reversible seam, when immediate repair is disproportionately risky or broad (especially across a real external/legacy boundary). Centralize translation at that boundary; don't let legacy semantics leak into the new domain. Require contract tests, ownership, observability, and an explicit lifecycle. State whether the seam is **temporary** (needs a migration path + removal condition) or **permanent** (needs explicit acceptance of its cost).
- **Feature-first** — proceed directly, *only* when evidence shows the foundation is sound and the change creates no second authority, no bypassed ownership, no new compensating exception.

### 6. Record the decision (ADR)

For any **Foundation-first** or **Bounded-compatibility** route, write an ADR capturing *why* — the claim, the counter-evidence, the route, and (for a temporary seam) its removal condition. Use `docs/adr/0000-template.md` when the project has adopted it. This is the antidote to "nobody remembers why this is here" — it directly protects the next maintainer's understanding.

### 7. Stop conditions

Stop *before* feature implementation when the path would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. If active harm already exists, apply only the smallest containment first, then make the structural decision.

Escalate to `adversarial-foundation-review` — a separate session whose only job is to refute your call — whenever an **observable condition** fires, not only when you rated yourself `SUSPECT`/`BLOCKED`: the change touches a foundation surface (public API, schema, migration, auth, core domain, shared module), a mismatch signal appeared, or a wired fitness check regressed. You should not be the only one grading your own foundation, and you must not be able to skip the second opinion by grading yourself OK.

## Fitness checks — put the hidden variable into the objective

An audit is a *reasoning* check; its honesty is its weak point. Where a real code stack exists, back it with **machine-measured** fitness checks so structural violations trip mechanically, with no good-faith required. The intents (tech-neutral): dependency direction holds, no new cycles, no duplicated domain type, complexity under a ceiling, no new change-coupling across module boundaries, layering respected. A claim rated `OK` should point at the check that enforces it, not just at your confidence. The optional guidance under `docs/foundation/fitness/` and the selected runtime's hook scripts are the wiring surface; no second setup skill is required. Green fitness checks are necessary, not sufficient: they prove no rule broke, not that the design is right.

Choose evidence by the claim being made, not by ritual. Use the
the adopted file `docs/foundation/fitness/proof-surface-selection.md` to
select a repro, contract test, validator, benchmark, runtime observation, visual
check, or owner-boundary proof that can falsify the claim and survive harmless
internal refactors.

## Output

Report the receipt, the classification, the explicit outcome, and the chosen route. If `RESEARCH_ONLY` or `NO_GO`, state the exact blocker and do not propose a workaround as if it were the fix.
