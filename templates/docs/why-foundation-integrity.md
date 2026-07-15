# Why foundation integrity

The rationale behind this pack. It's kept as text, in the repo, on purpose: the pack exists to fight understanding debt, so it shouldn't create any of its own. If you ever wonder why the gate is here, this is the answer.

## 1. The disease is older than AI

What follows isn't a new phenomenon of the "vibe coding" era. It's **software entropy / architectural erosion**, established by Manny Lehman starting in 1974. Two of his laws hit the core:

- **Law 2 — Increasing Complexity:** *"as an E-type system evolves, its complexity increases unless explicit work is done to maintain or reduce it."* Complexity rises monotonically; keeping it down takes deliberate effort. Do nothing and it degrades on its own.
- **Law 7 — Declining Quality:** *"the quality of an E-type system will appear to be declining unless it is rigorously maintained."*

Lehman borrowed the second law of thermodynamics directly: a closed system's entropy only rises. Software is an "E-type system" (embedded in the real world, must continually adapt), so it's always under this pressure. AI didn't create this law — it **accelerates the fall**.

The key consequence: **erosion is the default state.** A "good foundation" is something you pay to maintain continuously, not something you have by default.

## 2. Three theoretical pillars

**(a) Software rot.** The literature lists five causes: environment change, loss of reproducibility (onceability), rarely-run code hiding bugs, dependency drift, online dependencies. The only cure named is **refactoring** — *"rewriting existing code to improve its structure without affecting its external behaviour."* That is: actively repairing the foundation — exactly what an agent's completion bias avoids.

**(b) Normalization of deviance** (Diane Vaughan, analysing the Challenger disaster) — *"a process in which deviance from correct or proper behavior becomes culturally normalized."* Mechanism: a workaround bypasses a constraint with no immediate consequence → build passes, deploy succeeds → the team rationalizes it ("just temporary, it works") → the workaround becomes invisible architecture and the original constraint is forgotten. Newcomers inherit it as normal. Each accepted workaround lowers the bar for the next. This is precisely "each wrapper layer the agent adds makes the next wrapper look normal."

**(c) Conservation of Familiarity** (Lehman, Law 5) — the least-cited pillar and the one that best explains the dependency spiral: everyone tied to the system must **maintain mastery of its content and behaviour** to evolve it well; excessive growth erodes that mastery. Lehman said this in 1978: when a system grows faster than humans can understand it, evolution quality collapses. AI grows systems far faster → it breaks this law at an unprecedented scale.

## 3. Why AI makes it worse — four amplifiers

Humans cause erosion too. But AI has four properties that steepen the fall:

1. **Local optimization = Goodhart's Law.** The agent optimizes an explicit objective: "feature works + tests green." Architectural health is a **hidden variable** — not in the objective, not measured. Goodhart: *when a measure becomes a target, it stops being a good measure.* The stronger the agent, the better it hits that local objective — including by bending logic. High capability is a catalyst for harm here, not a defense.

2. **No "aesthetic pain."** A senior engineer looking at wrapper-around-wrapper feels *revulsion* — an evolved heuristic that blocks debt. For an agent, the subjective cost of ugliness is zero. It will cheerfully write a third adapter layer around a first-layer mistake.

3. **Completion bias.** The agent is rewarded for *finishing*. The path of least resistance is always "fit the existing foundation," not "stop and repair the base." It greedily chooses foundation-fitting.

4. **OOD drift — "the agent gets dumber."** LLMs are strongest on idiomatic, convention-following code near their training distribution. A bent codebase full of bespoke exceptions is **out-of-distribution** — the more deformed, the further from what the model has seen, the worse its reasoning. Combined with the context window limit: the agent can't hold the whole architecture in view, so it reasons locally → emits local patches → deforms further. There's a measured relative of this: LLM judges assign higher scores to text with **lower perplexity** — output more familiar to the model itself ([Self-Preference Bias in LLM-as-a-Judge, arXiv 2410.21819](https://arxiv.org/abs/2410.21819)). Familiarity and quality get conflated. Two consequences fall out of the same fact: a deformed (high-perplexity) codebase is genuinely harder for the model to reason about, *and* an agent grading its own fresh output rates it highly because it's maximally familiar — which is why the foundation gate can't be a self-grade (§7).

A deeper analogy worth recording: research on **model collapse / the "curse of recursion"** (Shumailov et al.) shows that when a model trains on another model's output, *"tails of the original content distribution disappear"* — rare cases and edge cases vanish first, and each iteration amplifies the loss. A codebase where AI keeps building on AI-written code follows the same shape: structure degrades toward the simplified, repetitive, and stripped-of-correct-specificity. Not direct evidence for code, but the same mathematical shape of a degenerating self-training loop.

## 4. The human side — the "addiction" has a scientific name

The "developers grow reluctant to fix it and lean on the AI more" pattern isn't vague psychology. It's two well-studied phenomena from human-automation research:

- **Automation bias & complacency** — *"propensity for humans to favor suggestions from automated systems,"* with reduced monitoring vigilance leading to *"poorer detection of system malfunctions."* The deskilling mechanism: cognitive offloading (taking the path of least cognitive effort), attention decay, and skill atrophy (losing the ability to take over when automation fails).
- **Ironies of Automation** (Lisanne Bainbridge, 1983) — automating the *easy* parts leaves humans the *hardest* parts (edge cases, failures) exactly when expertise matters most; skills atrophy from disuse; and monitoring is itself exhausting. The irony: someone supervising automation needs **more** training and deeper understanding, not less — precisely because the automation handles the routine. The gap between "normal operation" and "crisis handling" widens, making readiness harder to keep.

Together, this stacks **two kinds of debt**:

- **Technical debt** — bad code (visible).
- **Understanding debt** — *nobody remembers why* (invisible until an urgent fix is needed). The second is more dangerous, and it's a direct violation of Lehman's Law 5.

## 5. The closed loop — why it self-accelerates

The full shape of the debt machine, a **positive feedback loop**:

> weak foundation → agent patches locally to make the feature work (completion bias, no aesthetic pain) → codebase deforms further → (a) humans understand less → lean on the AI more (automation complacency + broken Conservation of Familiarity) → (b) codebase drifts further out-of-distribution → the AI also gets worse (OOD drift) → patches get even more local → foundation weakens further → repeat, steeper.

The distinctive part: **both the human and the AI degrade inside the same loop.** The human loses understanding; the AI loses reasoning capacity to OOD. There is no natural brake inside this loop — the brake has to be installed from outside.

## 6. What most workflow packs don't address

Workflow skill packs (idea → ticket → spec → test → review) optimize *flow*. They assume the foundation is fine and help you flow faster on top of it. But "flowing fast on a weak foundation" is exactly the debt machine in section 5.

Review and domain-modeling skills touch the edge (local quality review; keeping vocabulary/ADRs). But there's typically **no gate that, before you build, actively tries to prove the foundation assumption is WRONG.** That's the gap this pack fills.

## 7. How this pack answers it, and its own limits

The checks map to the mechanisms above, in two layers.

**Reasoning layer** (depends on the session's honesty — so it's backed, never trusted alone):

- `foundation-audit` — falsify-first, before building → counters **completion bias** and **normalized deviance**.
- `adversarial-foundation-review` — an independent session, ideally a different model → counters the **self-attestation conflict of interest** (an agent grading its own foundation).
- `foundation-health` — cumulative, separate from feature work → counters the **per-feature blind spot** (erosion is cumulative; no single feature owns it).
- The explain-the-invariant tripwire + ADR discipline → counter **understanding debt** and protect Lehman's Law 5.

**Measurement layer** (needs no good faith and nobody has to read the code — this is what makes the reasoning layer honest):

- **Fitness functions** (`templates/fitness/`) — machine-checked dependency direction, cycles, layering, complexity, change-coupling. A *structural* violation (wrong-direction import, a new cycle, a broken layer) trips a rule mechanically and becomes an objective fact, not an opinion. A wrapper that stays *within* an allowed direction does not — see §8; this is a floor, not a verdict.
- **Hooks** (`templates/hooks/`) — run the checks whether or not the agent wants them to, at commit/push (git, runtime-neutral) and mid-session (Claude/Codex). The surface-guard flags an **observable fact** (a schema/API/auth file changed with no ADR/receipt naming it) and prints the instruction to run `adversarial-foundation-review`. It removes the self-grade escape and makes skipping visible and costly — it does not itself launch or verify the review (§8).

Why two layers: the self-attestation problem has a measured basis — LLM judges prefer their own low-perplexity output ([arXiv 2410.21819](https://arxiv.org/abs/2410.21819)) — so a check that *depends* on the grading session's honesty can't be the only defence. The measurement layer is the part that doesn't ask for good faith.

The reframe to carry: the root problem is an **incentive mismatch** — the agent's objective is "task done + tests green" while what you need is a *hidden variable* (architectural health, future maintainability) that isn't in the objective and isn't measured. Every durable fix is one of two moves: **(a) put the hidden variable into the objective** (fitness signals, hooks, gates, ADRs, the invariant tripwire), or **(b) keep a human in the loop who genuinely holds it.** This pack does both — but neither move is total, and pretending otherwise would make the pack commit the exact sin it names.

## 8. Residual limits — what no amount of this tooling closes

Two gaps are structural, not bugs to be fixed in a later version. They were surfaced by running two independent different-model reviews against this pack (the very mechanism §7 recommends), and they are load-bearing enough to state plainly:

1. **A receipt proves a decision was *recorded*, not that a review *ran*, nor that it was *good*.** In the default **advisory** mode the surface-guard clears a change when a valid receipt in the change set names the changed path — a text artifact an agent can write. That still buys real value (a versioned, structured audit trail; skipping becomes deliberate and visible), but it is not proof. The opt-in **attested** mode narrows this: clearing additionally requires a commit signed by a key on a trusted-reviewer allowlist that lives *outside* the working tree, and the receipt's `reviewer` must match that key's identity. An agent that can edit files but does not hold the signing key cannot clear a gated surface change. But attested mode does **not** prove the reviewer thought hard (a held key can rubber-stamp), and it is only authoritative when a protected CI / branch-protection rule re-runs the verification — a local hook is bypassable. Its whole strength rests on one assumption: **the signing key and the allowlist are genuinely outside the authoring agent's reach.** If that holds, self-attestation is closed for gated surfaces; if it doesn't, attested collapses back to advisory. There is no portable way to prove *cognition*; only an out-of-band human or harness supplies that.

2. **Fitness functions measure structure, not intent.** Dependency direction, cycles, and layering are mechanically checkable. "Is this the right archetype?", "is this wrapper bending logic?", "is this a duplicated concept wearing two legal types?" are not — a bent-logic patch that stays inside an allowed dependency direction passes every structural rule. This is precisely the original failure (§1): the strong agent bends logic *within* what looks legal. So the machine layer is a **floor that catches the cheap violations**, and the semantic judgment still rests on the reasoning layer — which is why the reasoning layer must be backed by an independent, ideally different-model, reviewer and cannot be trusted alone.

3. **The trust root must sit outside the agent's write scope, or attested mode is theatre.** The guard reads its surface policy from `foundation-surface.txt`, runs from a script, and consults an allowlist — all of which, by default, live *in the repo the agent edits*. An agent that can edit files can simply empty the policy (no surface hits → nothing to attest → the guard exits 0 before any signature check), or rewrite the script, or point the allowlist at its own key. So attested mode only means anything when a **protected CI job runs a checker, policy, and allowlist fetched from a location the author cannot write** (a protected branch, a separate repo, server config) — not the copies in the pushed tree. Ship the in-repo hooks as convenience and as the advisory audit trail; treat the *enforcing* copy as infrastructure that must be external. This isn't a bug to patch in shell — it's the same irreducible truth one level down: a control the controlled party can edit is not a control.

4. **Structural checks bind to the working tree, not every pushed ref.** The tier-3 adapters (dependency-cruiser, ArchUnit, etc.) analyse the checked-out tree, so in a multi-ref push a structurally broken branch that isn't checked out is not adapter-checked locally. Only per-ref checkout in CI closes this. The git-only tier-2 delta *does* run per ref; the heavier adapters need CI to iterate refs.

The uncomfortable synthesis: the part of the problem that hurts most — *is this foundation actually sound?* — is an irreducible reasoning judgment. Tooling can make evasion visible and expensive, measure the mechanically-measurable, and force the question to be asked before code freezes. It cannot make the judgment for you. And the enforcement itself bottoms out on a trust root the agent cannot edit: without that, every mechanism here degrades to advisory. A capable, genuinely independent reviewer (human or different model) plus an external trust root are not nice-to-haves in this design; they are the load-bearing elements the rest is built to protect. This pack was itself built under exactly that discipline — its own fixes were falsified repeatedly by independent different-model review, which is the only reason these limits are stated honestly rather than discovered in production.

## Sources

**Read directly and verified while writing this:**

- [Lehman's laws of software evolution](https://en.wikipedia.org/wiki/Lehman's_laws_of_software_evolution) — Increasing Complexity, Declining Quality, Conservation of Familiarity
- [Software rot](https://en.wikipedia.org/wiki/Software_rot) — software entropy, causes, refactoring as the cure
- [The Curse of Recursion / Model Collapse (Shumailov et al.)](https://arxiv.org/abs/2305.17493)
- [Normalization of deviance](https://en.wikipedia.org/wiki/Normalization_of_deviance) — Diane Vaughan / Challenger
- [Automation bias](https://en.wikipedia.org/wiki/Automation_bias) — complacency, deskilling
- [Lisanne Bainbridge — Ironies of Automation (1983)](https://en.wikipedia.org/wiki/Lisanne_Bainbridge)
- [Fitness function-driven development (Thoughtworks)](https://www.thoughtworks.com/en-us/insights/articles/fitness-function-driven-development)
- [Self-Preference Bias in LLM-as-a-Judge (arXiv 2410.21819)](https://arxiv.org/abs/2410.21819) — LLM judges score their own lower-perplexity (more familiar) output higher; the measured basis for "an agent can't grade its own foundation"
- [Logical / change coupling](https://en.wikipedia.org/wiki/Coupling_(computer_programming)) — co-change from release history, computable from commit metadata alone
- Architecture-rule tools verified while writing the fitness adapters: [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) (JS/TS), [ArchUnit](https://github.com/TNG/ArchUnit) (JVM), [import-linter](https://github.com/seddonym/import-linter) (Python), [go-arch-lint](https://github.com/fe3dback/go-arch-lint) (Go)

**Unverified leads — cited by name, look up before relying on the specifics:**

- GitClear, "Coding on Copilot" / AI Copilot Code Quality reports (2023–2024) — the churn / duplication / declining-refactoring trend claims come from these but were not opened at the primary source here.
- Google DORA Report 2024 — AI adoption vs delivery-stability tradeoff.
- *Building Evolutionary Architectures* (Ford, Parsons, Kua) — fitness-function taxonomy (atomic/holistic, triggered/continuous).
- Goodhart's Law; Ward Cunningham's technical-debt metaphor.
