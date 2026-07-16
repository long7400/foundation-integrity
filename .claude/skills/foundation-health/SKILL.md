---
name: foundation-health
description: Periodically audit cumulative foundation drift from churn, recurring seams, ADRs, receipts, and structural trends, separately from feature work.
disable-model-invocation: true
---

`foundation-audit` looks at one change at a time. But architectural erosion is *cumulative* — it accretes across changes that each looked fine in isolation. This skill takes the wide, slow view: it's the check that catches "each feature passed, but the system is quietly rotting."

Run it **separate from feature work** — a session with no feature to ship, so there's no pressure to rate the codebase healthy. Every few waves, or on a cadence.

## What to read

Use whatever signals the repo already has. All of these are available from `git` and file inspection alone — no stack-specific tools required:

1. **Churn / rework rate.** Files or modules changed-then-changed-again within a short window are a design-not-settled signal. `git log` over a recent window, grouped by path; flag the hottest paths. Migrations, schemas, and core domain files that keep getting reworked are the loudest.

2. **Recurring seams.** Grep the history and the current tree for the mismatch signals from `foundation-audit`: the same file touched by many "fix"/"workaround"/"temp"/"hack" commits; growing wrapper layers; duplicated domain types. A seam that shows up across many changes is systemic, not local.

3. **Open ADRs and temporary seams.** Scan `docs/adr/` (or wherever ADRs live) for Bounded-compatibility decisions marked *temporary*. For each, check: is its **removal condition** met yet? A temporary seam that's outlived its condition is now permanent debt nobody decided to accept.

4. **Past foundation receipts.** If prior `foundation-audit` runs left receipts, look for the same claim going `SUSPECT` repeatedly, or the same mismatch signal recurring. Repetition means the gate keeps flagging something nobody has repaired.

5. **Structural drift (if tooling exists).** If the repo has dependency-graph / duplication / complexity tools wired in, read their trend, not just their current pass/fail. Rising duplication or a new dependency cycle is the machine-measured version of the same story. If no such tooling exists, note that as a gap — don't install it here.

   The concrete git-only signals to trend live in the adopted file
   `docs/foundation/fitness/git-only.md` when fitness guidance is installed:
   cross-boundary change-coupling, churn
   hotspots, blast radius, workaround-marker density. Compute them from `git log`
   alone — no stack tooling needed.

## Trend, not snapshot — the OOD-drift proxy

You cannot measure directly whether "the agent is getting dumber" — that would need the model's perplexity over the codebase, which most runtimes don't expose. Don't claim to. What you *can* do is **trend the signals above over time**: rising cross-boundary coupling, rising churn on the same hotspots, rising workaround-marker density, rising blast radius. That upward slope is the honest, portable proxy for "the codebase is drifting away from clean, idiomatic structure." One reading is noise; the slope is the signal. This skill *prevents* deformation by catching the trend early — it does not claim to *measure* model capability.

## What to produce

A short **health report**, not a fix list:

- **Drift hotspots** — the paths/seams accumulating the most churn or the most workarounds, with the evidence (commit counts, the recurring signal).
- **Stale temporary seams** — Bounded-compatibility ADRs past their removal condition.
- **Recurring flags** — claims or mismatch signals that keep reappearing across receipts.
- **A ranked remediation backlog** — the one output that fitness signals uniquely enable. Rank candidate repairs by **hotspot × coupling**: a file that is *both* high-churn *and* high-complexity (or high cross-boundary coupling) is the best refactor ROI — it's where the pain concentrates and where a repair pays back most. A file that's hot but simple, or complex but stable, ranks lower. This prioritisation is the part machine signals do that a human reading code can't do at scale.
- **One recommendation per hotspot** — usually "route a Foundation-first repair here" or "this temporary seam needs a removal decision."

This skill *ranks and routes*; it does not repair. Hand the top backlog items to a repair/refactor skill (e.g. `improve-codebase-architecture` if a workflow pack is installed), each entering through `foundation-audit` like any other change. Prioritising is the job here; executing is not.

## What NOT to do

- Don't fix things inline. This is a diagnostic pass; repairs go through the gate like any other change.
- Don't install new tooling as a side effect. If a structural signal is missing, name the gap and leave the decision to the maintainer; this pack has no hidden setup phase.
- Don't rate the codebase healthy just because the last few features shipped clean. The whole point is to look past the per-feature view.
