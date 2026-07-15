# Herdr + Claude pilot adapter

This maps the transport-neutral [coworker protocol](./coworker-protocol.md) and [model policy](./model-role-policy.md) to Claude Code. It is not a skill, native subagent definition, plugin, or workflow engine.

## Native configuration surface

Claude Code does not use Codex-style named profile overlays. Use an explicit launch envelope:

- `--model` and `--effort` bind the selected policy row;
- `--settings "$HOME/.claude/settings.json"` loads the canonical user model, endpoint, authentication, marketplace, and status-hook configuration directly; do not copy credential-bearing settings into role-profile files;
- `--setting-sources project,local` keeps project/local layers additive without loading the same user file twice;
- `--append-system-prompt-file` binds the role prompt while preserving normal project `CLAUDE.md` discovery;
- a read-only peer/worker uses `--permission-mode dontAsk` plus a read-only `--tools` allowlist;
- `--permission-mode acceptEdits` is allowed only for a root-assigned isolated worktree/write scope;
- `--disallowedTools` denies the installed native coordination tool family; this is defense-in-depth behind the allowlist;
- `--strict-mcp-config` denies inherited MCP servers unless the run envelope explicitly supplies an allowlist;
- a fresh `--session-id` distinguishes a new top-level thread from resume/fork continuity;
- `--name` records the role/profile label.

Canonical role prompts and commands live under [`profiles/claude/`](./profiles/claude/). Do not use `--agent`, `--agents`, `claude agents`, `--background`, or `--bg` as a second personnel control plane.

## Launch sequence

1. Root validates `role-model-matrix.tsv` and the run contract, including every actor/profile binding.
2. Root runs `templates/setup/check-credential-permissions.sh "$HOME/.claude/settings.json"`; any group/other access is a launch failure. This protects against other local users, not same-user processes.
3. Root acquires the transparent controller lock with `scripts/controller-lock.sh acquire`; a stale lock requires human inspection, never automatic takeover.
4. Root creates or selects the explicit cwd/worktree and records it. Before any write-capable actor, run and record a disposable write-isolation sentinel smoke; no `pass`, no writer.
5. Root creates a background pane/tab and starts the exact interactive command from `profiles/claude/launch-commands.md` with a fresh UUID; do not pass the task as an argv prompt.
6. After the normal interactive prompt is ready, root submits the open task packet.
7. Transport status is attention-only. Root reads the result/artifact, preserves transcript and worker-output digests, reconciles them into canonical state, then releases the controller lock after teardown.

## Resume boundary

A conversation ID does not prove that model, effort, appended role prompt, settings sources, permission mode, allowed/denied tools, cwd/worktree, or project instruction chain were restored. `--fork-session` inherits transcript context and is not clean-room independence. The current pilot is therefore `fresh-only`: reject resume, continue, and fork for accepted work until a full-envelope attestor and controlled resume smoke exist.

## Effects ledger

The adapter adds role prompt files and documented commands that reference the canonical user `settings.json` directly. It does not copy authentication or settings into role files. It requires owner-only permissions but does not claim same-user credential isolation. Removal is deletion of the role prompt/command files and instruction references after no live session depends on them.

## Honest enforcement boundary

The CLI help and parser prove that the named flags exist, not that every native-control path, plugin, hook, or permission edge is closed. After a Claude CLI upgrade, smoke-test role-prompt loading, project instruction discovery, read-only sentinel writes, native-tool denial from stream events, settings-source isolation, fresh-session independence, and exact model/effort observations. Treat an invalid-effort warning as launch failure because the current parser may fall back while exiting successfully.
