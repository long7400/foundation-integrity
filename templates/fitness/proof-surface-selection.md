# Proof-surface selection

Choose evidence from the claim that must be falsified. Tests are one proof surface,
not the definition of proof.

## Selection rule

For each acceptance claim, answer:

1. What observable failure would prove this claim false?
2. Which owner or public boundary can expose that failure without depending on private
   helper names or internal container shape?
3. What is the narrowest repeatable artifact that produces a clear red/green result?
4. Would the artifact survive a harmless rename, extraction, data-structure swap, or
   internal refactor while the behavior remains correct?
5. Does another adjacent proof already cover the same failure more directly?

If the proposed evidence cannot falsify the claim, choose another surface.

## Match the surface to the claim

| Claim | Prefer | Avoid as the primary proof |
| --- | --- | --- |
| Bug or deterministic regression | minimal repro or failing behavior test | broad suite that can fail for unrelated reasons |
| Public behavior or domain invariant | contract/integration test at the owning interface | tests of forwarding wrappers or private helpers |
| Protocol, schema, or wire compatibility | round-trip/golden record, schema validator, compatibility fixture | enum arithmetic, source-text grep, handwritten duplicate layout facts |
| Ownership or dependency direction | architecture rule, import/dependency check, owner-boundary test | feature happy-path test that never observes the dependency |
| Migration, persistence, or rollback | migration rehearsal, invariant query, rollback/restore exercise | compile-only proof or a mocked repository |
| Security or trust boundary | negative authorization/rejection path with realistic boundary data | internal method test that bypasses the boundary |
| Concurrency, ordering, or lifecycle | deterministic scheduler/replay, state-machine invariant, runtime trace | sleeps, timing luck, or mocks of the owned module graph |
| Performance or resource budget | benchmark/profile with correctness guard and contamination notes | unit tests that pin scratch size, pointer identity, or container choice |
| UI or visual behavior | interaction/accessibility assertion, browser inspection, screenshot evidence | unit tests for copy, CSS selectors, or implementation details |
| Docs or mechanical artifact | parser/linter/build/render check | a large behavioral suite unrelated to the changed artifact |

## Compatibility and bridge code

A compatibility seam is not exempt from proof. Test it directly when it performs
semantic translation, filtering, fallback, retry, caching, buffering, ordering, or a
durable policy. If it only forwards calls while an owner transition is in progress,
keep the main proof on the long-lived owner contract and require the seam's removal
condition to be machine- or receipt-visible.

## Test doubles

Use a double at a real external boundary—remote service, clock, randomness, network,
or storage when a controlled local implementation is impractical. Do not mock the
project's owned module graph merely to make a test easy; that can make the fake
architecture pass while the real owner path stays broken.

## Evidence receipt

Record the claim, selected surface, red condition, observed result, revision/input,
and residual limits. A green artifact proves only the property it exercised. It does
not prove that the system chose the right archetype or that every foundation claim is
sound.
