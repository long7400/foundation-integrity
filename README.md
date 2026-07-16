# Foundation Integrity

A small set of agent skills that add one thing most workflow skill packs leave out: **a gate that checks the foundation is sound _before_ you build a feature on it** — instead of letting a capable agent bend logic and stack wrappers to make the feature fit a weak foundation.

Works with both **Claude Code** and **OpenAI Codex** as plugins or as native
repo-local skills. `skills/` is the plugin-authoring source; `.claude/skills/` and
`.agents/skills/` are checked runtime projections for standalone project installs.
The distribution also carries a commit-pinned Matt Pocock workflow companion. The
Foundation Integrity core remains standalone and does not derive its gate or
coworker protocol from that snapshot.

## Why this exists

Workflow packs (spec → tickets → implement → test → review) optimise *flow*. They assume the foundation is fine and help you move faster on top of it. But "moving fast on a weak foundation" is exactly the machine that manufactures debt:

- An agent's objective is "feature works + tests green". Architectural health is a hidden variable — not in the objective, not measured. So a strong agent will happily bend logic and add wrapper-around-wrapper to hit the local objective (Goodhart's Law).
- Agents have no "aesthetic pain" at ugly structure, and a completion bias that always prefers fitting the existing foundation over stopping to repair it.
- As the codebase deforms, humans understand it less (and lean on the agent more), and the agent itself gets worse because a deformed codebase is out-of-distribution. A self-accelerating loop.

So the reasoning gate alone isn't enough — an agent grading its own foundation hits a measured bias: LLM judges score their own familiar (low-perplexity) output higher ([arXiv 2410.21819](https://arxiv.org/abs/2410.21819)). The pack pairs the reasoning gate with a **measurement layer** — fitness functions and hooks that check structure mechanically, needing no good faith and no one to read the code.

The compact consumer rationale is in
[`docs/foundation/why-foundation-integrity.md`](./docs/foundation/why-foundation-integrity.md).
Research notes stay local and are never copied into downstream project context.

## What's in the box

| Skill | When | What it does |
| --- | --- | --- |
| `foundation-audit` | Before building anything non-trivial | Falsify the foundation claims the work depends on. Produces a receipt, a classification (`FOUNDATION_OK` / `SUSPECT` / `BLOCKED`), and a chosen route. |
| `adversarial-foundation-review` | Any foundation-surface touch, mismatch signal, or regressed fitness check — not only self-rated `SUSPECT`/`BLOCKED` | An independent session (ideally a different model) whose only job is to *refute* the audit's claim — kills the "the agent that wants to ship also grades its own foundation" conflict of interest. |
| `foundation-health` | Every few waves, separate from feature work | Reads accumulated signals (git churn, open ADRs, past receipts) and reports drift the per-feature gate can't see. |

Plus a **measurement layer** authored in [`templates/fitness/`](./templates/fitness/)
and [`templates/hooks/`](./templates/hooks/). Project adoption places
fitness guidance under `docs/foundation/fitness/`, executable Codex checks under
`.codex/hooks/scripts/` (or Claude checks under `.claude/hooks/scripts/`), and
runtime wiring in `.codex/hooks.json` or `.claude/settings.json`.

The pack also includes an **experimental, opt-in coworker pilot** authored in
[`templates/orchestration/`](./templates/orchestration/). Adoption projects only the
selected runtime profiles and transparent root primitives into
`.orchestration/foundation/`. Live output stays in the sessions or a root-selected
temporary directory. The pilot is not a skill, never creates a task-state tree, and
full-opt never activates it or installs FirstMate.

Shared names such as **Balloon** and **Brake** are documented as optional mnemonics in
[`docs/foundation/foundation-pattern-language.md`](./docs/foundation/foundation-pattern-language.md).
The names are never findings by themselves.

## Pinned Matt companion

The plugin includes 21 workflow skills selected from the pinned upstream manifest for
[`mattpocock/skills`](https://github.com/mattpocock/skills). The upstream setup skill
is intentionally omitted because this distribution already includes its issue,
domain, and triage configuration. Useful mechanisms from the user-supplied temporary
skills were researched and merged into the existing Matt owners instead of adding
duplicate phases: archetype fit in `codebase-design`, fake-pass and review-artifact
checks in `code-review`, proof-surface selection in `tdd`, and the compact goal
contract in `to-spec`.

Provenance, license, upstream hashes, local patch ledger, and the update contract live
under [`third_party/mattpocock-skills/`](./third_party/mattpocock-skills/). The three
Foundation Integrity skills and coworker protocol remain usable if the companion is
removed.

## Install

Choose one installation surface. Plugin installation gives you a managed, namespaced
bundle. Standalone installation puts unnamespaced skills directly in a project.

### One-command project adoption

For a personal repository that should own the skills and selected project assets
directly, run the bootstrap from the target repository. Existing `AGENTS.md` and
`CLAUDE.md` remain untouched:

```bash
# Codex full-opt
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --codex

# Claude full-opt
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude --full-opt

# Both runtimes: preview the complete inert payload
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --both --full-opt --dry-run
```

Full-opt is the only supported project payload; the bootstrap requires exactly one
of `--codex`, `--claude`, or `--both`. `--full-opt` is accepted for clarity but is
already the default. It always installs fitness guidance, active project hooks, and
inert orchestration policy for the selected runtime.
Blocking pre-push remains a separate `--with-pre-push` choice. Use `--directory <repo>` outside the target directory and
`--ref <tag-or-commit>` to select the payload revision.

The bootstrap resolves the requested ref to one commit, downloads that immutable
archive, prints the repository/ref/commit, and calls the project-local adopter. It
does not modify global runtime configuration, install profiles, open panes, or
activate orchestration. As with any `curl | bash` flow, inspect `scripts/install.sh`
or run `--dry-run` first when the source is not already trusted.

### Claude Code plugin

```
/plugin marketplace add long7400/foundation-integrity
/plugin install foundation-integrity@foundation-integrity
```

Claude loads the plugin's canonical `skills/` payload. Invoke a first-party skill with
the plugin namespace, for example:

```text
/foundation-integrity:foundation-audit Audit the foundation for FEATURE A before design.
```

### Codex plugin

```bash
codex plugin marketplace add long7400/foundation-integrity
codex plugin add foundation-integrity@foundation-integrity
```

Codex loads the recursive `skills/` root declared by `.codex-plugin/plugin.json`.
The three Foundation Integrity skills are explicit-only in Codex, so name them:

```text
Use $foundation-audit to audit the foundation for FEATURE A before design.
```

### Manual standalone project skills

The bootstrap above removes the need for manual copying. From an existing checkout,
you can still copy only the runtime projection:

```bash
# Claude Code
mkdir -p <repo>/.claude/skills
cp -R .claude/skills/. <repo>/.claude/skills/

# Codex
mkdir -p <repo>/.agents/skills
cp -R .agents/skills/. <repo>/.agents/skills/
```

Claude then invokes `/foundation-audit`; Codex still invokes
`$foundation-audit`. Do not copy the Codex projection into Claude or the Claude
projection into Codex: only Codex carries `agents/openai.yaml` metadata.

Detailed installation boundaries are in
[`docs/install/claude.md`](./docs/install/claude.md) and
[`docs/install/codex.md`](./docs/install/codex.md).

## First use

Run the gate before a solution, schema, interface, or migration is frozen. A useful
first prompt is:

```text
Audit the foundation that FEATURE A will load-bear on. Identify the owner, source of
truth, lifecycle and trust boundaries, intended versus observed behavior, mismatch
signals, proof surfaces, and the cheapest fake pass. Return one classification, one
outcome, and exactly one implementation route before proposing implementation.
```

The audit must return:

- `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or `FOUNDATION_BLOCKED`;
- `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`; and
- one route: Foundation-first, Bounded compatibility, or Feature-first.

Only `PROCEED` unlocks dependent implementation. Unknown load-bearing facts are
research blockers, not assumptions to hide under wrappers.

## Normal workflow

1. Run `foundation-audit` before `to-spec`, design, `tdd`, `implement`, or
   `prototype`.
2. If the route is Foundation-first, repair or introduce the missing primitive before
   the feature. If it is Bounded compatibility, record the boundary, owner, proof,
   lifecycle, migration/removal condition, and accepted cost.
3. When a foundation surface changed, a mismatch signal appeared, or a fitness check
   regressed, run `adversarial-foundation-review` in a separate top-level session.
   Give it an open falsification question, not a proposed answer to approve.
4. Implement in vertical slices with the proof surface chosen by the claim. Use
   `tdd` when a test is the strongest proof; use a validator, benchmark, runtime
   observation, contract evidence, or visual check when it is stronger.
5. Run `code-review` against both the governing spec and repository standards. For a
   foundation surface, require the fake-pass/architecture axis as well as green
   feature tests.
6. Run `foundation-health` every few execution waves or when recurring seams, churn,
   open compatibility layers, or repeated exceptions begin to accumulate.

The 21 pinned companion skills provide specification, design, implementation, TDD,
review, research, and productivity workflows. They compose after or around the gate;
they do not replace it.

## What installation does—and does not—activate

Plugin installation makes the 24 skills discoverable but does not mutate the
repository. The one-command project adopter is different: full-opt installs the
selected skill projection, four `docs/agents/` conventions, compact foundation docs,
fitness guidance, runtime hooks, inert orchestration policy, the local ADR template,
and the marked ignore block.

Codex still requires the project and exact hook definitions to be reviewed/trusted
through `/hooks`. Orchestration remains inert: installation copies policy/profile
files but does not open panes, install global profiles, or create live state.

## Full-opt local adopter

The remote bootstrap calls `templates/setup/full-opt.sh`. There is one payload:
full-opt. Runtime selection is the only payload dimension:

```bash
sh templates/setup/full-opt.sh --runtime codex --full-opt --dry-run <repo>
sh templates/setup/full-opt.sh --runtime codex --full-opt <repo>
sh templates/setup/full-opt.sh --runtime both --full-opt <repo>
```

Use `--runtime claude` for Claude only or `--runtime both` for both checked runtime
projections. Each selected projection contains the same 24 skills.

Full-opt always installs the selected skills and marked ignore block, exactly four
`docs/agents/` files, compact foundation docs, fitness guidance, active hooks, inert
orchestration, and `docs/adr/0000-template.md`. The installer is transparent and
idempotent. It:

- installs all 24 managed pack skills for each selected runtime while preserving
  unrelated consumer-owned skills outside those managed directories;
- creates a short consumer-neutral `AGENTS.md` only when the target has no
  `AGENTS.md`, while leaving existing `AGENTS.md` and `CLAUDE.md` byte-for-byte
  untouched;
- merges ignore rules for `.foundation/`, `.orchestration/`, `.codex/`, `.agents/`,
  `docs/research/`, `tmp/`, and personal
  numbered ADR history while preserving `docs/adr/0000-template.md`;
- copies the four `docs/agents/` conventions and customizes the GitHub tracker from
  `origin` when possible;
- never creates a downstream `templates/` directory;
- on a v2 upgrade, retires owned legacy template files but preserves empty legacy
  parent directories because the v2 ledger has file ownership only; an ambiguous
  pre-existing identical v3 path is a conflict, never silently claimed;
- on a v2 upgrade, preserves `AGENTS.md` and `CLAUDE.md` byte-for-byte and records a
  digest-bound pending journal; the still-authoritative v2 adoption lock records the
  exact operation plan and binds that exact journal before mutation, so an unbound or
  planted journal cannot claim an identical project file during recovery;
- places fitness guidance in `docs/foundation/fitness/`;
- places executable hooks under the selected runtime's `hooks/scripts/` directory,
  installs
  `.codex/hooks.json` and/or `.claude/settings.json` for selected runtimes, and refuses
  to black-box merge an existing differing config;
- places static coworker policy and transparent root primitives in
  `.orchestration/foundation/`, copying only the selected runtime profile subtree and
  creating no live orchestration state;
- writes `.foundation-integrity/adoption.tsv` with the distribution version, source
  ref/revision, payload digest, selected components, and content plus POSIX mode for
  every managed file/hook;
- installs the warn-only pre-commit hook when the target has a normal `.git/hooks`
  directory and no existing hook conflict; and
- installs the blocking pre-push hook only with `--with-pre-push`.

`--no-pre-commit` suppresses new pre-commit wiring. On a later adoption run it keeps
an unchanged pre-commit hook already owned by the adoption lock; it does not silently
uninstall that hook. Removal stays ledger-driven as described below.

It does **not** copy research working notes, duplicate the merged gitignore source,
install user-global profiles, enable a session-backend integration, open panes, or
activate orchestration.
Existing differing project files are reported and left untouched; the main setup
aborts before installer-managed writes when preflight detects a conflict. A
target-local `.foundation-integrity-install.lock` serializes applying runs and is
removed only when its ownership token still matches the process that acquired it.
Before each managed update/removal and each shared-file write, the installer
revalidates the state observed during preflight. A custom pre-commit hook is preserved
for manual composition.

The shell installer is not a transactional package manager. The target lock
serializes cooperating installer runs, not arbitrary editors or processes, and no
portable shell check can eliminate the final compare-to-write race against a
non-cooperating mutation. An I/O failure or such a race can leave partial state. Final
postconditions detect incomplete, mode-changed, or otherwise changed managed surfaces
when the changed state survives; they cannot prove that no concurrent edit was briefly
overwritten. Inspect the effects ledger and rerun after resolving the cause.

On a later distribution snapshot, a managed file is updated or removed only when its
current hash still matches the previous adoption lock. A consumer edit becomes a
conflict instead of being overwritten. Unrelated skills remain outside the managed
set; stale files or wrong-runtime metadata inside one of the 24 managed skill
directories are rejected.

A pre-existing non-skill file or git hook that is already byte-and-mode identical is
reported as external-identical and is not claimed for future update or removal.
Selected runtime skill directories are the exception: choosing that runtime explicitly
adopts its exact 24-skill projection.

Instruction ownership is outside the installer. Existing rules, imports, and any
transport-neutral coworker boundary remain exactly as the project currently defines
them. The full orchestration manuals and profiles remain inert until explicitly read
and activated.

After setup, customize the selected runtime's `hooks/scripts/foundation-surface.txt` and
adapt the matching rule under `docs/foundation/fitness/adapters/`. Hook configuration is already project-scoped;
existing differing runtime config is a preflight conflict, never a silent merge.

Removal is deliberately ledger-driven rather than a destructive uninstall command:
verify managed paths and hook hashes from `.foundation-integrity/adoption.tsv`, remove
only unchanged recorded files/hooks, remove the marked block from `.gitignore`, then
delete the lock. A newly-created generic `AGENTS.md` may appear in the first adoption
receipt, but a later run preserves it and transfers further edits to the project.
Modified managed files require an explicit human decision.

Companion tracker skills expect project-specific `docs/agents/` configuration. If it
is absent, they report the gap instead of invoking a hidden setup workflow.

## Local and canonical state

The distribution includes a root `.gitignore` and a reusable marked block that keeps
consumer-local `.foundation/`, `.orchestration/`, `.codex/`, `.agents/`, per-project
`docs/research/`, `tmp/`, and numbered personal ADR history out of commits.
`docs/adr/0000-template.md` remains trackable.
For full-opt consumers this is deliberate: runtime projections, hook policy, and
inert orchestration stay local, while the non-ignored
`.foundation-integrity/adoption.tsv` binds their source revision, hashes, and modes
for conflict-safe upgrades. Review the pinned source/effects ledger before adoption;
do not mistake ignored payload for repository-reviewed configuration.
Plugin managers install
into their own caches and do not create `docs/research/` or mutate a consumer
repository's `.gitignore`; standalone skill installs copy only their runtime skill
projection. Direct repo installs must merge the supplied ignore block explicitly
rather than relying on hidden setup.

Do not publish working research merely because it exists. Promote only the accepted,
decision-lossless conclusion into its canonical owner; keep the exploratory note
ignored.

## Maintainers: why all three skill trees exist

`skills/` is not redundant. It is the sole authoring source and the payload consumed
by both plugin manifests. `.claude/skills/` and `.agents/skills/` are generated
standalone project projections.

Never edit a projection directly. After changing a canonical skill, run:

```bash
sh scripts/sync-runtime-skills.sh
sh tests/repo-contracts.sh
```

The sync builds both projections before replacing either one and removes Codex-only
metadata from Claude. Deleting `skills/` would break both plugin manifests, the
provenance hash paths, and the one-way source-of-truth contract.

## Advanced: optional coworker pilot

The project-owned material under `.orchestration/foundation/` is a measured
experiment, not an installed skill or default workflow. It requires one root controller, fresh
top-level sessions, explicit role/model envelopes, non-overlapping write scopes,
root-owned validation locks, and digest-bound evidence. Workers receive the task
contract, not transport topology. Runtime status is never acceptance evidence.
The executable receipt-bound Herdr lifecycle and real smoke are presently the Codex
pilot; the Claude material is an explicitly narrower static launch envelope.

A release that claims the Codex envelope must run the binary-bound runtime tier; the
portable repository contracts alone do not make that claim:

```bash
export FI_CODEX_BIN=/absolute/path/from-audited-install-record/codex
export FI_CODEX_SHA256=<sha256-from-that-independent-record>
sh tests/codex-orchestration-acceptance.sh
```

The tier fails closed on a missing or mismatched declared identity. It proves that the
observed file bytes match the supplied digest; it does not authenticate that digest
or a hostile local verifier toolchain. Use a trusted shell/Python/hash environment
and an authenticated independent installation or release record, not a digest
resolved from the current `PATH` inside the same acceptance command.

Start with a bounded comparison against a single-agent baseline and keep the pilot
only if it finds material counterevidence worth its coordination cost.

References: [Claude project skills](https://code.claude.com/docs/en/skills),
[Claude plugins](https://code.claude.com/docs/en/plugins),
[Codex customization](https://learn.chatgpt.com/docs/customization/overview#skills),
and [Codex plugin structure](https://developers.openai.com/codex/plugins/build).

## License

MIT.
