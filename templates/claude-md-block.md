<!-- BEGIN foundation-integrity -->
## Foundation Integrity

- Before a non-trivial feature, module, mechanism, migration, refactor, or
  security/reliability/performance change, load `foundation-audit`. Skip only clearly
  mechanical/local work and state why.
- Try to falsify the foundation before making the feature fit. Check the owner,
  authoritative source, lifecycle, trust boundaries, dependency direction,
  invariants, intended versus observed behavior, and the simpler established system
  archetype when that comparison is material.
- Treat existing code, tests, docs, and runtime behavior as evidence, not automatic
  truth. Unknown load-bearing facts require bounded research, not an implementation
  assumption.
- Record exactly one classification (`FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or
  `FOUNDATION_BLOCKED`), one outcome (`PROCEED`, `RESEARCH_ONLY`, or `NO_GO`), and
  one route (Foundation-first, Bounded compatibility, or Feature-first). Only
  `PROCEED` unlocks dependent implementation.
- Stop if the path would create a second authority, bypass ownership or a trust
  boundary, require repeated exceptions, or freeze a known mismatch into a public or
  durable contract. Foundation repair is a valid successful outcome.
- Select acceptance proof for the architectural property at risk. Green feature
  tests are necessary but insufficient when a cheap fake pass can preserve the wrong
  owner, archetype, or compatibility residue.
- A foundation-surface change, mismatch signal, or regressed fitness check requires a
  fresh independent `adversarial-foundation-review`. The implementer cannot approve
  its own durable work.
- Keep accepted decisions and evidence in canonical text. Working `.foundation/`,
  `docs/research/`, and `tmp/` state is not authoritative.

Optional external coworker orchestration is not a skill or default workflow. Load its
policy and runtime adapter only when explicitly requested. One root owns acceptance;
native subagents stay disabled for that run; workers receive no transport topology;
transport status is never proof.
<!-- END foundation-integrity -->
