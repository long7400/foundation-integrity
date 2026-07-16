# Herdr + Claude adapter

This provides the static [coworker protocol](../coworker-protocol.md) launch envelope
for fresh top-level Claude Code sessions. It is not a skill, native subagent
definition, plugin, or task engine. The executable receipt-bound start/submit/wait
pilot and real runtime smoke are currently Codex-only; do not claim equivalent Claude
lifecycle attestation until a separate adapter and integration proof exist.

Claude Code has no Codex-style named profile overlays. Use the reviewed commands in
[`profiles/claude/launch-commands.md`](../profiles/claude/launch-commands.md): explicit
model/effort, normal project instruction discovery, an appended role prompt, bounded
tools/permission mode, strict MCP posture, disabled native personnel tools, cwd or
worktree, and a fresh session ID.

The root alone creates panes, submits open task packets, waits boundedly, reads
responses, leases validation, accepts/rejects work, and tears down resources. Workers
receive no Herdr commands or topology. Transport status remains attention-only.

Before creating the validation capability, the root operationally designates its live
pane with `herdr agent rename "${HERDR_PANE_ID:?}" fi-root-lead`. The lease binds that
exact runtime/session/pane identity and process ancestry; the name is an accidental
misuse guard, not a same-user security boundary.

Use `.orchestration/foundation/scripts/validation-lease.sh` before heavy or flaky
validation. It locks the Git common directory across worktrees and has no automatic
stale takeover. For any writer, record an isolated worktree or bounded serialized
scope and run a disposable write-isolation smoke first.

Resume and fork are not clean-room review. Conversation history does not prove that
model, effort, role prompt, settings sources, permissions, tools, cwd, or worktree
were restored. Start fresh until the complete launch envelope is attested.

The adapter installs no credentials or user settings. Removal is deletion of the
projected role prompts/commands and references after no live session depends on them.
