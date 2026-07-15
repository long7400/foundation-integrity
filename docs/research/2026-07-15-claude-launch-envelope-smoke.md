# Claude launch-envelope smoke — 2026-07-15

> Superseded setup note: this smoke used a hook-only profile settings file and therefore excluded the canonical user model/endpoint/auth configuration. The adapter now passes `~/.claude/settings.json` directly. The authentication failure below is evidence for why the previous envelope was invalid, not evidence about the corrected envelope.

- **CLI:** Claude Code `2.1.202`
- **Repository:** `/Users/long7400/project/foundation-integrity`
- **Base revision:** `1fc2da4b1095975be9671cae084c7f0b24bd2f1d`
- **Worktree:** dirty; this observation validates only the launch envelope, not repository content
- **Transport:** a fresh top-level Herdr process created with `herdr agent start`; the pane was closed after evidence collection
- **Role:** `fi-worker-medium`

## Envelope observed in the process-start response

```text
claude
--model claude-haiku-4.5
--effort medium
--setting-sources project,local
--settings ~/.claude/fi-profiles/settings.json
--strict-mcp-config
--permission-mode dontAsk
--tools Read,Glob,Grep,WebSearch,WebFetch
--disallowedTools Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents
--append-system-prompt-file ~/.claude/fi-profiles/worker-medium.md
--session-id <fresh-uuid>
--name fi-worker-medium-smoke
```

In the first attempt, Herdr returned the exact argv and a new pane identity. Claude rendered `claude-haiku-4.5 with medium effort`, the expected repository cwd, and `don't ask` mode, but its startup validator warned that `TeamCreate` matched no known tool. The checked-in and installed launch commands were amended to remove that unsupported deny rule. A second fresh top-level process using the envelope above reached the prompt with the same model/effort/cwd/mode and no deny-rule warning; it was then closed without submitting a model turn.

## Blocker and negative evidence

Claude stopped before model/tool execution with:

```text
Not logged in · Please run /login
```

Therefore this run does **not** prove project instruction discovery, role-prompt loading, read-only enforcement, native-tool denial, MCP isolation, or model availability to the account. The requested sentinel `.foundation-integrity-claude-smoke-sentinel` was absent after the run, but absence is expected because no model turn executed and is not permission evidence.

## Verdict

- Process creation, argv transport, cwd, displayed model/effort, session identity, and status integration: **observed**.
- Unsupported deny-rule detection and correction: **observed**.
- Authenticated end-to-end Claude role behavior: **blocked by missing login**.
- Resume/isolation behavior: **not tested**.

Do not promote the Claude adapter from pilot evidence on this observation alone. After authentication exists, repeat the read-only sentinel and native-tool event test with a fresh session ID.
