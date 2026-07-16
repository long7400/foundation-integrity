# Foundation Integrity project convention

This repository treats feature correctness as necessary but not sufficient. Before a
non-trivial feature, module, migration, refactor, or security/reliability/performance
change, falsify the load-bearing foundation claims first.

The canonical operating rules live in the consumer's existing `AGENTS.md` or
`CLAUDE.md`. When `AGENTS.md` is absent, installation creates a short consumer-neutral
one; an existing instruction file is never modified or claimed.
The three reusable project references are
`docs/foundation/foundation-audit.md`,
`docs/foundation/foundation-pattern-language.md`, and
`docs/foundation/why-foundation-integrity.md`.

Project-specific receipts belong under ignored `docs/foundation/receipts/`; the
directory keeps only `.gitkeep` in version control. Working research likewise belongs
under ignored `docs/research/`. These are local evidence surfaces, not canonical
project truth. Promote only the decision-lossless subset that the project truly needs
to share into an explicitly tracked owner.

The required vocabulary is:

- `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or `FOUNDATION_BLOCKED`;
- exactly one route: Foundation-first, Bounded compatibility, or Feature-first;
- exactly one outcome: `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`;
- one named source of truth, canonical invariant, proof surface, and compatibility
  lifecycle where applicable.

Optional names such as Balloon and Brake are mnemonics only. They never replace the
evidence-backed foundation claim.

External coworker mode is opt-in. When the user explicitly requests it and
`HERDR_ENV=1`, the root may read `.orchestration/foundation/README.md` and only the
selected runtime adapter. Ordinary sessions must not load orchestration policy.
