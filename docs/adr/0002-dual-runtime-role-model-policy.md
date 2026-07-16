# ADR-0002: Use one role/model policy with explicit Codex and Claude adapters

- **Status:** superseded by ADR-0004
- **Date:** 2026-07-15
- **Foundation route:** Foundation-first
- **Classification at decision time:** FOUNDATION_SUSPECT

## Context

The user requires the coworker pilot to work with either Codex or Claude, remove the shared Herdr skill from both runtimes, keep controller behavior in instructions, and bind an approved role/model set while allowing root to choose coworker count per task.

The design must preserve one authority, worker ignorance of backend protocol, native-subagent exclusion, project instruction discovery, model/effort transparency, and no global-default overwrite.

## Evidence and counterevidence

- Installed Codex CLI `0.144.4` and the current Codex manual document named profile overlays at `$CODEX_HOME/<name>.config.toml`, selected by `--profile`; project and CLI layers can still override them.
- Installed Claude Code `2.1.202` exposes `--model`, `--effort`, `--settings`, `--setting-sources`, `--permission-mode`, tool allow/deny lists, fresh session IDs, and strict MCP selection. Its binary accepts the currently hidden `--append-system-prompt-file`, which therefore requires an upgrade smoke test. Native `--agent`/`--agents`, background agents, and coordination tools would create a second personnel control plane for this pilot.
- The Herdr skill existed once at the shared user path `~/.agents/skills/herdr`; both runtimes could discover it. Claude and Codex status integrations are separate hook files and are transport observations, not skills.
- Putting backend commands in shared `AGENTS.md`/`CLAUDE.md` would expose the protocol to workers. Therefore shared instructions contain only the transport-neutral authority contract; backend commands live only in root-lead role overlays.
- Resume behavior remains load-bearing uncertainty for both runtimes. Session identity cannot establish the effective launch envelope.

## Decision

Maintain one checked-in `role-model-matrix.tsv`, one shared coworker instruction block, and separate native adapters:

- Codex: user-level profile overlays with `developer_instructions`, explicit sandbox/approval posture, and native multi-agent features disabled.
- Claude: explicit interactive CLI commands with model/effort, the canonical user settings file for model/endpoint/auth/hook configuration, additive project/local settings sources, appended role prompt, role-specific tool allowlists, strict MCP selection, fresh session IDs, permission mode, and native agent tools denied.
- Root/lead always uses the approved strongest root row. Root selects zero or more bounded coworkers from task dependencies; model tier never changes claim authority.
- Bind every run actor to a runtime/profile row in the run contract and bind both the contract and matrix digests in the run receipt. These remain declaration checks, not proof of effective process state.
- Delete the shared Herdr skill after root and worker instruction replacements exist. Keep Herdr status integrations because they are replaceable transport hooks, not workflow policy.

## Strongest alternative considered

Use only three launch classes per runtime: `root`, read-only `challenge`, and bounded `mechanical`. This is simpler and reduces profile drift. We retain five profile IDs only because read-only versus write-capable medium/max work needs materially different permission envelopes and the user explicitly approved both model tiers. They do not create five authority levels: the durable authority classes remain root, observation/challenge, and bounded implementation. The matrix checker prevents a profile name from silently changing those classes.

## Foundation receipt

- **Requested outcome:** interchangeable Codex/Claude top-level coworker launches with one controller, explicit approved models/efforts, no shared transport skill, no native subagent control, and transparent removal.
- **Foundation claims:** project instructions remain canonical; role overlays are additive; runtime adapters can bind model/effort and permissions while reading—not copying—the canonical user settings; transport status is not task authority; status hooks are separable from the deleted skill.
- **Decisive evidence:** installed CLI help/profile behavior, exact checked-in matrix/profile assets, separate existing status-hook files, shared skill discovery at one path, contract/profile tests, and an authenticated fresh medium-worker smoke that loaded the canonical user settings, read both project instruction files, exposed only read/search tools, denied write/native-agent tools, and created no sentinel. The earlier hook-only settings envelope failed authentication because it omitted the canonical model/endpoint/auth source; that failed envelope is superseded. Independent challenge also preserved the remaining authority/resume uncertainty.
- **Counterevidence and unknowns:** Claude file-prompt flags are not public-help stable; invalid effort may warn and fall back; declarations do not prove effective tool state; resume may restore conversation without authority; Codex cannot fully attest its own effective profile from a version probe; implementer write enforcement remains untested.
- **Intended versus observed:** intended launches are fresh, explicit, role-bounded processes; a real top-level Claude medium worker loaded the canonical settings, reached the model, discovered project instructions, and exposed only read-only tools. Resume isolation remains unproven.
- **Mismatch signals:** stale aliases, skill-based controller discovery, prompt-only native-agent denial, and unbound actor/model declarations existed before the repair.
- **Blast radius and coupling:** user-level instruction/profile files plus optional repo templates; no base model default, authentication, plugin, hook script, or setup path is replaced.
- **Lock-in and reversibility:** no public API or durable domain data; remove the user profile files/instruction block and optional templates to roll back. Session receipts must preserve any live dependency before removal.
- **Cognitive cost/debt interest:** five explicit envelopes and two runtime adapters require parity maintenance; matrix/profile/contract checks bound that recurring cost and reject aliases as a second source of truth.
- **Fitness properties:** one root; exact runtime/profile/model/effort mapping; native controls declared/denied; no transport protocol in non-root prompts; contract/matrix digest binding; hook/skill separation; fresh-session default; explicit unknowns where effective enforcement is not observable.
- **Classification:** `FOUNDATION_SUSPECT`.
- **Route:** **Foundation-first** — bind the policy and remove the skill/alias drift before relying on the workflow.

## Unknowns and lifecycle

- Effective model availability and aliases are runtime/account facts; launch failure is explicit evidence and must not silently fall back to an unapproved row.
- Resume must be disabled or fully revalidated until controlled tests establish envelope preservation.
- Claude permission modes and Codex sandbox profiles constrain behavior but do not replace worktree/path ownership and external validation locks.
- Remove the adapters if they drift, require protocol disclosure to workers, or add no measured value over a single root session.

## Canonical invariant

One root selects and launches explicit role envelopes; workers receive the task contract, not the backend control protocol, and no model may promote its own claim authority.
