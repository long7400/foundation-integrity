# Foundation Integrity — repo guide

This repo is a dual-runtime agent-skills pack (Claude Code + OpenAI Codex). It adds a foundation gate to agent-driven engineering: prove the foundation is sound before building on it, instead of bending logic to fit a weak one.

## Repo invariants

- **Canonical source plus runtime projections.** `skills/` is the plugin-authoring
  source. `.claude/skills/` is the Claude project projection and must not contain
  Codex-only `agents/openai.yaml`; `.agents/skills/` is the Codex project projection
  and must contain the matching interface metadata. Regenerate both projections and
  run parity checks after every source change.
- **Standalone core, explicit companion boundary.** The three Foundation Integrity skills and root-owned protocol must work without any companion. This distribution may carry a commit-pinned companion under `skills/_third_party/` only when its license, allowlist, upstream hashes, explicit local patch ledger, update record, and removal test are present. Do not derive the foundation gate or coworker authority from the companion, and never patch vendored content without recording the research and hash change.
- **Portable skill bodies.** `SKILL.md` must not hardcode stack-specific tool names (no "Flyway", "ArchUnit", etc.). Stack-specific detail lives in `templates/` only. The skills stay tech-neutral. A `SKILL.md` may reference the fitness *intents* (dependency direction, no cycles, layering) and link to `templates/fitness/`; the concrete tool names (dependency-cruiser, ArchUnit, import-linter, go-arch-lint) live only in `templates/fitness/adapters/` and `templates/hooks/`.
- **Reasoning layer is backed by a measurement layer.** The gate depends on the running session's honesty, and an agent grading its own foundation hits a measured self-preference bias. So every good-faith check (`foundation-audit`, receipts, self-ratings) must be backed by something that needs no good faith — fitness functions and hooks in `templates/`. Don't ship a change that makes the pack rely on self-attestation alone.
- **Hooks stay proportional and dual-wired.** Hook scripts are shared (`templates/hooks/scripts/`); only the wiring differs per runtime (git / Claude `settings.json` / Codex `config.toml`). Keep default posture warn, scope to foundation-surface paths, and keep git-level enforcement runtime-neutral so switching runtime can't bypass it.
- **Protocol is not workflow.** A session backend may provide terminals, identity hints, status events, and resume pointers; it must not become the authority for task state, acceptance, evidence, or release decisions. Optional orchestration material stays transparent, replaceable, and outside the default setup path until measured pilots justify promotion.
- **Runtime parity without false equivalence.** Codex profiles and Claude launch envelopes implement the same role/model policy through different native configuration surfaces. Keep one transport-neutral contract, explicit runtime adapters, and parity checks over the architectural properties each must preserve.
- **Manifests stay in sync.** `.claude-plugin/plugin.json` `skills[]`,
  `.codex-plugin/plugin.json`, the marketplace, canonical `skills/`, and both runtime
  projections must expose the same 24 skill names (three first-party, 21 companion).
- **Runtime/process state is never canonical.** Ignore all `.foundation/` and `tmp/`
  content. Durable receipts, research conclusions, ADRs, domain docs, and acceptance
  evidence belong under `docs/` or `CONTEXT.md`, not in the orchestration workspace.
- **The pack obeys its own doctrine.** Single source of truth, recorded decisions, no unverified claims shipped as fact. If a change to this repo would violate that, it's a bug in the pack.

## Structure

```
.claude-plugin/     plugin.json + marketplace.json (Claude Code plugin manifests)
.codex-plugin/      plugin.json (Codex plugin manifest)
.claude/skills/     standalone Claude project-skill projection
.agents/skills/     standalone Codex project-skill projection
skills/             canonical plugin skill source: SKILL.md + agents/openai.yaml
  _third_party/     pinned companion snapshots; never a source of first-party authority
third_party/        provenance, license, hash locks, and patch ledgers for companions
templates/          explicit maintainer wiring and reusable policy templates
  claude-md-block.md    the operating-rules block injected into CLAUDE.md/AGENTS.md
  setup/                transparent helpers used to resolve setup ownership
  docs/                 consumer rules + the rationale write-up
  adr/                  ADR template
  fitness/              measurement layer: intent (tech-neutral) + git-only tier + per-stack adapters
  hooks/                enforcement layer: shared scripts + git / Claude / Codex wirings
  orchestration/        optional, experimental coworker protocol + runtime adapters
docs/               decisions and research evidence about this pack itself
tests/              repo-contract checks for ownership, parity, and template scripts
```

## Agent skills

### Issue tracker

GitHub Issues for `long7400/foundation-integrity`; see `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/`), with research and evidence kept
as canonical text; see `docs/agents/domain.md`.

### Triage labels

Use the five labels recorded in `docs/agents/triage-labels.md`; do not create a second
state vocabulary.

## Personal Operating Rules

### External Coworker Authority

- Exactly one root/main session owns external coworker launch, task-graph mutation, validation leases, acceptance, release, and teardown. The root chooses coworker count from independent dependency units; no fixed department size is policy.
- Native subagent/background delegation is disabled for this pack. Do not mix it with externally managed top-level coworkers, and do not silently fall back to it when the external runtime is unavailable; run the review locally or report the missing independent session. Root/lead launch envelopes disable native multi-agent tools. Non-root roles never delegate or supervise.
- Companion workflow skills may mention subagents, background agents, or parallel reviewers. Treat those as a request for root-owned independent work, not permission to open a second control plane. The root translates the intent into an open task packet; workers never receive transport topology, and implementers never self-approve.
- Shared instructions remain transport-neutral. Backend commands and topology belong only to the root/lead launch envelope; worker, implementer, peer, and reviewer prompts must not expose the backend protocol.
- Delegate with an open question and closed safety envelope. Do not pre-solve and ask a coworker to confirm; receive independent evidence before challenging or reconciling it.
- Model tier does not grant claim authority. Bounded/fast workers produce observations and artifacts, not final high-impact conclusions. Complex peers challenge independently; implementers cannot approve their own durable changes. Final acceptance stays with root.
- Monitoring is root/harness work, never a coworker role. Status events attract attention only; acceptance comes from the root record plus digest-bound artifacts and validation evidence.
- The pilot is fresh-session only until a full-envelope attestor and controlled resume test exist. Reject resume, continue, and fork for accepted work; a session reference is continuity, not authority.
- Root owns the live controller lock and canonical-validation lease. Preserve the exact worker output and transport transcript with content digests before synthesis. A write-capable actor requires an isolated worktree and a passed write-isolation smoke.
- Use the opt-in policy and adapters under `templates/orchestration/`; no setup skill
  installs or activates them automatically.

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
- Inspect the owning subsystem and the dependencies the change would load-bear on. Identify the requested outcome, ownership model, authoritative source of truth, lifecycle and trust boundaries, dependency direction, invariants, existing extension path, and intended versus observed behavior. Challenge the system archetype as well as the local implementation: expected category versus observed category, primary evidence for the simplest established alternative, the project constraint that justifies deviation, and the compensating complexity that would disappear. Use industry practice as comparative evidence, not as an automatic override of project constraints; if the comparison is load-bearing and trustworthy evidence is missing, return `RESEARCH_ONLY` rather than inventing a standard.
- Treat code, tests, documentation, ADRs, issues, and current runtime behavior as evidence, not automatic normative truth. Characterization tests establish what the system does, not what it should do. For load-bearing claims, trace generated summaries, release notes, and rollups to stable primary evidence such as the exact source diff, commit, decision record, or runtime observation.
- Produce a concise foundation receipt containing: requested outcome; foundation claims by dependency; decisive evidence and counterevidence; intended and observed behavior; confidence and unknowns; mismatch signals; blast radius; change amplification and coupling; public-contract or durable-data lock-in; reversibility; cognitive cost and recurring debt interest; and the architectural properties acceptance checks must preserve. Classify the foundation as exactly one of `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or `FOUNDATION_BLOCKED`, and record exactly one outcome: `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`. Only `PROCEED` permits feature implementation.
- Treat multiple compensating patches at the same seam, wrapper-around-wrapper designs, duplicated domain types, state or control flow, synchronized writes, cross-layer leakage, bypassed ownership, feature-specific exceptions, unrelated-module spread, tests that preserve workarounds, behavior about to be frozen into a public API, schema, or durable data, and inability to state one canonical invariant as mismatch signals. They are investigation triggers, not proof by themselves; numeric thresholds are project-specific heuristics. Account for cognitive debt as durable growth in concepts, paths, exceptions, and coordination that maintainers must understand.
- Optional shared names such as Balloon and Brake are mnemonics, never evidence. Use the semantic definitions and disconfirming probes in `templates/docs/foundation-pattern-language.md`; if a name does not change the claim, counterexample, or fitness check under investigation, drop the name.
- Unknown load-bearing facts are explicit research blockers, not implementation assumptions. Resolve bounded read-heavy research with a decision-lossless receipt containing primary evidence and uncertainty, and do not let dependent implementation proceed until the blocker is resolved or the user explicitly accepts the risk.
- Choose and justify exactly one implementation route:
  - **Foundation-first:** repair or introduce the missing primitive when the feature would otherwise deepen a systemic mismatch or make later correction materially harder.
  - **Bounded compatibility:** use the narrowest reversible seam when immediate foundation repair is disproportionately risky or broad, especially across a true external or legacy semantic boundary. Centralize translation at that boundary, prevent legacy semantics from leaking into the new domain, and require contract tests, ownership, observability, and an explicit lifecycle. State whether the seam is temporary or permanent; a temporary seam also requires a migration path and removal condition, while a permanent seam requires explicit acceptance of its architectural cost.
  - **Feature-first:** proceed directly only when evidence shows the foundation is sound and the change does not create a second authority, bypass ownership, or add another compensating exception.
- Stop before feature implementation when the proposed path would violate an invariant or trust boundary, create a second source of truth, require repeated exceptions, or materially entrench a known mismatch. If active harm exists, apply only the smallest necessary containment before the structural decision.
- Preserve explicit user-required outcomes, mechanisms, and sequencing. If the audit recommends changing one, surface the conflict and request direction rather than silently substituting a different design.
- Define architecture fitness checks for the actual property at risk, such as ownership, dependency direction, single source of truth, lifecycle, trust boundary, rollback, or removal path. Select the proof surface by the claim—repro, contract test, validator, benchmark, runtime observation, visual check, or owner-boundary evidence—and prefer proof that survives harmless internal refactors. Green feature tests are necessary but insufficient when they do not exercise those properties or when the cheapest fake-pass implementation can keep the wrong owner or archetype intact.
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
