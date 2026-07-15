## Foundation Integrity

The gate that runs before building on a foundation, so a capable agent doesn't bend logic to fit a weak one. Full rationale: `docs/agents/foundation.md`.

### The gate

- Before designing or building a non-trivial feature, module, mechanism, migration, or refactor, run `foundation-audit`. Skip only work that is clearly mechanical or local with no plausible architectural effect — and say in one line why the skip is safe.
- The audit's first objective is to **falsify** the foundation claims the work depends on, not to make the feature fit the current code at any cost. A foundation repair, a research blocker, or an evidence-backed no-go is a valid outcome; feature completion is not the only success.
- Classify the foundation as exactly one of `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, `FOUNDATION_BLOCKED`, and choose one justified route: Foundation-first, Bounded-compatibility, or Feature-first.
- Stop before implementation when the path would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. If active harm exists, apply the smallest containment first, then decide.

### Explain-the-invariant tripwire

- Before merging any change that touches the foundation, state the one canonical invariant it preserves — in a single plain sentence. If you cannot state it, the change is not ready and understanding debt has reached its limit: stop and resolve, don't merge.
- A handoff is not merge-ready unless the source of truth, the canonical invariant, the trusted foundation claims, the material failure modes, and every compatibility seam's lifecycle are explicit enough for an accountable maintainer to verify and explain.

### Independent check — triggered by facts, not by the self-rating

- Run `adversarial-foundation-review` in a **separate session** (ideally a different model) whenever an *observable condition* fires: the change touches a foundation surface (public API, schema, migration, auth, core domain, shared module), a mismatch signal appeared, or a wired fitness check regressed. The self-rating (`SUSPECT`/`BLOCKED`) is one trigger among these — never the only one. You must not be able to skip the second opinion by grading yourself `OK`.

### Machine-measured fitness (where a code stack exists)

- Structural health is enforced by fitness checks, not good faith: dependency direction, no cycles, layering, complexity, cross-boundary change-coupling. A claim rated `OK` should point at the check that enforces it. Green fitness checks are necessary, not sufficient — they prove no rule broke, not that the design is right.
- Hooks run these checks whether or not the agent wants them to. The surface-guard removes the self-grade escape — it fires on a changed surface file with no valid receipt naming it, making a skipped review visible and costly. In the default *advisory* mode the receipt is author-writable (records a decision, doesn't prove a review ran); the opt-in *attested* mode additionally requires a signed, trusted-reviewer attestation, and is only meaningful if the signing key lives outside the agent's reach and protected CI re-runs the check.

### Cumulative check

- Every few waves of work, run `foundation-health` in a session **separate from feature work**. The per-feature gate can pass repeatedly while the whole still drifts; this reads churn, open ADRs, and past receipts, trends them over time, and produces a remediation backlog ranked by hotspot × coupling.

### Record decisions

- For any Foundation-first or Bounded-compatibility route, write an ADR (`docs/adr/`) capturing the claim, the counter-evidence, the chosen route, and — for a temporary seam — its removal condition.

<!-- FOUNDATION-INTEGRITY:WORKFLOW-PACK-INTEGRATION
Included by setup-foundation-integrity only when a workflow pack was detected.
Remove this section if no such pack is installed. -->
### Workflow-pack integration

- Run `foundation-audit` in the seam between `to-spec` and `implement` / `tdd` / `prototype` — after the spec, before code.
- Give `code-review` a foundation lens: check the change against the mismatch signals in `docs/agents/foundation.md`, not only local standards.
- On a Foundation-first route, hand the repair to `improve-codebase-architecture` or `codebase-design`.
- These are reference lines, not a dependency. If the workflow pack is removed, they degrade to plain guidance and the gate still runs.
