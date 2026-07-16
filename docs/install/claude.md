# Claude Code installation

Foundation Integrity uses one transparent shell adoption path. It installs the
checked Claude projection and project-owned support assets without modifying global
Claude configuration.

## Remote bootstrap

Run from the target repository:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude
```

Preview first or choose an immutable source revision:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude --dry-run --ref <commit-or-tag>
```

Use `--directory <repo>` outside the target, `--with-pre-push` for the explicit
blocking tier, or `--no-pre-commit` to avoid newly wiring the warn-only hook.
`--full-opt` is accepted for clarity but is already the only payload.

## Local checkout

```bash
sh templates/setup/full-opt.sh --runtime claude --dry-run <repo>
sh templates/setup/full-opt.sh --runtime claude <repo>
```

The source checkout must have an `origin` remote, or the launch environment must set
`FI_SOURCE_REPOSITORY`. A source copy with neither fails closed rather than writing
unknown provenance.

The adopter installs all 24 managed skills under `.claude/skills/`, compact project
guidance, fitness assets, `.claude/hooks/scripts/`, `.claude/settings.json`, the
marked ignore block, and inert Claude coworker policy under
`.orchestration/foundation/`.

It creates the generic `AGENTS.md` only when `AGENTS.md` is absent. Existing
`AGENTS.md` and `CLAUDE.md` remain byte-for-byte untouched. Differing project files
and runtime configuration are explicit preflight conflicts, never silently merged.

## Skill invocation

Project skills are unnamespaced:

```text
/foundation-audit Audit the foundation before design.
/adversarial-foundation-review Challenge the receipt in a fresh session.
/foundation-health Review cumulative structural drift.
```

The Claude projection intentionally omits Codex-only `agents/openai.yaml` metadata.
Do not replace it with the Codex projection.

## Inert versus active state

Adoption installs project-scoped hook configuration and static coworker policy. It
does not open sessions, install user launch envelopes, enable a coworker backend, or
turn transport status into task authority. Blocking pre-push remains an explicit
choice.

Companion tracker flows expect the installed project-specific `docs/agents/`
configuration and report a gap when it is absent. The three Foundation Integrity
skills remain usable independently of that companion configuration.

## Ownership, upgrades, and removal

`.foundation-integrity/adoption.tsv` records the source version/ref/revision,
selected runtime, payload digest, and exact hashes/modes for managed files. A later
run updates or removes a managed path only when the consumer has not changed it.

The marked ignore block keeps `.foundation/`, `.orchestration/`, `.claude/`,
`.agents/`, `docs/research/`, local foundation receipts, `tmp/`, and numbered ADR
history out of commits. Only `docs/foundation/receipts/.gitkeep` is tracked.
The non-ignored adoption ledger binds the ignored installed payload to its reviewed
source.

For removal, verify the ledger and delete only unchanged recorded paths/hooks, then
remove the marked ignore block and ledger. Modified managed files require an explicit
owner decision.

Claude Code skill documentation: <https://code.claude.com/docs/en/skills>.
