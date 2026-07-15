# Local patch ledger

The vendored Matt Pocock skill snapshot starts from the commit recorded in
`UPSTREAM.json`, then applies the explicit, bounded integration patches recorded
below. The upstream setup skill is excluded because this pack is already configured.

Any future modification to vendored content requires, in the same change:

1. a research record explaining the incompatibility or defect;
2. the upstream path and old/new SHA-256;
3. why a first-party instruction or runtime adapter cannot solve it;
4. dual-runtime and two-primary-problem regression evidence; and
5. an updated `promoted-files.sha256` manifest.

## Current patches

- `codebase-design/SKILL.md`: absorbs the tmp misfit-detector's expected/observed/
  canonical archetype comparison and missing-evidence stop.
- `code-review/SKILL.md`: absorbs plan-review's fake-pass construction, solution-
  correctness/readiness separation, open-question delegation rule, and review-artifact
  safety ledger; removes the retired setup dependency.
- `tdd/SKILL.md` and `tdd/agents/openai.yaml`: absorb the temporary
  test-driven-development input's claim-to-proof selection, contract-before-RED
  record, relevant-test gate, thin-wrapper/temporary-bridge rules, honest recovery
  when code predates RED, and disconfirming fake-pass probe. The canonical owner
  remains `tdd`; no second `test-driven-development` phase is published.
- `tdd/tests.md` and `tdd/mocking.md`: absorb the remaining temporary testing
  guidance after source review: do not widen a production API solely for test
  arrangement/inspection; understand required dependency effects before replacing
  them; and keep doubles faithful to an authoritative contract. The temporary rule
  to include every field verbatim was narrowed because fidelity concerns behavior
  and contract, not irrelevant fixture bulk. Research basis: Google, *Software
  Engineering at Google*, chapters 12 and 13, and Martin Fowler, *Mocks Aren't
  Stubs*. Old/new SHA-256: `tests.md`
  `859f9e592c188fda4fc7277dd180e4ce9c7a2e13f6efe1f6f29eccc9d28c106a` →
  `a858f464ccecc67d845e976cd0512527ea0af63d63f1e989166b8053d721aa22`;
  `mocking.md`
  `3ceb807fdf4a47d6a93d4d9a891e5ba6d362a6247bd08adc451feebfc17361ef` →
  `e32c9de3a3b7472f5358b72fde52bf13f365b4a3eba674af1d2b495f1a9e1d54`.
- `to-spec/SKILL.md`: absorbs goal-crafter's compact outcome/evidence/constraints/
  boundaries/iteration/blocked-stop contract without importing `/goal` or native
  subagent mechanics.
- `ask-matt`, `triage`, `to-tickets`, and `wayfinder`: replace the retired setup
  invocation with the preinstalled `docs/agents/` configuration.
- `ask-matt` and `to-tickets`: route every non-trivial build through
  `foundation-audit`, include the separate cumulative `foundation-health` flow, and
  replace autonomous ticket-grabbing language with root-assigned ready work. This
  preserves one task-graph authority in both single- and multi-session use.
  Old/new SHA-256: `ask-matt/SKILL.md`
  `2e307ae97700b9c84120be1236b9a3ca23072ca2740118ce2c94b82461f20621` →
  `7fefffc431fc8246528f7520a1d96824e130e0c4fba7de15b1e12d578268a8db`;
  `to-tickets/SKILL.md`
  `d2e78bf65a4b31e16290a7ab17e5f0b52089933f16534062779d03e19ad3a422` →
  `418f53cc485c37338cd0570b8a0f9451386cc9c071cf8bba1d9bfb335f6f15aa`.
- `to-spec/SKILL.md`: distinguish a speculative temporary bridge from a centralized
  semantic adapter at a true external/legacy boundary selected by the foundation
  gate. Old/new SHA-256:
  `533fbf31e6fa7e97654e20b92826ce88505ea8e93d35f8737d0d2efddfdb4705` →
  `ced8694acf484341873487fc8d48d803a58eb33912c3e58fe61a6e7b739d4b62`.
- `code-review/SKILL.md`: make the foundation/fake-pass review fail-closed with a
  canonical invariant, proof surface, compatibility lifecycle, and explicit CLEAR or
  BLOCKED architecture verdict. This prevents a descriptive review or green feature
  test from silently approving the wrong owner/archetype. Old/new SHA-256:
  `b029aa036b939f5c6eca96fabaad329aa73602561a81f06873711567123e3484` →
  `b7da3c7649269e561db860e2e55fbf674360f05265a4fe5d639d0b3c9e93721b`.
- `research`: translates native/background delegation into root-owned top-level
  coworker packets or local work and makes `docs/research/` an ignored working
  surface whose accepted conclusions must be promoted to canonical records.
- `improve-codebase-architecture` and `codebase-design/DESIGN-IT-TWICE.md`: translate
  native/background/parallel-agent requests into root-owned top-level coworker
  packets or local work; workers never learn transport topology.

`review-pack` was not copied or executed. Its safe concepts are represented in the
code-review artifact contract; its untested packaging script, secret/symlink risks,
and incomplete-success behavior remain intentionally excluded.

The temporary-source absorption and rejection record, including exact source hashes,
is [`docs/adr/0003-temporary-skill-absorption.md`](../../docs/adr/0003-temporary-skill-absorption.md).

Prefer updating to a reviewed upstream commit over growing local patches. Re-evaluate
each patch against the two primary problems and remove it when upstream provides an
equivalent, safer mechanism.
