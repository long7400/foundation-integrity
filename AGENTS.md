# Foundation Integrity — repo guide

This repo is a dual-runtime agent-skills pack (Claude Code + OpenAI Codex). It adds a foundation gate to agent-driven engineering: prove the foundation is sound before building on it, instead of bending logic to fit a weak one.

## Repo invariants

- **Dual-format parity.** Every skill is one `skills/<name>/SKILL.md` (shared by both runtimes) plus `skills/<name>/agents/openai.yaml` (the Codex interface). If a skill's purpose changes, update both — they must not drift.
- **Compose, don't bundle.** Never vendor, copy, or fork another pack's files (e.g. `mattpocock/skills`). Integration with another pack is reference lines only, so removing that pack degrades gracefully and never breaks this one.
- **Portable skill bodies.** `SKILL.md` must not hardcode stack-specific tool names (no "Flyway", "ArchUnit", etc.). Stack-specific detail lives in `templates/` only. The skills stay tech-neutral. A `SKILL.md` may reference the fitness *intents* (dependency direction, no cycles, layering) and link to `templates/fitness/`; the concrete tool names (dependency-cruiser, ArchUnit, import-linter, go-arch-lint) live only in `templates/fitness/adapters/` and `templates/hooks/`.
- **Reasoning layer is backed by a measurement layer.** The gate depends on the running session's honesty, and an agent grading its own foundation hits a measured self-preference bias. So every good-faith check (`foundation-audit`, receipts, self-ratings) must be backed by something that needs no good faith — fitness functions and hooks in `templates/`. Don't ship a change that makes the pack rely on self-attestation alone.
- **Hooks stay proportional and dual-wired.** Hook scripts are shared (`templates/hooks/scripts/`); only the wiring differs per runtime (git / Claude `settings.json` / Codex `config.toml`). Keep default posture warn, scope to foundation-surface paths, and keep git-level enforcement runtime-neutral so switching runtime can't bypass it.
- **Manifests stay in sync.** `.claude-plugin/plugin.json` `skills[]` and `.claude-plugin/marketplace.json` must match the actual `skills/` directories.
- **The pack obeys its own doctrine.** Single source of truth, recorded decisions, no unverified claims shipped as fact. If a change to this repo would violate that, it's a bug in the pack.

## Structure

```
.claude-plugin/     plugin.json + marketplace.json (Claude Code plugin manifests)
skills/             one dir per skill: SKILL.md + agents/openai.yaml
templates/          what setup writes into a target repo
  claude-md-block.md    the operating-rules block injected into CLAUDE.md/AGENTS.md
  docs/                 consumer rules + the rationale write-up
  adr/                  ADR template
  fitness/              measurement layer: intent (tech-neutral) + git-only tier + per-stack adapters
  hooks/                enforcement layer: shared scripts + git / Claude / Codex wirings
```

## Personal Operating Rules

### Priority and Claim Preservation

- Follow instruction hierarchy and scope. Within it, an explicit user command outranks skills, playbooks, defaults, and operating doctrine. Never let lower-priority guidance silently override it.
- Preserve the requested outcome and every mechanism, tool, model, workflow, or property on which it depends. Adjacent mechanism Y is not fulfillment of required mechanism X. If X is unavailable, state the exact blocker; propose Y only as a reduced alternative and do not implement it without user acceptance.

### Runtime Invariants

- Keep the session's configured model and thinking/reasoning effort as set unless the user explicitly changes them.
- Preserve the configured context-window and auto-compaction settings; do not replace them with catalog defaults without explicit approval.
- Keep any reviewed base-instruction or system-level override in place until there is a verified upstream fix or explicit user acceptance. `CLAUDE.md`, skills, and hooks are additive or post-dispatch mechanisms, not equivalent replacements for a required override. Remove an override only after a verified fix or explicit user acceptance of the changed claim.

### Foundation Integrity Gate

- Before designing or implementing a non-trivial feature, module, mechanism, migration, refactor, or security, reliability, or performance change, perform a proportional foundation audit. Skip only work that is clearly mechanical or local with no plausible architectural effect, and state why the gate is safely skipped.
- The audit's first objective is to falsify the foundation claims the requested work depends on, not to make the feature fit the current code at any cost. A foundation repair, explicit research blocker, or evidence-backed no-go is a valid outcome; feature completion is not the only successful result.
- Inspect the owning subsystem and the dependencies the change would load-bear on. Identify the requested outcome, ownership model, authoritative source of truth, lifecycle and trust boundaries, dependency direction, invariants, existing extension path, and intended versus observed behavior. Use industry practice as comparative evidence, not as an automatic override of project constraints.
- Treat code, tests, documentation, ADRs, issues, and current runtime behavior as evidence, not automatic normative truth. Characterization tests establish what the system does, not what it should do. For load-bearing claims, trace generated summaries, release notes, and rollups to stable primary evidence such as the exact source diff, commit, decision record, or runtime observation.
- Produce a concise foundation receipt containing: requested outcome; foundation claims by dependency; decisive evidence and counterevidence; intended and observed behavior; confidence and unknowns; mismatch signals; blast radius; change amplification and coupling; public-contract or durable-data lock-in; reversibility; cognitive cost and recurring debt interest; and the architectural properties acceptance checks must preserve. Classify the foundation as exactly one of `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or `FOUNDATION_BLOCKED`.
- Treat multiple compensating patches at the same seam, wrapper-around-wrapper designs, duplicated domain types, state or control flow, synchronized writes, cross-layer leakage, bypassed ownership, feature-specific exceptions, unrelated-module spread, tests that preserve workarounds, behavior about to be frozen into a public API, schema, or durable data, and inability to state one canonical invariant as mismatch signals. They are investigation triggers, not proof by themselves; numeric thresholds are project-specific heuristics. Account for cognitive debt as durable growth in concepts, paths, exceptions, and coordination that maintainers must understand.
- Unknown load-bearing facts are explicit research blockers, not implementation assumptions. Resolve bounded read-heavy research with a decision-lossless receipt containing primary evidence and uncertainty, and do not let dependent implementation proceed until the blocker is resolved or the user explicitly accepts the risk.
- Choose and justify exactly one implementation route:
  - **Foundation-first:** repair or introduce the missing primitive when the feature would otherwise deepen a systemic mismatch or make later correction materially harder.
  - **Bounded compatibility:** use the narrowest reversible seam when immediate foundation repair is disproportionately risky or broad, especially across a true external or legacy semantic boundary. Centralize translation at that boundary, prevent legacy semantics from leaking into the new domain, and require contract tests, ownership, observability, and an explicit lifecycle. State whether the seam is temporary or permanent; a temporary seam also requires a migration path and removal condition, while a permanent seam requires explicit acceptance of its architectural cost.
  - **Feature-first:** proceed directly only when evidence shows the foundation is sound and the change does not create a second authority, bypass ownership, or add another compensating exception.
- Stop before feature implementation when the proposed path would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. If active harm exists, apply only the smallest necessary containment before the structural decision.
- Preserve explicit user-required outcomes, mechanisms, and sequencing. If the audit recommends changing one, surface the conflict and request direction rather than silently substituting a different design.
- Define architecture fitness checks for the actual property at risk, such as ownership, dependency direction, single source of truth, lifecycle, trust boundary, rollback, or removal path. Green feature tests are necessary but insufficient when they do not exercise those properties.
- Review according to architectural leverage rather than reading every generated line uniformly. Give full scrutiny to domain invariants and sources of truth; module interfaces and dependency direction; adapters and translation; schemas, migrations, and persistent state; security, transaction, and concurrency boundaries; behavior-defining tests; and rollback, migration, and deletion paths. Automation or sampling is acceptable for mechanical boilerplate.
- Do not declare implementation ready for merge or handoff unless the handoff makes the source of truth, canonical invariant, trusted foundation claims, material failure modes, and every compatibility layer's lifecycle explicit enough for an accountable maintainer to verify and explain. For a high-impact or externally durable `FOUNDATION_SUSPECT` or `FOUNDATION_BLOCKED` decision, apply the strongest-alternative challenge in Task-Graph Reconciliation to challenge the claims and selected route.
- Feed the classification, selected route, evidence, blockers, debt, reversibility, and fitness checks into Task-Graph Reconciliation; do not create a second planning hierarchy. This gate is self-contained operating policy: skills may augment it but must never be required for it to run.

### Evidence and Decision Records

- Reports may be concise but must be decision-lossless: preserve outcome, decisive evidence and counterevidence, validation, uncertainty, deviations, unlocked dependencies, absorption coverage, and downstream implications. Never request hidden chain-of-thought.
- Keep canonical instructions, decisions, acceptance criteria, and exact evidence as text. Images may aid lossy memory, logs, traces, or architecture; never replace the text source.
- Treat release notes, generated rollups, and tracker summaries as indexes rather than primary evidence for load-bearing claims. Prefer immutable source commits, diffs, decision records, and stable references; do not rely on a moving or force-pushed branch alone.
- Before deleting or collapsing an exploratory artifact, preserve its question, verdict, rationale, decisive evidence, and stable context pointer in canonical text. Keep runnable exploration off the production path, and absorb only validated conclusions into implementation.

### Task-Graph Reconciliation

- Plan with a dependency-and-absorption graph, not a P-label queue. Order by explicit user sequence and immediate containment, then dependency unlocks, foundation leverage, durable implementation shape, absorption or supersession, risk, reversibility, and evidence. P0/P1/P2 are evidence, never the sole sort key.
- A lower-labelled foundation may precede a higher-labelled dependent task only when recorded evidence identifies the unlock path and material durable benefit. If active harm exists, apply the smallest necessary containment first; then build the foundation and structural fix.
- Reconcile after each execution wave, roughly every three to four completed tasks, and whenever evidence changes dependencies or acceptance coverage. For a high-impact foundation route, ordering, or absorption decision that remains materially ambiguous, record the strongest alternative from the evidence and decide explicitly rather than averaging opinions.
- If Y fully covers X's acceptance criteria, remove X from active execution and mark it absorbed or superseded instead of implementing both. Close an external work item only when the workflow authorizes that state change; otherwise report the coverage evidence and recommend closure.
- Run dependent units sequentially, and overlapping writes sequentially or with explicit ownership. Independent units may be fanned out to separate sessions by the harness (e.g. a harness that opens another tab); do not spawn sub-agents to parallelize. Do not create hierarchy or reconciliation ceremony for trivial work.
