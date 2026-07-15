---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle — consult them before and during the loop, not after.

When exploring the codebase, read `CONTEXT.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Choose the proof surface by the claim

Tests are one proof surface, not a ritual. Before writing one, name the claim and
choose the strongest evidence that observes its owner boundary: a reproducible
example, contract/integration test, validator, benchmark, visual check, runtime
observation, or explicit ownership evidence. Prefer proof that survives harmless
renames and internal refactors. If a validator or owner-boundary artifact proves the
claim more directly, do not add a weaker implementation-detail test just to satisfy
red-green ceremony.

For foundation-sensitive work, include a disconfirming probe or the cheapest
fake-pass path: a green test is insufficient when the same test can preserve the
wrong owner, archetype, wrapper, or synchronization mechanism.

The pack-wide claim-to-proof matrix is in `templates/fitness/proof-surface-selection.md`.
Use it when a repro, validator, benchmark, runtime trace, visual check, or owner
evidence is stronger than a test.

## Lock the contract before RED

Before writing the first failing test, record:

- the owner boundary or public interface;
- the first behavior or invariant;
- the observable failure signal that should be red; and
- what is deliberately out of scope for this slice.

Name the seam in the task record. Ask for clarification only when the seam or
contract is materially ambiguous, or when the change would alter ownership or a
public contract; do not turn an already explicit contract into a needless approval
round-trip.

## Seams — where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

Test only at the recorded seams. You cannot test everything; naming the seam keeps
effort on critical paths and complex behavior instead of every edge case.

Ask: "What's the public interface, and which seams should we test?"

## When a test is not the strongest proof

Do not force red-green ceremony for a refactor with unchanged behavior, a
pass-through wrapper, compile-keeping bridge, docs/config edit, visual-only change,
or performance claim whose primary evidence should be a benchmark. Keep the proof
at the long-lived owner boundary. Test a wrapper or bridge directly only when it
performs semantic translation, filtering, retry, fallback, caching, buffering,
ordering, or another contract expected to survive the transition.

## Relevant-test gate

Before keeping a test, answer:

1. What owner-boundary contract or invariant does it lock?
2. Would a harmless rename, extraction, data-structure swap, or internal refactor
   break it while behavior remains correct?
3. Is an adjacent owner proof already stronger or more direct?
4. Does the test name claim more than its assertion proves?
5. If this test disappeared, what concrete regression would escape?

If the answers point at helper names, private fields, source text, scratch layout,
or duplicate seam coverage, choose another proof surface.

## Anti-patterns

- **Implementation-coupled** — mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological** — the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth — a known-good literal, a worked example, the spec.
- **Horizontal slicing** — writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead — one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactor only while green.** After the proof passes, a small owner-clean refactor
  may run in the same cycle and must rerun the proof. A structural refactor that
  changes ownership, dependency direction, or the seam returns to
  `foundation-audit` before more implementation.

## Bridges and thin layers

Do not add dedicated tests merely because a temporary bridge or forwarding wrapper
exists. Strengthen the long-lived owner proof and record the bridge's removal
condition. Add direct bridge tests only for independent translation, policy,
fallback, retry, caching, buffering, ordering, or a durable compatibility contract.

## If code already exists before RED

Do not delete working code to satisfy a ritual. State what evidence is missing,
write the smallest boundary-facing failing test or repro that would falsify the
claim, then decide whether the missing piece is proof, scope, or a foundation
design issue. Recover honestly before extending the implementation.
