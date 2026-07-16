# Distribution provenance capsule

This is not a research bibliography. It preserves the minimum audit path for
operational claims copied into a consumer project.

The local adoption is bound by `.foundation-integrity/adoption.tsv`, which records:

- distribution version and source revision;
- an exact payload SHA-256 digest;
- selected runtime and instruction owner; and
- SHA-256 hashes for every managed file and installed hook.

Distribution-side decisions remain in the canonical source repository,
`https://github.com/long7400/foundation-integrity`:

- context activation and the 24-skill contract: `docs/adr/0004-context-budget-and-coworker-routing.md`;
- transparent coworker transport and resume boundary: `docs/adr/0001-transparent-coworker-pilot.md`;
- full-opt ownership and lifecycle: `docs/adr/0005-transparent-full-opt-adoption.md`.

The coworker resume claim was last grounded against Herdr source revision
`d0111c9f9022e0ec26d8f03236a91b026b567d45`. Mechanisms compared but not installed
were inspected at revision `e063ca5e2459ea8cbcefb1d58310b3617318bfb8`.

After a runtime or transport upgrade, treat those operational claims as stale until
the distribution revalidates them. The adoption lock identifies which distribution
snapshot the consumer received without forcing its bibliography into ordinary
project context.
