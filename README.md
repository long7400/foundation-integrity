# Foundation Integrity

A small set of agent skills that add one thing most workflow skill packs leave out: **a gate that checks the foundation is sound _before_ you build a feature on it** — instead of letting a capable agent bend logic and stack wrappers to make the feature fit a weak foundation.

Works with both **Claude Code** (as a plugin) and **OpenAI Codex** (via `agents/openai.yaml` in each skill). Every skill is one `SKILL.md` shared by both runtimes.

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
| `setup-foundation-integrity` | Once per repo | Detects your stack and existing workflow pack, then wires the gate, the fitness adapter, and the hooks into `CLAUDE.md` / `AGENTS.md` and CI. |

Plus a **measurement layer** the skills lean on ([`templates/fitness/`](./templates/fitness/) + [`templates/hooks/`](./templates/hooks/)): tech-neutral fitness *intents*, a git-only tier that runs in any repo, per-stack adapters (dependency-cruiser / ArchUnit / import-linter / go-arch-lint), and hooks — git-level (runtime-neutral) plus Claude and Codex — that run the checks whether or not the agent cooperates.

The pack also includes an **experimental, opt-in coworker pilot** in [`templates/orchestration/`](./templates/orchestration/). It keeps terminal/session transport separate from workflow authority, uses Codex profile overlays and Claude launch envelopes rather than a transport-control skill inside workers, and ships a machine-checked role/model matrix, root-only validation/controller locks, fresh-session policy, digest-bound current-state/worker/transcript artifacts, and a controlled [weak-foundation baseline benchmark](./templates/orchestration/weak-foundation-benchmark.md). The validators check declarations and artifact binding; they do not prove effective runtime state, reasoning quality, or correctness. The pilot is not installed by `setup-foundation-integrity`, does not add a new skill, and does not depend on or install FirstMate.

Shared names such as **Balloon** and **Brake** are documented as optional mnemonics in [`templates/docs/foundation-pattern-language.md`](./templates/docs/foundation-pattern-language.md). The names are never findings by themselves; each must resolve to a foundation claim, primary evidence, a disconfirming probe, and a fitness check or an explicit semantic-only limit.

## Composes with Matt Pocock's skills — bundles none of them

If [`mattpocock/skills`](https://github.com/mattpocock/skills) is installed, `setup-foundation-integrity` wires `foundation-audit` before `to-spec` or any architecture is frozen, and points the `code-review` foundation lens at the same signals. If a spec already exists, the audit runs immediately before design/code. If the other pack isn't installed, everything runs standalone. This pack never vendors or forks another pack's files — integration is a single reference line, not a copy.

## Install

**Claude Code**

```
/plugin marketplace add long7400/foundation-integrity
/plugin install foundation-integrity@foundation-integrity
/setup-foundation-integrity
```

**Codex** — point your skills loader at this repo; each skill's `agents/openai.yaml` supplies the Codex interface.

## License

MIT.
