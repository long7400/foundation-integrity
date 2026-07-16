# ADR-0005: Make full repository adoption explicit, selective, and idempotent

- **Status:** accepted
- **Date:** 2026-07-16
- **Foundation route:** Foundation-first
- **Classification:** FOUNDATION_SUSPECT before the setup repair; FOUNDATION_BLOCKED
  after independent challenges; FOUNDATION_OK after the second repair wave
- **Outcome:** PROCEED

## Requested outcome

Provide a curl-friendly one-command setup for a personal downstream project that
installs all 24 managed pack skills for Codex, Claude, or both; adopts the Foundation
Integrity operating block and generated-state ignores; installs exactly four
companion configuration documents; and offers fitness, hooks, and orchestration as
explicit components without requiring manual tree copies.

Reduce downstream context and documentation noise by excluding research working
notes and research bibliographies from consumer templates. Decide explicitly whether
the reusable instruction block, hooks, and fitness templates are still necessary.

## Foundation receipt

- **Ownership and source of truth:** runtime skill projections remain generated from
  canonical `skills/`; `templates/claude-md-block.md` remains the single marked
  instruction source; the gitignore template remains the single marked ignore source;
  `templates/fitness/` and `templates/hooks/` own the measurement layer; optional
  coworker policy remains under `templates/orchestration/`.
- **Intended versus observed behavior:** the intended full setup was one explicit
  project adoption. The observed README path required manual copying and merging,
  encouraged copying the entire template tree, did not define conflict behavior, and
  left hook activation ambiguous.
- **Decisive evidence:** first-party and companion skills directly reference the ADR,
  pattern, proof-surface, and git-only fitness templates. Hook scripts execute those
  structural signals and provide the observable foundation-surface trigger. The
  reusable instruction block is a compact marked consumer policy, while repository
  `AGENTS.md` contains repo-only authoring and maintenance rules.
- **Counterevidence:** installed template files are inert until read, so deleting them
  does not reduce prompt context by itself. Conversely, copying every template and
  every research citation makes project adoption harder to inspect even if it is not
  automatically prompt-loaded.
- **Unknowns:** runtime discovery budgets and exact prompt serialization remain
  runtime-dependent. Existing project hook/config ownership cannot be inferred safely
  from filenames alone.
- **Mismatch signals:** manual multi-step setup, whole-tree copying, duplicated merged
  source blocks, silent config overwrite, automatic blocking hooks, or global profile
  mutation would each create unclear ownership or hidden effects.
- **Blast radius and lock-in:** project-local skill trees, instruction and ignore
  blocks, `docs/agents/`, inert templates, and optional `.git/hooks` wiring. No API,
  schema, durable domain data, user-level runtime config, plugin registry, or external
  session state changes.
- **Reversibility:** added files are project-local; marked blocks have exact ownership
  delimiters; `.foundation-integrity/adoption.tsv` binds the distribution snapshot and
  every managed file/hook hash; unchanged managed files can be updated or removed
  without overwriting consumer edits; orchestration remains inactive.
- **Cognitive cost:** one installer and its contract tests replace a manual checklist.
  The remaining cost is reviewing real project-file conflicts and customizing the
  foundation-surface policy.
- **Architectural fitness properties:** all 24 managed pack skills per selected
  runtime while unrelated consumer skills remain untouched; no stale or mixed-runtime
  file inside a managed skill; one instruction owner; exact marked-block idempotence;
  symlink-safe target and hook paths; hash-bound update/removal ownership; ignored
  working state; four project docs; no research bibliography but a compact provenance
  capsule; warn-only delta-only pre-commit by default; blocking pre-push only by
  explicit flag; no automatic runtime-hook, profile, integration, pane, or
  orchestration activation.

## Decision

Keep `templates/claude-md-block.md`. It is the canonical reusable consumer block and
is not equivalent to the repository-specific `AGENTS.md`. The installer merges this
block but does not copy the source template into the consumer project.

Keep `templates/fitness/`. It is load-bearing for proof-surface selection,
foundation-health's git signals, stack-specific structural enforcement, and the
pack's claim that reasoning is backed by measurement rather than self-attestation.

Keep hooks in full-opt. Copy the shared scripts, policy, receipt, git samples, and
runtime samples. Install only the warn-only pre-commit hook by default, and only when
the target uses a normal project-local hook directory and has no conflicting hook.
The default pre-commit runs the surface guard and cheap git delta only; stack adapters
wait for explicit runtime-hook adoption or the pre-push/CI tier.
Install blocking pre-push only with `--with-pre-push`. Never merge runtime settings
or replace a custom hooks path automatically.

Copy orchestration in full-opt because the user explicitly selected the complete
personal setup. Copying is not activation: do not install user profiles, enable a
backend integration, open sessions, or add orchestration manuals to always-loaded
instructions. The merged consumer block retains only the minimal transport-neutral
safety boundary needed if orchestration is later selected.

Copy only the selected template subtrees: ADR, compact consumer docs, fitness, hooks,
orchestration, and required setup helpers. Merge rather than duplicate the instruction
and ignore source blocks. Do not copy `docs/research/` or a research bibliography.
Copy a compact distribution provenance capsule and bind the exact adopted payload in
`.foundation-integrity/adoption.tsv`; keep full research in repository ADRs.

Implement `scripts/install.sh` as a thin bootstrap that requires one runtime, defaults
to core, resolves a branch/tag to one commit, downloads that immutable archive, prints
its provenance, and invokes the project-local adopter without changing global config.

Implement `templates/setup/full-opt.sh` with a required runtime selection, explicit
core/full-opt presets plus additive components, dry-run
effects ledger, symlink-aware preflight conflict detection, marked-block idempotence,
GitHub tracker customization when `origin` supplies a clear slug, a durable
hash-and-mode-bound adoption lock, safe updates/removals of unchanged managed files, an exact
managed-skill projection postcondition, first-adoption protection for unowned marked
blocks, a one-instruction-owner preflight, a target-local serialization lock, and no
installer-managed writes after a preflight-detected file conflict. Do not claim
crash-atomic installation; final postconditions detect incomplete managed surfaces
but do not provide rollback.

## Strongest alternative

Delete the instruction template, fitness layer, and hooks, then copy only skills and
orchestration. This is smaller on disk but breaks the canonical merge owner, leaves
skill references dangling, and changes the product from a reasoning-plus-measurement
gate into a self-attested reasoning pack. Disk size is not active prompt context, so
the alternative removes requested capability without evidence of a context benefit.

The narrower viable alternative is keeping the files but retaining the manual
checklist. It avoids installer maintenance but preserves the user's reported friction
and has no machine-checked no-overwrite or idempotence contract.

## Independent challenge and repair absorption

The stabilized candidate received an independent `NO_GO` on five claims. The final
design absorbs them as follows:

- apply-time state is revalidated before managed copies, removals, shared-file writes,
  hook writes, and adoption-lock replacement; documentation now excludes the final
  non-cooperating compare/write race from the no-overwrite claim;
- refs are URL-encoded, direct commit refs remain compatible with the system Bash on
  macOS, archive paths/roots/symlinks are checked, and contract tests prove that the
  archive request uses the resolved commit rather than the mutable ref;
- Claude-only to Codex/both instruction-owner migration is an explicit manual safety
  boundary, not an implied automatic upgrade;
- the transient apply lock carries an ownership token, so cleanup will not remove a
  replacement lock; and
- pre-existing identical non-skill files and hooks are recorded as external, not as
  update/removal-owned payload.

The strongest remaining alternative is to delete the remote bootstrap and retain only
the local adopter. That removes one network trust edge but restores manual download
and checkout friction without improving project-file ownership. The accepted route
keeps the thin bootstrap, makes the exact GitHub ref-to-commit trust boundary visible,
and leaves all project mutation in the tested local adopter.

## Acceptance checks

- dry-run performs no target mutation;
- the remote bootstrap requires exactly one runtime, rejects conflicting presets,
  resolves a requested ref to a digest-bound commit, and defaults to core;
- core, fitness-only, hooks-implies-fitness, and full-opt component selections match
  their documented payloads without global runtime or orchestration activation;
- Codex, Claude, and both-runtime modes install all 24 managed pack skills per
  selected runtime while unrelated skills survive;
- stale files and wrong-runtime metadata inside managed skill directories fail before
  mutation;
- reruns do not duplicate the instruction or ignore blocks;
- a pre-existing marked block without an adoption lock is accepted only when it is
  byte-identical to the distribution source; customized blocks remain untouched and
  fail before other project writes;
- a Foundation Integrity block in the non-selected instruction file prevents adoption
  until the project reconciles one owner;
- dangling destination, symlinked `.git`, and symlinked hook paths are rejected before
  writes;
- source instruction/gitignore templates and research working state are not copied;
- exactly four `docs/agents/` files and the selected template surfaces exist;
- a GitHub `origin` customizes the tracker without inheriting this repo's slug;
- a differing project file stops setup before instruction/ignore writes;
- final postconditions cover every staged file, both managed blocks, installed hooks,
  the exact file/directory contents of all managed skill roots, removal of deselected
  runtime skill roots, and the adoption lock written by the run;
- the adoption lock records source ref/revision, component selection, payload digest,
  managed file/hook hashes, and POSIX modes; unchanged old managed files can update or
  be removed on component downgrade, while content or mode edits conflict;
- a held install lock fails before project mutation and is never removed by the
  process that failed to acquire it;
- an acquired install lock carries an ownership token and cleanup leaves a replacement
  lock untouched;
- pre-existing identical non-skill files and hooks remain external and survive
  component downgrade instead of silently becoming deletion-owned;
- managed writes revalidate their preflight state immediately before apply; the docs
  explicitly exclude arbitrary non-cooperating writers from the serialization claim;
- Claude-only to Codex/both instruction-owner migration remains an explicit manual
  safety boundary rather than an automatic block move;
- pre-commit is warn-only, delta-only, and conflict-preserving;
- pre-push is absent by default and blocking only after explicit opt-in;
- consumer templates contain no research bibliography and retain a compact immutable
  provenance pointer;
- repository contracts, runtime projection parity, companion hashes, and shell syntax
  remain green.
