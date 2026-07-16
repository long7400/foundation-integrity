# Hooks — the enforcement layer

A `SKILL.md` rule is *self-enforced*: the agent decides whether to obey it. That's
exactly the trust the core problem says you don't have. Hooks are the answer — they
run **whether or not the agent wants them to**, so they move enforcement out of
good-faith and into the runtime.

Hooks **complement** the reasoning gate; they don't replace it. A hook can
mechanically check "a foundation-surface file changed and no ADR was written" or "the
fitness rules still pass." It cannot decide "is this foundation sound" — that's still
`foundation-audit` + `adversarial-foundation-review`.

## Two enforcement layers, by reach

| Layer | File | Runtime | Authority |
| --- | --- | --- | --- |
| **Git hooks** | `.git/hooks/pre-commit`, optional `.git/hooks/pre-push` | both (Claude + Codex + humans) | runtime-neutral, canonical |
| **Agent hooks** | `.claude/settings.json`, `.codex/hooks.json` | one per runtime | fast local feedback |

The **git layer is the source of truth** — it fires for every actor (both agents and
a human on the CLI), so a foundation check that lives there can't be sidestepped by
switching runtime. The **agent layer** is a faster feedback loop: it fires *during*
the session (on tool use, on stop) so drift is caught at the moment it's written, not
at commit time. Wire both; they reinforce, they don't duplicate.

Codex project hooks load only for a trusted project and changed non-managed command
hooks require review/trust. Use `/hooks` to inspect the exact definition before
expecting the Codex wiring to run. See the official
[Codex Hooks documentation](https://learn.chatgpt.com/docs/hooks) for the current
event, matcher, stdin, and exit-status contract.

All configs invoke the managed scripts installed at the selected runtime owner:
`.codex/hooks/scripts/` for Codex or `.claude/hooks/scripts/` for Claude. The source
of truth remains `templates/hooks/scripts/`; the installed copies are runtime
payload, while the git hook loader keeps the enforcement runtime-neutral. The Codex
file is a real project hook definition, not an inert TOML fragment.

For a both-runtime adoption, `.foundation-integrity/adoption.tsv` records `runtime=both`.
The git loader requires the shared Codex and Claude copies to be byte-identical, then
uses the Codex copy as the explicit git authority. Pre-commit warns and returns; the
blocking pre-push fails closed when either copy is missing or they diverge. A missing,
invalid, or runtime/path-mismatched adoption ledger follows the same posture:
pre-commit warns, while pre-push blocks rather than guessing another owner.

## The managed scripts

- `<runtime>/hooks/scripts/fitness-check.sh` — run the wired tier-3 adapter (if
  any) plus a cheap tier-2 delta. Non-zero exit = a structural rule broke. Fast; safe
  to run on every edit/commit.
- `<runtime>/hooks/scripts/foundation-surface-guard.sh` — did this
  change touch a **foundation-surface** path (public API, schema, migration, auth,
  core domain, shared module) without a **valid v2 receipt in the same change set that
  names that exact path**? (Receipt format: [`review-receipt.md`](./review-receipt.md);
  the guard parses the delimited block, checks required fields + enums, binds the exact
  revision and changed-content digest, and matches paths exactly — no substring,
  spaces-safe.) Warns (or blocks, if you opt in). Two eval
  modes: worktree (pre-commit, mid-session) and range (pre-push, via
  `FI_RANGE=base..head`) so it also sees already-committed changes. This is the
  **observable trigger** for `adversarial-foundation-review` — it fires on a fact (a
  named surface file changed), never on the agent's self-rating.

  Two **trust** modes, set by `FI_REVIEW_MODE`:
  - **advisory** (default) — a valid receipt clears the change. The receipt is
    author-writable, so this buys a versioned audit trail + visible, deliberate
    skipping, not proof a review ran. Right for a solo/trusted-agent setup.
  - **attested** (opt-in) — clearing *also* requires the pushed tip to be a commit
    signed by a key on `FI_TRUSTED_REVIEWERS` (a `fingerprint<TAB>identity` file kept
    **outside** the working tree), and the receipt's `reviewer` must equal that
    identity. Resists a single agent that can edit files but not sign as the reviewer.
    Engages in range mode only (needs committed history); fails closed. Authoritative
    only when protected CI re-runs it — a local hook is bypassable.

## Proportionality — the rule that keeps hooks alive

A hook that blocks every edit until an ADR exists is unusable, so it gets disabled —
and a disabled hook is **worse than none** (it reads as safety that isn't there).
Therefore:

- Scope every hook to **foundation-surface paths only** (configured in
  `<runtime>/hooks/scripts/foundation-surface.txt`). Edits elsewhere pass silently.
- Default posture is **warn**, not block. Blocking (`exit 2` in Claude, non-zero in
  git) is opt-in, and only for the surface-guard on a pre-push — never on every keystroke.
- The pre-commit stays fast (delta only). Full fitness runs on pre-push / CI.
- Ignored numbered ADRs can clear only the local worktree advisory check. A blocking
  pushed-range check needs a tracked receipt in the pushed commit.

## What the surface-guard does — and what it honestly can't

It's the mechanism that *narrows* **Gap 1** (self-attestation). The old escape hatch
only triggered `adversarial-foundation-review` when the agent *self-rated*
SUSPECT/BLOCKED — so an agent that rated itself OK never got reviewed. The surface-guard
triggers on an **observable condition** (a surface file changed with no ADR/receipt
naming it) regardless of the self-rating. That removes the self-grade escape.

Be honest about the ceiling, though:

- It detects that a **decision was recorded** (a receipt naming the path), **not that
  an independent review actually ran, nor that it was any good.** A receipt is a text
  artifact an agent can write. What it buys is *visibility and cost* — a named,
  version-controlled verdict a human or a different-model check can later audit —
  not cryptographic proof.
- A hook **prints instructions**; it does not launch or verify a separate review
  session. Wiring the actual second-model review is a human/harness step.
- Blocking is bypassable (`--no-verify`, editing settings). Against a completion-biased
  agent that's usually enough — the goal is to make skipping deliberate and visible,
  not impossible. Against an adversarial one, it isn't a control.

See "Residual limits" in `docs/foundation/why-foundation-integrity.md`.
