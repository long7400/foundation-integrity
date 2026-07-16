# Foundation Integrity orchestration pilot

This directory is an inert, project-owned policy projection. It is not a skill and
does not open panes, install profiles, mutate global config, or create runtime state.

Use it only when the user explicitly requests an external coworker pilot and
`HERDR_ENV=1`. The root reads `model-role-policy.md`, `coworker-protocol.md`, only
`runtime/codex.md` or `runtime/claude.md` for the active runtime, and the matching
`run-contract`/matrix. Workers receive an
open task packet and safety scope; they do not receive transport topology or control
authority.

Static policy lives here. Live locks, runs, transcripts, and worker artifacts belong
under ignored `.foundation/orchestration/`. A parked run is not accepted until the
root reconciles its artifacts and promotes any decision-lossless evidence to the
project's chosen durable owner.

The installer copies only the selected runtime profile subtree. It never copies the
other runtime's profiles and never activates the pilot automatically.
