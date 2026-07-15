# Foundation Integrity — consumer rules

How the skills in this repo treat the foundation gate. This is the short operational reference; the *why* is in `why-foundation-integrity.md`.

## The gate, in one paragraph

Before building anything non-trivial, run `foundation-audit`. Its first job is to try to **prove the foundation wrong** — not to make the feature fit. Classify `FOUNDATION_OK` / `SUSPECT` / `BLOCKED`, pick one route (Foundation-first / Bounded-compatibility / Feature-first), and for the first two routes record an ADR. Stop before implementation if building would break an invariant, create a second source of truth, or entrench a known mismatch.

## Mismatch signals

Investigation triggers — not proof by themselves. If the work you're about to do would *add* one of these, that is the signal to stop:

- multiple compensating patches at the same seam
- wrapper-around-wrapper designs
- duplicated domain types, state, or control flow
- synchronized writes to two places that must agree
- cross-layer leakage; bypassed ownership
- feature-specific exceptions in shared code
- tests that exist to preserve a workaround
- behaviour about to be frozen into a public API, schema, or durable data
- you can't state one canonical invariant for the thing

## Evidence rules

- Code, tests, docs, ADRs, and runtime behaviour are **evidence, not automatic truth**. A characterization test says what the system *does*, not what it *should* do.
- For load-bearing claims, trace summaries / release notes / rollups back to **primary evidence**: the exact diff, commit, decision record, or runtime observation.
- Unknown load-bearing facts are **research blockers**, not assumptions. Resolve them before the dependent work proceeds, or record explicit user acceptance of the risk.

## The three checks

- **`foundation-audit`** — per change, before building.
- **`adversarial-foundation-review`** — separate session (ideally a different model), triggered by an *observable* condition (a foundation surface touched, a mismatch signal, a regressed fitness check), not only by a self-rated SUSPECT/BLOCKED.
- **`foundation-health`** — separate from feature work, every few waves, trends drift and produces a remediation backlog ranked by hotspot × coupling.

## Fitness checks — grade on artifacts, not confidence

Where a code stack exists, structural health is machine-measured (dependency direction, no cycles, layering, complexity, change-coupling) so violations trip without good faith. A claim rated `FOUNDATION_OK` should cite the artifact that enforces it — a passing check, a cited invariant, an exact diff — not "it looks right." An unverified load-bearing claim is `SUSPECT` by default. Green fitness checks are necessary, not sufficient.

## Hooks enforce it whether the agent wants it or not

Git hooks (runtime-neutral) and runtime hooks (Claude/Codex) run the checks at commit/push and mid-session. The surface-guard fires on the *fact* that a surface file changed with no valid v1 receipt/ADR naming its exact path — removing the self-grade escape and making a skipped review a visible, auditable act. Default *advisory* mode records that a decision was made (it does not prove an independent review ran); opt-in *attested* mode additionally requires a signed, trusted-reviewer attestation. See Residual limits in `why-foundation-integrity.md`.

## Explain-the-invariant tripwire

Before merging a foundation-touching change, state its canonical invariant in one plain sentence. Can't state it → not ready → stop.
