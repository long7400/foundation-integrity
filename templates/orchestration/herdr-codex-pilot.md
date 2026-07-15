# Herdr + Codex pilot adapter

This is a transparent mapping of the transport-neutral [coworker protocol](./coworker-protocol.md). It is not a Herdr skill, a Codex subagent configuration, or a FirstMate installation.

## Effects ledger

| Layer | What it affects | What it does not own |
| --- | --- | --- |
| Herdr session | PTYs, workspaces/tabs/panes, input, bounded reads/waits, attention status, optional session restore | task decomposition, acceptance, evidence, worktree ownership, merge/release |
| Herdr Codex integration | reports Codex session identity to Herdr; current releases may use that identity to relaunch `codex resume <id>` during restore | the Codex profile, developer instruction, sandbox, or authority contract unless the relaunch envelope explicitly rebinds them |
| Codex profile | a named configuration overlay for the launched Codex invocation: model/effort, sandbox/approval, `developer_instructions`, features, skill enablement, and other valid keys | sibling processes, Herdr policy, or any invocation not launched/resumed with an equivalent profile |
| `AGENTS.md` / project guidance | repository-owned durable instructions loaded by each Codex thread according to its instruction chain | machine-enforced capability boundaries |
| Run contract + receipts | workflow authority, actors, validation lease, artifacts, and acceptance evidence | terminal lifecycle implementation |

Before enabling or installing a Herdr integration, inspect `herdr integration` and the generated changes. The integration should be limited to identity/status reporting hooks; it must not inject department workflow instructions into coworkers. Record exact hook/config paths and the uninstall/disable command in the run receipt.

## Profile rule

Use user-level Codex profile files (`$CODEX_HOME/<name>.config.toml`) and launch with `codex --profile <name>`. Profiles are explicit layers, not inheritance from the root process. The canonical templates and approved mapping live under [`profiles/codex/`](./profiles/codex/) and [`role-model-matrix.tsv`](./role-model-matrix.tsv).

Keep any reviewed global `model_instructions_file` untouched. Worker profiles should add role behavior with `developer_instructions`; they must not replace the base instruction file or duplicate `AGENTS.md`.

Example peer profile:

```toml
# ~/.codex/fi-peer-max.config.toml
model = "gpt-5.6-luna"
model_reasoning_effort = "max"
sandbox_mode = "read-only"
approval_policy = "never"
developer_instructions = """
You are an independent peer speaking directly with the decision owner. Do not
delegate or supervise other agents. Expand the problem space, seek primary
counterevidence, and report unknowns and the strongest alternative. Do not use
or inspect terminal-multiplexer control mechanisms.
"""

[features]
multi_agent = false
```

An implementer profile may use `workspace-write`, but only with a worktree and write scope recorded in the run contract. A reviewer stays read-only and receives no author narrative. Do not install a transport-control skill for any role. Root controller behavior is plain `developer_instructions` in the root profile; worker profiles contain no backend protocol.

## Transparent launch sequence

1. Verify the root is already inside Herdr (`HERDR_ENV=1`) and record Herdr/Codex versions.
2. Write and validate a copy of [`run-contract.tsv`](./run-contract.tsv) against [`role-model-matrix.tsv`](./role-model-matrix.tsv), including runtime/profile bindings, the root-bound `current_state_path`, fresh-session policy, root-owned validation, and typed implementer scopes.
3. Acquire the transparent controller lock with `scripts/controller-lock.sh acquire`; a stale lock requires human inspection, never automatic takeover.
4. Before any write-capable actor, create an isolated worktree and record a disposable sentinel smoke proving allowed writes succeed and out-of-scope writes are rejected by the actual runtime envelope. No `pass`, no writer.
5. Create one background tab per coworker so repeated right-splits cannot shrink the root pane. Use IDs returned by Herdr JSON; never construct IDs from display numbers.
6. Start only the normal Codex interactive executable with the selected canonical profile. Do not pass the task as an argv prompt.
7. Wait for `idle`, then submit the open task packet with explicit pane targeting.
8. Wait for `working`; later treat either `idle` or `done` as possible turn completion. Inspect the pane and artifact before deciding.
9. Keep the root as the only Herdr controller. Coworkers do not call Herdr and do not know the department topology.
10. Preserve the worker response and transport transcript as separate SHA-256-bound artifacts, reconcile them into the root current-state record, fill [`pilot-run-receipt.md`](./pilot-run-receipt.md), and release the controller lock only after acceptance/teardown. A green validator is not runtime or acceptance evidence.

Illustrative commands; read IDs from each JSON response:

```sh
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --label "peer-a" --no-focus
# Read the created tab/pane IDs from JSON.
herdr pane run <pane-id> "codex --profile fi-peer-max"
herdr wait agent-status <pane-id> --status idle --timeout 30000
herdr pane run <pane-id> "<open task packet>"
herdr wait agent-status <pane-id> --status working --timeout 30000
```

Use `--no-focus`, explicit IDs, and bounded waits. Inspect before waiting for a future transition. Never close a pane or tab without a creation receipt showing this run owns it.

## Status semantics

- `working` — attention signal that the agent is generating or otherwise detected as active.
- `blocked` — attention signal that input may be required.
- `done` — the agent completed while unseen.
- `idle` — the agent is waiting and the result is considered seen; an initially opened prompt is also idle.

`idle` and `done` differ in attention state, not work-product validity. Long foreground tools can also produce misleading agent status. The root must reconcile the task packet, artifact, current repository state, and canonical evidence lock.

## Session references and restore

The current pilot is `fresh-only`. Do not resume, continue, or fork accepted work; start a fresh thread for every role and challenge.

Current Herdr source restores Codex with plain `codex resume <id>`. Until a controlled experiment and full-envelope attestor prove how profile, `developer_instructions`, skill/feature enablement, sandbox, approvals, cwd, and worktree are resolved, automatic resume must remain disabled and restored output is not accepted as pilot evidence.

Minimum resume experiment:

1. Start a disposable read-only Codex thread with a harmless developer marker.
2. Record thread ID, profile, effective config/instruction sources, cwd, revision, and permission behavior.
3. Stop the process.
4. Resume once with plain `codex resume <id>` and once with `codex --profile <name> resume <id>`.
5. Compare effective authority and attempt only a disposable write probe.

A matching conversation history does not prove matching authority.

## Mechanisms borrowed, files not copied

No FirstMate component is installed or vendored. The useful mechanisms were identified from immutable FirstMate commit [`e063ca5e2459ea8cbcefb1d58310b3617318bfb8`](https://github.com/kunchenguid/firstmate/commit/e063ca5e2459ea8cbcefb1d58310b3617318bfb8):

- worktree isolation separate from the terminal backend (`docs/herdr-backend.md`);
- durable task metadata (`bin/fm-spawn.sh`);
- event-driven supervision with polling fallback (`bin/fm-watch.sh`, `bin/backends/herdr.sh`);
- creation provenance before prune/teardown (`docs/herdr-backend.md`);
- a single session/fleet lock to prevent two controllers (`AGENTS.md`, `bin/fm-lock.sh`).

Do not copy its agent distro, skills, second-level hierarchy, daemon, project modes, or approval policy. Reimplement only a mechanism after its local invariant and deletion path are explicit.

Primary Herdr evidence for the resume seam: commit [`d0111c9f9022e0ec26d8f03236a91b026b567d45`](https://github.com/ogulcancelik/herdr/commit/d0111c9f9022e0ec26d8f03236a91b026b567d45), especially `src/agent_resume.rs`, `src/integration/assets/codex/herdr-agent-state.sh`, and `website/src/content/docs/session-state.mdx`.
