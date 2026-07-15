# Claude canonical-settings smoke — 2026-07-15

- **CLI:** Claude Code `2.1.202`
- **Role/profile:** `fi-worker-medium`
- **Model/effort observed:** `claude-haiku-4.5` / `medium`
- **Settings source:** `/Users/long7400/.claude/settings.json` passed explicitly with `--settings`; project/local layers remained additive
- **Transport:** fresh Herdr top-level process; closed after evidence collection
- **Cwd:** `/Users/long7400/project/foundation-integrity`

## Observed result

The process reached an authenticated prompt with the expected model, effort, cwd, and `dontAsk` mode. The worker read both `CLAUDE.md` and `AGENTS.md` successfully. Its available tool set was:

```text
Glob, Grep, Read, WebFetch, WebSearch
```

The worker reported that `Write`, `Edit`, `Agent`, and `Task` were not available. No sentinel file was created. The pane was then closed by the root after preserving this receipt.

## Verdict

The previous failure was caused by the hook-only profile settings file omitting the canonical user model/endpoint/auth environment. Passing the original settings file directly fixes model/auth initialization while preserving one source of truth. Read-only and native-agent absence were observed for the medium worker envelope. This does not yet prove implementer write-scope enforcement or resume preservation.
