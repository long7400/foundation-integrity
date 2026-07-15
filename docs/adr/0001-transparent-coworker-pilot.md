# ADR-0001: Keep coworker orchestration a transparent, optional pilot

- **Status:** accepted
- **Date:** 2026-07-15
- **Foundation route:** Foundation-first
- **Classification at decision time:** FOUNDATION_BLOCKED

## Context

The requested outcome was to study and improve this pack for a Herdr-based Codex coworker workflow: one root authority, independent top-level threads, role-specific Codex profiles rather than a Herdr skill in workers, open-ended delegation, evidence/test execution ownership, bounded monitoring, and no FirstMate installation.

The work load-bears on the pack's single-source-of-truth, dual-runtime, measurement-layer, transparency, and compose-don't-bundle invariants.

## Counter-evidence

- `CLAUDE.md` explicitly says the canonical repo guide is `AGENTS.md` and imports it with `@AGENTS.md`.
- Before this decision, `skills/setup-foundation-integrity/SKILL.md` selected `CLAUDE.md` whenever it existed. On this repo that could write a Foundation Integrity block into the forwarding shim and create a second authority.
- The sanitized [Herdr status observation](../research/2026-07-15-herdr-status-observation.md) records the version, commands, output shape, and uncertainty from the live pilot. It shows that a fresh worker may be `idle` and that rendered task completion can disagree with the detected status, so status cannot be acceptance evidence.
- Herdr source at commit [`d0111c9f9022e0ec26d8f03236a91b026b567d45`](https://github.com/ogulcancelik/herdr/commit/d0111c9f9022e0ec26d8f03236a91b026b567d45) reports Codex session identity and restores with plain `codex resume <id>` (`src/integration/assets/codex/herdr-agent-state.sh`, `src/agent_resume.rs`). This proves conversation continuity, not profile, sandbox, instruction, cwd, worktree, or authority continuity.
- FirstMate commit [`e063ca5e2459ea8cbcefb1d58310b3617318bfb8`](https://github.com/kunchenguid/firstmate/commit/e063ca5e2459ea8cbcefb1d58310b3617318bfb8) contains useful mechanisms—worktree isolation, durable metadata, event/poll fallback, provenance-aware teardown, and session locks—but also a large distro/state machine whose installation would violate the requested mechanism and increase blast radius.
- Independent read-only peer sessions disagreed on which proposed rules are invariants versus heuristics. The strongest counter-design keeps root global authority but permits bounded peer coordination; that remains an experiment, not pack doctrine.
- The five-panel exploratory run preceded the finalized contract, artifact-binding rules, and pilot receipt. It informed this decision but does not count as a compliant pilot run or promotion evidence.

## Decision

First repair instruction-file ownership with a transparent resolver and repo-contract tests.

Then provide an optional orchestration pilot under `templates/orchestration/`:

- a transport-neutral coworker protocol;
- a Herdr/Codex mapping using explicit profile overlays and no worker transport skill;
- a small TSV declaration contract plus a linter for one root, a root-bound current-state artifact, one validation lease, declared-disabled native subagents during the pilot, attention-only transport status, unique actors/artifacts, and typed non-overlapping implementer scopes;
- a per-run receipt that records the baseline, incremental value, coordination cost, provenance/resume failures, and root decision needed to remove or reconsider the pilot, plus a narrow validator binding it to the contract digest and root current-state path.

Do not add a new skill, change manifests, auto-wire the pilot in setup, install or vendor FirstMate, or claim that the checker measures reasoning quality. Shared skills may state transport-neutral review invariants, but the optional protocol and backend mapping stay outside them.

## Pilot lifecycle

Although the implementation route repairs the foundation first, the orchestration templates themselves are a **temporary bounded-compatibility seam**.

- **Migration path:** run small read-only pilots; preserve task packets, receipts, transport observations, and evidence artifacts; compare against the simplest permitted baseline using `templates/orchestration/pilot-run-receipt.md`.
- **Removal condition:** before each evaluation series, record a maintainer-chosen review window. Delete the orchestration templates if that window adds no material finding/traceability, loses provenance, misroutes messages, requires transport status as truth, or cannot revalidate the Codex launch authority envelope on resume.
- **Promotion condition:** only consider a public skill or setup wiring after repeated evidence establishes a stable contract, a trustworthy measurement seam, and material benefit over the simpler baseline.

## Canonical invariant

One canonical owner decides task state and acceptance; terminal/session mechanisms remain replaceable transport and never become a second authority.

## Consequences

The ownership bug is repaired before adding orchestration guidance. The pilot is reversible and does not change default consumer behavior. The cost is a small optional template/checker surface and the need to maintain primary-evidence pointers for Herdr/Codex resume behavior. A full workflow engine, monitor daemon, or role hierarchy remains explicitly out of scope.
