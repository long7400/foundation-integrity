# Foundation Integrity project convention

This repository treats feature correctness as necessary but not sufficient. Before a
non-trivial feature, module, migration, refactor, or security/reliability/performance
change, falsify the load-bearing foundation claims first.

The canonical operating rules live in `AGENTS.md` or `CLAUDE.md`. The reusable block
is `templates/claude-md-block.md`; the receipt guide is
`templates/docs/foundation-audit.md`; the rationale is
`templates/docs/why-foundation-integrity.md`.

Project-specific receipts belong under `docs/foundation/receipts/`. Working research
belongs under ignored `docs/research/` and must be promoted into an ADR, receipt,
`CONTEXT.md`, or another canonical owner before it becomes a durable decision.

The required vocabulary is:

- `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, or `FOUNDATION_BLOCKED`;
- exactly one route: Foundation-first, Bounded compatibility, or Feature-first;
- exactly one outcome: `PROCEED`, `RESEARCH_ONLY`, or `NO_GO`;
- one named source of truth, canonical invariant, proof surface, and compatibility
  lifecycle where applicable.

Optional names such as Balloon and Brake are mnemonics only. They never replace the
evidence-backed foundation claim.
