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

The full write-up — with sources — is in [`templates/docs/why-foundation-integrity.md`](./templates/docs/why-foundation-integrity.md).

## What's in the box

| Skill | When | What it does |
| --- | --- | --- |
| `foundation-audit` | Before building anything non-trivial | Falsify the foundation claims the work depends on. Produces a receipt, a classification (`FOUNDATION_OK` / `SUSPECT` / `BLOCKED`), and a chosen route. |
| `adversarial-foundation-review` | Any foundation-surface touch, mismatch signal, or regressed fitness check — not only self-rated `SUSPECT`/`BLOCKED` | An independent session (ideally a different model) whose only job is to *refute* the audit's claim — kills the "the agent that wants to ship also grades its own foundation" conflict of interest. |
| `foundation-health` | Every few waves, separate from feature work | Reads accumulated signals (git churn, open ADRs, past receipts) and reports drift the per-feature gate can't see. |

Plus a **measurement layer** the skills lean on ([`templates/fitness/`](./templates/fitness/) + [`templates/hooks/`](./templates/hooks/)): tech-neutral fitness *intents*, claim-to-proof-surface selection, a git-only tier that runs in any repo, per-stack adapters, and hooks — git-level (runtime-neutral) plus Claude and Codex — that run the checks whether or not the agent cooperates.

The pack also includes an **experimental, opt-in coworker pilot** in [`templates/orchestration/`](./templates/orchestration/). It keeps terminal/session transport separate from workflow authority, uses Codex profile overlays and Claude launch envelopes rather than a transport-control skill inside workers, and ships a machine-checked role/model matrix, root-only validation/controller locks, fresh-session policy, digest-bound current-state/worker/transcript artifacts, and a controlled [weak-foundation baseline benchmark](./templates/orchestration/weak-foundation-benchmark.md). The validators check declarations and artifact binding; they do not prove effective runtime state, reasoning quality, or correctness. The pilot is not a skill or an automatic setup path, and does not depend on or install FirstMate.

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

### Standalone project skills

From a checkout of this repository, copy the projection for the runtime you use:

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

## Optional full repository adoption

For a transparent project-level setup, copy only the surfaces you choose from a
source checkout and review the diff:

```bash
TARGET=<repo>

mkdir -p "$TARGET/docs/agents"
cp -R docs/agents/. "$TARGET/docs/agents/"
cp -R templates "$TARGET/"
```

Then:

1. Run `sh templates/setup/resolve-instruction-target.sh "$TARGET"` to identify
   whether `AGENTS.md` or `CLAUDE.md` is the canonical instruction owner. Merge
   `templates/claude-md-block.md` manually; the script does not edit it for you.
2. Merge the marked block from
   `templates/gitignore/foundation-integrity.gitignore` into the target `.gitignore`.
3. Adjust `templates/hooks/foundation-surface.txt` and choose a stack adapter under
   `templates/fitness/adapters/`.
4. Install git hooks explicitly if desired:

   ```bash
   cp templates/hooks/git/pre-commit .git/hooks/pre-commit
   cp templates/hooks/git/pre-push .git/hooks/pre-push
   chmod +x .git/hooks/pre-commit .git/hooks/pre-push
   ```

5. Merge the Claude or Codex runtime-hook sample only after reviewing it. Runtime
   samples warn by default; the supplied pre-push hook is the explicit blocking tier.

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
