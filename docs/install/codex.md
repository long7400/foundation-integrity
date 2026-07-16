# Codex installation

Foundation Integrity uses one transparent shell adoption path. It installs the
checked Codex projection and project-owned support assets without changing your base
Codex provider or user configuration.

## Remote bootstrap

Run from the target repository:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --codex
```

Preview first or choose an immutable source revision:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --codex --dry-run --ref <commit-or-tag>
```

Use `--directory <repo>` outside the target, `--with-pre-push` for the explicit
blocking tier, or `--no-pre-commit` to avoid newly wiring the warn-only hook.
`--full-opt` is accepted for clarity but is already the only payload.

## Local checkout

```bash
sh templates/setup/full-opt.sh --runtime codex --dry-run <repo>
sh templates/setup/full-opt.sh --runtime codex <repo>
```

The source checkout must have an `origin` remote, or the launch environment must set
`FI_SOURCE_REPOSITORY`. A source copy with neither fails closed rather than writing
unknown provenance.

The adopter installs all 24 managed skills under `.agents/skills/`, compact project
guidance, fitness assets, `.codex/hooks/scripts/`, `.codex/hooks.json`, the marked
ignore block, and inert Codex coworker policy under `.orchestration/foundation/`.
Review and trust the project and exact hook definitions through Codex's hook UI.

It creates the generic `AGENTS.md` only when `AGENTS.md` is absent. Existing
`AGENTS.md` and `CLAUDE.md` remain byte-for-byte untouched. Differing project files
and runtime configuration are explicit preflight conflicts, never silently merged.

## Skill invocation

The first-party skills are explicit:

```text
Use $foundation-audit to audit the foundation before design.
Use $adversarial-foundation-review in a fresh independent session.
Use $foundation-health to review cumulative structural drift.
```

The Codex projection includes optional `agents/openai.yaml` presentation metadata.
Do not replace it with the Claude projection.

## User profiles

Adoption copies profile templates into the inert project policy; it does not install
them into `$HOME/.codex/`. Review them first, then use the primary profile manager:

```bash
sh .orchestration/foundation/scripts/manage-codex-profiles.sh status
sh .orchestration/foundation/scripts/manage-codex-profiles.sh install
```

The manager exclusively creates and provenance-binds the five primary envelopes. It
does not claim or overwrite the two separately owned GLM profile paths.

The five primary role envelopes retain the current Codex provider. Two GLM-5.2
auxiliary profiles are active through a user-local CLIProxyAPI v7.2.80 gateway;
they cap context at 272,000 tokens and use only the loopback client key
`FI_CLIPROXY_KEY`.

The gateway is the single translation seam: Codex speaks Responses to loopback and
CLIProxyAPI speaks Chat Completions to Z.AI. It was locally exercised for text,
function calling, tool-result continuation, and SSE streaming.

From the installed project, run:

```bash
sh .orchestration/foundation/scripts/cliproxy-glm.sh setup
sh .orchestration/foundation/scripts/cliproxy-glm.sh start
eval "$(sh .orchestration/foundation/scripts/cliproxy-glm.sh print-env)"
codex --profile fi-glm-peer-scout
# or codex --profile fi-glm-implementer-mechanical
```

`setup` asks for the Z.AI key without echoing it, verifies the pinned release,
installs only the two GLM profiles into `$CODEX_HOME` (without overwriting a
difference), creates owner-only gateway state, and binds the seam to `127.0.0.1`.
Use `doctor`, `stop`, `restart`, `status`, and `remove` for lifecycle. The upstream
key is never written to a Codex profile or repository; the default provider remains
untouched.

If a previous direct-integration test left a differing GLM profile in `$CODEX_HOME`,
remove that old test copy after stopping dependent sessions; setup refuses conflicting
profile content by design.

Z.AI endpoint references:

- <https://docs.z.ai/devpack/tool/others>
- <https://docs.z.ai/devpack/latest-model>

See [`../../templates/orchestration/runtime/codex.md`](../../templates/orchestration/runtime/codex.md)
for the full role, launch, evidence, and removal contract.

## Ownership, upgrades, and removal

`.foundation-integrity/adoption.tsv` records the source version/ref/revision,
selected runtime, payload digest, and exact hashes/modes for managed files. A later
run updates or removes a managed path only when the consumer has not changed it.

The marked ignore block keeps `.foundation/`, `.orchestration/`, `.codex/`,
`.agents/`, `docs/research/`, local foundation receipts, `tmp/`, and numbered ADR
history out of commits. Only `docs/foundation/receipts/.gitkeep` is tracked. The
non-ignored adoption ledger binds the ignored installed payload to its reviewed source.

For removal, verify the ledger and delete only unchanged recorded paths/hooks, then
remove the marked ignore block and ledger. User profiles copied to `$HOME/.codex/`
have a separate lifecycle and must be removed explicitly after live sessions stop:
use `manage-codex-profiles.sh remove` for the primary five and
`cliproxy-glm.sh remove` for the two GLM auxiliaries plus gateway state.

Codex skill and profile documentation:

- <https://learn.chatgpt.com/docs/customization/overview#skills>
- <https://learn.chatgpt.com/docs/config-file/config-advanced#profiles>
- <https://learn.chatgpt.com/docs/config-file/config-advanced#custom-model-providers>
