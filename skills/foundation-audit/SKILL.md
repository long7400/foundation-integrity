---
name: foundation-audit
description: Before designing or building a non-trivial feature, module, mechanism, migration, or refactor, run a proportional audit of the foundation the work will load-bear on. The audit's first objective is to FALSIFY the foundation claims the work depends on — not to make the feature fit the current code at any cost. Produces a foundation receipt, a classification (FOUNDATION_OK / FOUNDATION_SUSPECT / FOUNDATION_BLOCKED), and one justified implementation route. Use before implement/tdd/prototype, before a migration or schema change, or whenever you're about to build on top of something you haven't verified.
---

A gate you pass through *before* building, not a review you run *after*. A capable agent, left to its own objective ("feature works + tests green"), will bend logic and stack wrappers to make a feature fit a weak foundation. This skill forces the opposite move: try to prove the foundation is wrong before you commit to it.

If a workflow pack is installed, this runs in the seam between spec and build: `to-spec` → **foundation-audit** → `implement` / `tdd` / `prototype`. It needs none of them to run.

## When to run

**Run it** before any non-trivial feature, module, mechanism, migration, refactor, or security/reliability/performance change.

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

### 4. Classify — artifact over prose

Exactly one:

- **`FOUNDATION_OK`** — claims survived the attempt to break them. The change doesn't create a second authority, bypass ownership, or add a compensating exception.
- **`FOUNDATION_SUSPECT`** — at least one claim is shaky, or a mismatch signal fired and you couldn't fully clear it. Proceed only with a named seam and eyes open.
- **`FOUNDATION_BLOCKED`** — building now would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. Or a load-bearing fact is unknown and unresolved.

**The default is not OK.** A load-bearing claim rated `OK` must cite the **artifact** that broke the attempt to falsify it — the exact diff, commit, test run, or runtime observation. A claim with no attached primary evidence is `SUSPECT` by default, not OK. This is deliberate: your own confidence is the least trustworthy input here — the same self-preference that makes you rate familiar output highly (arXiv 2410.21819) makes "I'm sure it's fine" worthless as evidence. "It looks right" is prose; a passing contract test or a cited invariant is an artifact. Grade on artifacts.

### 5. Choose one route, and justify it

- **Foundation-first** — repair or introduce the missing primitive when building now would deepen a systemic mismatch or make later correction materially harder. If a workflow pack is installed, this is where you hand off to an architecture/refactor skill (e.g. `improve-codebase-architecture`, `codebase-design`).
- **Bounded-compatibility** — the narrowest reversible seam, when immediate repair is disproportionately risky or broad (especially across a real external/legacy boundary). Centralize translation at that boundary; don't let legacy semantics leak into the new domain. Require contract tests, ownership, observability, and an explicit lifecycle. State whether the seam is **temporary** (needs a migration path + removal condition) or **permanent** (needs explicit acceptance of its cost).
- **Feature-first** — proceed directly, *only* when evidence shows the foundation is sound and the change creates no second authority, no bypassed ownership, no new compensating exception.

### 6. Record the decision (ADR)

For any **Foundation-first** or **Bounded-compatibility** route, write an ADR capturing *why* — the claim, the counter-evidence, the route, and (for a temporary seam) its removal condition. Use [`templates/adr/0000-template.md`](../../templates/adr/0000-template.md). This is the antidote to "nobody remembers why this is here" — it directly protects the next maintainer's understanding.

### 7. Stop conditions

Stop *before* feature implementation when the path would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. If active harm already exists, apply only the smallest containment first, then make the structural decision.

Escalate to `adversarial-foundation-review` — a separate session whose only job is to refute your call — whenever an **observable condition** fires, not only when you rated yourself `SUSPECT`/`BLOCKED`: the change touches a foundation surface (public API, schema, migration, auth, core domain, shared module), a mismatch signal appeared, or a wired fitness check regressed. You should not be the only one grading your own foundation, and you must not be able to skip the second opinion by grading yourself OK.

## Fitness checks — put the hidden variable into the objective

An audit is a *reasoning* check; its honesty is its weak point. Where a real code stack exists, back it with **machine-measured** fitness checks so structural violations trip mechanically, with no good-faith required. The intents (tech-neutral): dependency direction holds, no new cycles, no duplicated domain type, complexity under a ceiling, no new change-coupling across module boundaries, layering respected. A claim rated `OK` should point at the check that enforces it, not just at your confidence. Wiring these per stack is `setup-foundation-integrity`'s job — see `templates/fitness/`. Green fitness checks are necessary, not sufficient: they prove no rule broke, not that the design is right.

## Output

Report the receipt, the classification, and the chosen route. If blocked, state the exact blocker — don't propose a workaround as if it were the fix.
