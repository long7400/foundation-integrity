# Official-document reconciliation — 2026-07-15

## Decision

The seven previously reported remediation priorities remain supported. The strongest alternative is simpler: use managed runtime requirements and protected external CI for hard security/acceptance boundaries, while keeping this pack's Herdr transport pilot transparent and advisory. The repository changes below improve local evidence integrity and fail closed where the pack can do so, but they do not turn profiles, instructions, local hooks, or receipts into a security boundary.

## Primary evidence

- Codex configuration precedence: CLI/`--config` overrides project config, which overrides selected profiles and user config. Profiles are overlays, not immutable role authority. (Official Config Basics — Configuration Precedence.)
- Codex hooks: non-managed hooks require trust and can be disabled; managed hooks and `requirements.toml` are the stronger enforcement seam. (Official Hooks — Review and Trust; Configuration Reference — Admin Requirements.)
- Codex app-server resume: restoring a thread restores conversation continuity; it does not by itself attest the complete launch envelope. (Official App Server — Start or Resume a Thread.)
- Codex sandbox/approval guidance: sandbox capability and approval prompting are separate controls. (Official Agent Approvals and Security — Sandbox and Approvals.)
- Claude Code settings, permissions, hooks, subagents, and CLI lifecycle docs were checked at the current official documentation pages; the installed CLI also confirms explicit model/effort, settings-source, tool allow/deny, strict-MCP, fresh session, and resume/fork flags.

## Reconciliation against the seven priorities

1. **Credential permissions — upheld.** The local Claude settings file contained credential-bearing values and was world-readable. The pack now ships a metadata-only permission checker; the live file is fixed to owner-only mode (`0600`). Same-user agent-process exposure remains an explicit limitation.
2. **Receipt/self-attestation binding — upheld.** The surface guard now requires v2 receipts bound to the checked revision, changed-content SHA-256 manifest, evidence refs, reviewer, classification, route, and explicit outcome. Advisory mode still does not prove independent cognition.
3. **Root ownership/locks/provenance — upheld.** Contracts require root ownership for validation, remove monitor as a coworker role, and require root-side monitoring. A transparent controller lock plus digest-bound current-state, worker, and transcript artifacts is provided; stale takeover is intentionally manual.
4. **Fresh sessions/write smoke — upheld with boundary.** The pilot contract is `fresh-only`; resume/continue/fork is rejected until a full-envelope attestor exists. Write-capable roles require an isolated-worktree/write-isolation smoke recorded as evidence. Prompted scope remains non-authoritative without OS/runtime isolation.
5. **Explicit no-go and audit timing — upheld.** Foundation audit now records `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`; only `PROCEED` permits implementation. Guidance runs before architecture is frozen, not after a spec has already anchored the design.
6. **Monitoring outside worker authority — upheld.** The contract and protocol make monitoring a root/harness concern and keep transport status attention-only. No worker is allowed to become a second controller.
7. **Baseline benchmark — upheld as a pilot gate.** A weak-foundation benchmark template now requires a same-snapshot simple baseline, preserved artifacts, exact validation evidence, coordination cost, and incremental value before retaining the pilot.

## Residual blockers

- Local hooks remain bypassable; protected CI, branch/ruleset controls, managed requirements, and external reviewer keys are required for merge/release-grade enforcement.
- Codex/Claude effective runtime state is still not fully attestable by the checked-in declaration validators. Upgrade smoke tests remain required.
- The repository has no completed repeated benchmark series yet, so the pilot is not promoted from opt-in advisory status.
