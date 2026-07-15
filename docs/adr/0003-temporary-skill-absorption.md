# ADR 0003: Absorb useful temporary-skill mechanisms, then delete the scratch sources

- Status: Accepted
- Date: 2026-07-16
- Base revision inspected: `ee082006cd552e21e070c13f7dc7ad476f592656`

## Context

The user supplied five temporary skill bundles under ignored `tmp/` and asked the
pack to research and merge useful mechanisms without creating duplicate workflow
phases. Before deleting those exploratory inputs, the repository rules require a
decision-lossless record of the question, verdict, rationale, evidence, and stable
source identity.

The governing question was not "can every file be copied?" It was: which mechanisms
improve the two primary outcomes—preventing strong agents from building polished
features on weak foundations, and keeping coworker orchestration transparent and
root-owned—without adding a second owner, unsafe executable, or conflicting control
plane?

## Decision

Use the existing skill owners and do not publish five additional phases:

- `misfit-detector` is absorbed by `foundation-audit` and `codebase-design` through
  expected/observed/canonical-archetype comparison and explicit missing-evidence
  stops.
- `plan-review` is absorbed by `code-review`, `foundation-audit`, and
  `adversarial-foundation-review` through fake-pass construction, independent open
  challenge, owner/lifecycle/proof analysis, and separation of solution correctness
  from document readiness. Its hard-coded native reviewer mechanism is rejected.
- `goal-crafter` is absorbed by `to-spec` as a compact outcome, evidence,
  constraints, boundaries, iteration, and blocked-stop contract. Its second goal
  phase and native fork/session mechanics are rejected.
- `test-driven-development` is absorbed by the existing `tdd` owner. The final
  residual guidance is now in `tdd/tests.md` and `tdd/mocking.md`: do not add a
  production API solely for tests, trace required dependency effects before mocking,
  and keep doubles faithful to an authoritative contract. The source rule requiring
  every response field was intentionally narrowed: omitted irrelevant optional data
  is acceptable when the exercised contract remains faithful and a stronger
  contract or larger-scope proof covers the boundary.
- `review-pack` is not shipped as a skill or executable. Its safe artifact-contract
  ideas—target-driven scope, dry-run visibility, included/skipped/missing paths,
  immutable revision binding, per-file and aggregate hashes, separate prompts, and
  fail-closed handling—are owned by `code-review`. The supplied Python packager is
  permanently rejected in its current form because it follows selected symlinks,
  has no secret-deny boundary, can report missing requested paths while still
  completing successfully, and lacks the aggregate digest required by the published
  contract. Its language profiles, ZIP/excerpt workflow, and Rust enrichment are
  implementation details of that rejected tool, not accepted product requirements.
  A future packager must be designed as a separately owned, tested, fail-closed tool;
  this source is not its foundation.

After this record, projection sync, and full contract validation, the ignored `tmp/`
tree is safe to delete. Deletion means "absorbed or explicitly rejected," not "copied
verbatim."

## Research basis for the TDD changes

- Google, *Software Engineering at Google*, chapter 12, "Unit Testing": tests should
  exercise public APIs rather than implementation details, so harmless refactors do
  not require test changes.
  <https://abseil.io/resources/swe-book/html/ch12.html>
- Google, *Software Engineering at Google*, chapter 13, "Test Doubles": fidelity is
  behavioral similarity to the real implementation; low-fidelity doubles can make
  tests worthless, real implementations are preferred when practical, and larger
  scope tests must cover unavoidable fidelity gaps.
  <https://abseil.io/resources/swe-book/html/ch13.html>
- Martin Fowler, "Mocks Aren't Stubs": mock expectations can mask inherent errors,
  and adding methods to an object's API purely for testing is an acknowledged design
  discomfort rather than a free testing convenience.
  <https://martinfowler.com/articles/mocksArentStubs.html>

These sources support the mechanism, but not the temporary file's absolute "include
all fields" prescription; contract fidelity is the durable invariant.

## Temporary source identity

| Source | SHA-256 | Disposition |
| --- | --- | --- |
| `tmp/review-pack/SKILL.md` | `4d77204d9ca166ec8e6f8404d8628d1692ff690a5de1bdf8134be95d9d2dce13` | Safe contract ideas absorbed; packaging phase rejected |
| `tmp/review-pack/agents/openai.yaml` | `a7cac694245d9130dd87a71877ea665f45182541ea9ef514716c764092522fa5` | Duplicate skill interface rejected |
| `tmp/review-pack/references/profiles.md` | `7682eaf925ce88a4e6b5b88ea30560428aa8d9cdd8f3dc0c63f10146cdb81fbe` | Rejected-tool implementation detail |
| `tmp/review-pack/scripts/review_pack.py` | `3ee9928ab3c950dcb487aadc72aa14468417afecbbef610a7b82963c2be88aa1` | Unsafe/unvalidated executable rejected |
| `tmp/skill/goal-crafter/SKILL.md` | `08d4b021101d7ce895387d661dd1e0407420a3b879b7cd151bf8e3924c055f2e` | Core contract absorbed by `to-spec` |
| `tmp/skill/goal-crafter/agents/openai.yaml` | `168885b787c7111532ac9b8ef1e56f4747409a7d4a45e4b4ea431c02db65505d` | Duplicate interface rejected |
| `tmp/skill/misfit-detector/SKILL.md` | `c8db1cfdc54e1a8c96e6a1a41c33ac30e416f37a96935367f176b2c4f198e54c` | Mechanism absorbed by existing owners |
| `tmp/skill/misfit-detector/agents/openai.yaml` | `dd0285e819bbb3a7f2f7fa9c367b6e3b6beb7b02722d901f61eb7a57f6b1c671` | Duplicate interface rejected |
| `tmp/skill/plan-review/SKILL.md` | `70ab06d248c9de5d4ff881da18017d90cda1c6d7556470e36c41a0b3429cf840` | Core review mechanisms absorbed |
| `tmp/skill/plan-review/agents/openai.yaml` | `280bf2d6ca55ad5adf1b358c7939f323a885e4a04136aac6409e9e4ac50bb981` | Conflicting native-reviewer mechanism rejected |
| `tmp/skill/test-driven-development/SKILL.md` | `d036a44451893f63e9d134d4821c341600f27335eef40215c1b555edea61973e` | Absorbed by `tdd` and proof-surface templates |
| `tmp/skill/test-driven-development/agents/openai.yaml` | `4593a4245a62967d95f464176cd95d6fbd4090feedad256da99b8352dea2d201` | Absorbed by the existing `tdd` interface |
| `tmp/skill/test-driven-development/testing-anti-patterns.md` | `bde453bc258f06543987477c837939afaa774ea2acbd9f308d702fc452bc4283` | Useful rules researched, narrowed, and absorbed |

## Foundation receipt

- Requested outcome: remove scratch inputs without losing accepted mechanisms or
  creating a second workflow/control authority.
- Canonical invariant: every accepted mechanism has one published owner; every
  excluded mechanism has an explicit rationale and stable source hash.
- Intended and observed behavior: `skills/` owns 24 canonical plugin skills; runtime
  projections mirror them; no temporary skill is published independently.
- Decisive counterevidence: the review-pack executable and three testing rules were
  initially not fully closed. The executable is now explicitly rejected and the test
  rules are absorbed after research.
- Mismatch signals avoided: duplicate phases, native subagent control, unsafe
  archives, self-attested artifact integrity, and widened production APIs for tests.
- Blast radius: TDD guidance, patch provenance, runtime projections, and README
  onboarding. No runtime code or consumer project is mutated automatically.
- Reversibility: source hashes and dispositions make the decision auditable; future
  changes can restore a mechanism from its original source only through a new
  researched decision.
- Cognitive/debt effect: one owner per phase is preserved; the rejected packager does
  not become an untested security boundary.
- Classification after absorption: `FOUNDATION_OK`.
- Route: Foundation-first—close provenance and proof gaps, then delete `tmp/`.
- Acceptance checks: manifest/projection parity, pinned-file hashes, repo contracts,
  strict Claude plugin validation, Markdown/link checks, and a clean diff check.

## Consequences

The pack gains the useful testing safeguards without a duplicate TDD skill. Users do
not receive the review-pack executable or its profile-specific packaging features.
The ignored `tmp/` directory remains a disposable input surface, never a second
source of truth.
