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
[`templates/docs/why-foundation-integrity.md`](./templates/docs/why-foundation-integrity.md).
Research and context-activation evidence stay in repository ADRs, especially
[`ADR-0004`](./docs/adr/0004-context-budget-and-coworker-routing.md), so downstream
projects do not inherit the pack's research bibliography.

## What's in the box

| Skill | When | What it does |
| --- | --- | --- |
| `foundation-audit` | Before building anything non-trivial | Falsify the foundation claims the work depends on. Produces a receipt, a classification (`FOUNDATION_OK` / `SUSPECT` / `BLOCKED`), and a chosen route. |
| `adversarial-foundation-review` | Any foundation-surface touch, mismatch signal, or regressed fitness check — not only self-rated `SUSPECT`/`BLOCKED` | An independent session (ideally a different model) whose only job is to *refute* the audit's claim — kills the "the agent that wants to ship also grades its own foundation" conflict of interest. |
| `foundation-health` | Every few waves, separate from feature work | Reads accumulated signals (git churn, open ADRs, past receipts) and reports drift the per-feature gate can't see. |

Plus a **measurement layer** the skills lean on ([`templates/fitness/`](./templates/fitness/) + [`templates/hooks/`](./templates/hooks/)): tech-neutral fitness *intents*, claim-to-proof-surface selection, a git-only tier that runs in any repo, per-stack adapters, and hooks — git-level (runtime-neutral) plus Claude and Codex — that run the checks whether or not the agent cooperates.

The pack also includes an **experimental, opt-in coworker pilot** in [`templates/orchestration/`](./templates/orchestration/). It keeps terminal/session transport separate from workflow authority, uses Codex profile overlays and Claude launch envelopes rather than a transport-control skill inside workers, and ships a machine-checked role/model matrix, root-only validation/controller locks, fresh-session policy, digest-bound current-state/worker/transcript artifacts, and a controlled [weak-foundation baseline benchmark](./templates/orchestration/weak-foundation-benchmark.md). The validators check declarations and artifact binding; they do not prove effective runtime state, reasoning quality, or correctness. The pilot is not a skill; explicit `full-opt` adoption copies its inert templates but never activates it. It does not depend on or install FirstMate.

Shared names such as **Balloon** and **Brake** are documented as optional mnemonics in [`templates/docs/foundation-pattern-language.md`](./templates/docs/foundation-pattern-language.md). The names are never findings by themselves; each must resolve to a foundation claim, primary evidence, a disconfirming probe, and a fitness check or an explicit semantic-only limit.

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

For a personal repository that should own the skills and policy files directly, run
the bootstrap from the target repository:

```bash
# Codex: lightweight core (default)
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --codex

# Claude: core plus the optional fitness layer
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude --with-fitness

# Both runtimes: preview the complete inert payload
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --both --full-opt --dry-run
```

The remote bootstrap defaults to `--core`; it requires exactly one of `--codex`,
`--claude`, or `--both`. `--with-fitness` adds measurement templates,
`--with-hooks` adds warn-only hook assets and implies fitness,
`--with-orchestration` copies the inert coworker pilot, and `--full-opt` selects all
three optional surfaces. Blocking pre-push remains a separate `--with-pre-push`
choice. Use `--directory <repo>` outside the target directory and
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

Installing the plugin automatically makes the 24 skills discoverable. It does not
silently mutate the consumer repository.

The following remain explicit, reviewable adoption steps:

- merge the operating-rule block into the canonical `AGENTS.md` or `CLAUDE.md`;
- customize/copy `docs/agents/` if tracker, domain, or triage workflows are wanted;
- merge the supplied `.gitignore` block;
- select fitness adapters and wire git/runtime hooks;
- create `docs/research/` only when research actually runs; and
- enable the experimental coworker pilot.

This distinction is intentional: files present in the distribution are not claimed
to be active in a project until that project adopts them.

## Project adoption presets and local adopter

The remote bootstrap calls `templates/setup/full-opt.sh`. The bootstrap defaults to
the lightweight `core` preset; direct local use retains the historical `full-opt`
default. Prefer an explicit preset when scripting:

```bash
sh templates/setup/full-opt.sh --runtime codex --core --dry-run <repo>
sh templates/setup/full-opt.sh --runtime codex --core <repo>
sh templates/setup/full-opt.sh --runtime both --full-opt <repo>
```

Use `--runtime claude` for Claude only or `--runtime both` for both checked runtime
projections. Each selected projection contains the same 24 skills.

Core always installs the selected skills, the marked instruction and ignore blocks,
exactly four `docs/agents/` files, compact consumer docs/ADR, and setup helpers.
Fitness, hooks, and orchestration are additive selections. The installer is
transparent and idempotent. It:

- installs all 24 managed pack skills for each selected runtime while preserving
  unrelated consumer-owned skills outside those managed directories;
- merges the marked Foundation Integrity block into the resolved instruction owner;
- creates a Claude `@AGENTS.md` shim only when Claude is selected, `AGENTS.md` is the
  owner, and no substantive `CLAUDE.md` would be displaced;
- merges ignore rules for `.foundation/`, `docs/research/`, and `tmp/`;
- copies the four `docs/agents/` conventions and customizes the GitHub tracker from
  `origin` when possible;
- copies `templates/adr`, compact consumer docs, and setup helpers, plus only the
  selected `fitness`, `hooks`, and orchestration surfaces;
- writes `.foundation-integrity/adoption.tsv` with the distribution version, source
  ref/revision, payload digest, selected components, and content plus POSIX mode for
  every managed file/hook;
- installs the warn-only pre-commit hook when the target has a normal `.git/hooks`
  directory and no existing hook conflict; and
- installs the blocking pre-push hook only with `--with-pre-push`.

`--no-pre-commit` suppresses new pre-commit wiring. On a later adoption run it keeps
an unchanged pre-commit hook already owned by the adoption lock; it does not silently
uninstall that hook. Removal stays ledger-driven as described below.

It does **not** copy research working notes, duplicate the already-merged
`claude-md-block`/gitignore source templates, merge runtime hook samples, install user
profiles, enable a session-backend integration, open panes, or activate orchestration.
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

A fresh Claude-only setup normally owns its block in `CLAUDE.md`; Codex requires
`AGENTS.md`. Expanding that repository later to Codex or both runtimes therefore
requires a deliberate instruction-owner migration. The installer refuses to move or
delete that policy automatically. Reconcile the managed block into `AGENTS.md`, make
`CLAUDE.md` a reviewed `@AGENTS.md` shim when appropriate, and rebuild the adoption
lock in a clean branch rather than allowing two owners.

The merged instruction block does retain a small transport-neutral safety boundary
for any future coworker run (one root, no native second control plane, status is not
proof). The full orchestration manuals and profiles remain inert until explicitly
read and activated.

After setup, customize `templates/hooks/foundation-surface.txt` and select or adapt a
stack rule under `templates/fitness/adapters/`. Runtime hook samples remain explicit
manual merges because project settings may already contain unrelated policy.

Removal is deliberately ledger-driven rather than a destructive uninstall command:
verify managed paths and hook hashes from `.foundation-integrity/adoption.tsv`, remove
only unchanged recorded files/hooks, remove the two marked blocks from the instruction
owner and `.gitignore`, then delete the lock. Modified files require an explicit
human decision.

Companion tracker skills expect project-specific `docs/agents/` configuration. If it
is absent, they report the gap instead of invoking a hidden setup workflow.

## Local and canonical state

The distribution includes a root `.gitignore` and a reusable marked block that ignore
all `.foundation/` runtime/research/plan/orchestration state, per-project
`docs/research/` notes, and `tmp/`. Canonical records belong under `docs/adr/`,
`docs/foundation/receipts/`, `docs/agents/`, or `CONTEXT.md`. Plugin managers install
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

The material under `templates/orchestration/` is a measured experiment, not an
installed skill or default workflow. It requires one root controller, fresh
top-level sessions, explicit role/model envelopes, non-overlapping write scopes,
root-owned validation locks, and digest-bound evidence. Workers receive the task
contract, not transport topology. Runtime status is never acceptance evidence.

Start with a bounded comparison against a single-agent baseline and keep the pilot
only if it finds material counterevidence worth its coordination cost.

References: [Claude project skills](https://code.claude.com/docs/en/skills),
[Claude plugins](https://code.claude.com/docs/en/plugins),
[Codex customization](https://learn.chatgpt.com/docs/customization/overview#skills),
and [Codex plugin structure](https://developers.openai.com/codex/plugins/build).

## License

MIT.
