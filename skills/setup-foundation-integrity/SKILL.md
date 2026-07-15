---
name: setup-foundation-integrity
description: Wire the foundation-integrity gate into a repo. Detects the repo's existing setup — which of CLAUDE.md / AGENTS.md is in use, whether a workflow pack like mattpocock/skills is installed, whether docs/adr/ exists — then adds the operating rules to the right file and writes the consumer docs. Prompt-driven, not a script: explore, present what you found, confirm, then write. Run once per repo; re-run only to re-wire or reset.
---

Scaffold the per-repo configuration the foundation-integrity skills assume. Like the pack it configures, this skill obeys its own doctrine: it detects rather than assumes, composes rather than bundles, and never vendors another pack's files.

This is prompt-driven. Explore, present findings, confirm with the user, then write.

## Process

### 1. Explore

Read the repo's current state. Don't assume:

- `git remote -v` — is this GitHub / GitLab / other? (for the ADR + doc footer only)
- **`CLAUDE.md` and `AGENTS.md` at the repo root** — which exists, which is authoritative, and is either one only a forwarding/import shim to the other? Is there already an `## Foundation Integrity` or `## Personal Operating Rules` block?
- **`docs/adr/`** — does an ADR directory already exist? What numbering is in use?
- **Is a workflow pack installed?** Look for `mattpocock/skills` (a `skills-lock.json`, a `docs/agents/` dir from `setup-matt-pocock-skills`, or those skills in your available-skills list). This decides whether Section B runs.
- **Stack signals** — `package.json` / `pom.xml` / `build.gradle` / `go.mod` / `pyproject.toml` / `Cargo.toml`, and whether there's any CI (`.github/workflows/`, `.gitlab-ci.yml`). This decides what Section C can honestly offer.

Run [`templates/setup/resolve-instruction-target.sh`](../../templates/setup/resolve-instruction-target.sh) against the repo root before proposing the target, and record its output and exit status. Exit `0` identifies a mechanical candidate that you must still inspect. Exit `2` (`AMBIGUOUS`) or `3` (`NONE`) is a stop-and-ask result; do not choose or create a file on the user's behalf.

### 2. Present findings and ask

Summarise what's present and missing. Then take the sections in order — one section, one answer.

**Section A — Where the operating rules go.**

The foundation gate lives in the repo's **canonical instruction file**, not whichever filename wins a hard-coded priority. Resolve ownership before proposing an edit. The transparent helper [`templates/setup/resolve-instruction-target.sh`](../../templates/setup/resolve-instruction-target.sh) covers the common mechanical cases; inspect its result and the files themselves rather than treating it as magic.

- If only one of `CLAUDE.md` / `AGENTS.md` exists, that file is the candidate target.
- If both exist and one is a forwarding/import shim to the other (for example a minimal `CLAUDE.md` containing `@AGENTS.md`), edit the imported canonical file and leave the shim minimal.
- If both files are substantive, both contain blocks, or the forwarding relationship is ambiguous, stop and ask which file is canonical even when only one currently contains the Foundation Integrity block. Existing placement is evidence, not proof of ownership.
- If neither exists, ask which to create — don't pick for them.

Never edit a forwarding shim merely because its filename is preferred by one runtime. If a foundation block already exists in the canonical file, update it in place — don't append a duplicate and don't overwrite the user's surrounding edits.

**Section B — Workflow-pack integration.** Skip entirely if no workflow pack was found.

If `mattpocock/skills` is installed, propose wiring (recommended: **yes**):

- Insert `foundation-audit` before `to-spec` or any architecture is frozen. If a spec already exists, audit it immediately before design/code.
- Point `code-review`'s standards axis at the foundation mismatch signals.
- On a Foundation-first route, hand off to `improve-codebase-architecture` / `codebase-design`.

Record this as **reference lines** in the block — never copy the other pack's files. If the pack is later removed, these lines degrade to plain guidance; the gate still runs.

**Section C — Structural fitness signals.** Default: **git-only** (churn, recurring-seam grep, ADR staleness) — works in every repo including one with no code yet. Write this without asking; it's tier 2 of [`templates/fitness/`](../../templates/fitness/).

Offer the **tier-3 per-stack adapter** — a real architecture-rule tool wired into CI — **only if** exploration found a real code stack. Match the stack to the adapter template and offer to wire it:

- JS/TS → [`templates/fitness/adapters/js-ts.md`](../../templates/fitness/adapters/js-ts.md)
- JVM → [`templates/fitness/adapters/jvm.md`](../../templates/fitness/adapters/jvm.md)
- Python → [`templates/fitness/adapters/python.md`](../../templates/fitness/adapters/python.md)
- Go → [`templates/fitness/adapters/go.md`](../../templates/fitness/adapters/go.md)
- Other stack → use the equivalent architecture-rule tool for that ecosystem; the tier-1 intents are the same.

Each adapter template names the concrete tool and shows the rule config — that's the one place a tool is named, so there's a single source of truth for the stack→tool mapping.

If the repo is docs/schema-only or pre-code, say so and *don't* wire a code-level adapter — installing governance on a repo with no code is itself the premature scaffolding this pack warns against. Name the deferral explicitly, and note that re-running this skill once code lands will wire it then.

**Section D — Hooks (enforcement layer).** Hooks run the checks whether or not the agent wants them to — the answer to "you can't trust the agent's good faith." Offer from [`templates/hooks/`](../../templates/hooks/):

- **Git hooks** (`templates/hooks/git/`) — runtime-neutral, fire for Claude, Codex, and humans. Recommend for any repo with a git remote. `pre-commit` warns; `pre-push` blocks (opt-out).
- **Agent hooks** — wire the one matching the target runtime into **project scope**: Claude → merge `claude-settings.json` into `.claude/settings.json`; Codex → merge `codex-config.toml` into the project `config.toml` (`features.hooks = true`). Both call the same scripts as the git hooks.
- Both layers depend on [`foundation-surface.txt`](../../templates/hooks/foundation-surface.txt) — help the user tailor its globs to the repo's actual surfaces before wiring. A mis-scoped surface list is what makes hooks annoying enough to disable.
- The guard clears a surface change only when a **valid v2 receipt** (or an ADR embedding the same block) **in the same change set names the exact path and binds the checked revision, changed-content digest, and evidence references**. Copy [`review-receipt.md`](../../templates/hooks/review-receipt.md) as the format, and create `.foundation/receipts/` if the repo will use receipts rather than full ADRs.
- In blocking or attested mode, a missing surface policy, unavailable temporary workspace, unresolved revision, or unavailable SHA-256 implementation fails closed rather than silently clearing the change.
- Choose a **trust mode** with the user (`FI_REVIEW_MODE`):
  - **advisory** (default) — a valid receipt clears the change. Records a decision and makes skipping visible/costly; does **not** prove an independent review ran (the receipt is author-writable). Right for solo or trusted-agent repos.
  - **attested** (opt-in) — clearing also requires a signed commit from a key on `FI_TRUSTED_REVIEWERS` whose identity matches the receipt's `reviewer`. Only meaningful if that allowlist and the signing key live **outside** the agent's write scope (ideally injected by protected CI) and a server-side check re-runs the guard — a local hook is bypassable. Walk the user through: enabling commit signing, creating the `fingerprint<TAB>identity` allowlist outside the worktree, and adding branch protection. If they can't guarantee key isolation, say so plainly and stay on advisory — attested without key isolation is theatre.

Keep it proportional: default posture is **warn**, blocking only on `pre-push`. If the user doesn't want runtime hooks, the git layer alone still enforces at commit/push. Skip hooks entirely for a pre-code repo (nothing to check yet) and note the deferral.

### 3. Confirm and edit

Show a draft of:

- The block to add to `CLAUDE.md` / `AGENTS.md` (from [`templates/claude-md-block.md`](../../templates/claude-md-block.md), with Section B lines included only if a pack was found)
- `docs/agents/foundation.md` (consumer rules — from [`templates/docs/foundation-audit.md`](../../templates/docs/foundation-audit.md))
- `docs/agents/foundation-pattern-language.md` (shared Balloon/Brake vocabulary reference with evidence probes — from [`templates/docs/foundation-pattern-language.md`](../../templates/docs/foundation-pattern-language.md); using the aliases remains optional)
- `docs/adr/0000-template.md` (if no ADR template exists — from [`templates/adr/0000-template.md`](../../templates/adr/0000-template.md))
- The fitness adapter config, if Section C wired one (the tool's config file, tailored to the repo's real layer layout)
- The hook wiring and a tailored `foundation-surface.txt`, if Section D wired hooks
- Optionally `docs/foundation/why-foundation-integrity.md` (the rationale, if the user wants it kept in-repo)

Let the user edit before writing. For the fitness config and `foundation-surface.txt`, the path globs *must* match the repo — draft them from what exploration found, and have the user confirm.

### 4. Write

- Insert/update the block in the resolved canonical instruction file; leave any forwarding shim as a forwarding shim.
- Write `docs/agents/foundation.md`.
- Write `docs/agents/foundation-pattern-language.md` so the consumer rules' vocabulary reference is local and stable.
- Scaffold `docs/adr/0000-template.md` only if no ADR template exists (respect existing numbering).
- If Section C wired an adapter: write its config file and add the check to CI if CI exists.
- If Section D wired hooks: install the git hooks (into `.git/hooks/` or a `core.hooksPath` dir), merge the runtime hook config into **project scope**, copy the scripts and `foundation-surface.txt` to a stable in-repo path, and update the command paths in the configs to match. Make the scripts executable.
- Write the why-doc only if the user opted in.

### 5. Done

Tell the user what's wired and how it runs: `foundation-audit` before non-trivial work; `adversarial-foundation-review` in a separate session (ideally a different model) whenever a foundation surface is touched or a fitness check regresses — not only on a self-rated SUSPECT/BLOCKED; `foundation-health` every few waves for cumulative drift and the remediation backlog. If fitness/hooks were wired, note that structural violations now trip mechanically at commit/push and mid-session, and that the surface-guard removes the self-grade escape — a surface change with no ADR/receipt naming it is flagged, making a skipped review visible and costly (it records a decision; it does not prove an independent review ran). Mention they can edit `docs/agents/foundation.md`, `docs/agents/foundation-pattern-language.md`, and `foundation-surface.txt` directly later, and re-run this skill to wire the stack adapter once code lands (if it was deferred) or to re-wire/reset.
