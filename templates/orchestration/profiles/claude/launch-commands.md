# Claude role launch commands

Run these as the interactive command inside a root-created top-level pane. Do not append the task as an argv prompt; submit it only after the Claude prompt is ready. Set `FI_SESSION_ID` to a fresh valid UUID before every process; an empty or reused value is a launch failure. The explicit `--settings "$HOME/.claude/settings.json"` loads the user's canonical model, endpoint, authentication, marketplace, and status-hook configuration without copying secrets into a second profile file. Project and local settings remain additive.

```sh
# root-lead
claude --model claude-opus-4.8 --effort max --setting-sources project,local --settings "$HOME/.claude/settings.json" --strict-mcp-config --permission-mode manual --disallowedTools 'Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents' --append-system-prompt-file "$HOME/.claude/fi-profiles/root-lead.md" --session-id "$FI_SESSION_ID" --name fi-root-lead

# bounded read-only research/scout
claude --model claude-haiku-4.5 --effort medium --setting-sources project,local --settings "$HOME/.claude/settings.json" --strict-mcp-config --permission-mode dontAsk --tools 'Read,Glob,Grep,WebSearch,WebFetch' --disallowedTools 'Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents' --append-system-prompt-file "$HOME/.claude/fi-profiles/worker-medium.md" --session-id "$FI_SESSION_ID" --name fi-worker-medium

# bounded mechanical implementer; root must provide isolated cwd/worktree and write scope
claude --model claude-haiku-4.5 --effort medium --setting-sources project,local --settings "$HOME/.claude/settings.json" --strict-mcp-config --permission-mode acceptEdits --disallowedTools 'Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents,Bash(*herdr*)' --append-system-prompt-file "$HOME/.claude/fi-profiles/implementer-medium.md" --session-id "$FI_SESSION_ID" --name fi-implementer-medium

# complex independent challenger/reviewer
claude --model claude-opus-4.7 --effort max --setting-sources project,local --settings "$HOME/.claude/settings.json" --strict-mcp-config --permission-mode dontAsk --tools 'Read,Glob,Grep,WebSearch,WebFetch' --disallowedTools 'Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents' --append-system-prompt-file "$HOME/.claude/fi-profiles/peer-max.md" --session-id "$FI_SESSION_ID" --name fi-peer-max

# complex/high-coupling implementer; independent review remains required
claude --model claude-opus-4.7 --effort max --setting-sources project,local --settings "$HOME/.claude/settings.json" --strict-mcp-config --permission-mode acceptEdits --disallowedTools 'Agent,Task,TaskCreate,TaskGet,TaskList,TaskUpdate,TaskStop,TaskOutput,SendMessage,Monitor,ScheduleWakeup,ListAgents,Bash(*herdr*)' --append-system-prompt-file "$HOME/.claude/fi-profiles/implementer-max.md" --session-id "$FI_SESSION_ID" --name fi-implementer-max
```

`--append-system-prompt-file` is additive and preserves normal project `CLAUDE.md` discovery. Do not replace it with `--system-prompt`, `--bare`, `--safe-mode`, `--agent`, or `--agents`; those change or bypass the instruction/customization surface this adapter depends on. A read-only role uses a tool allowlist, not permission-mode prose alone. If a task requires MCP or another tool, amend and record the launch envelope explicitly instead of inheriting user defaults.
