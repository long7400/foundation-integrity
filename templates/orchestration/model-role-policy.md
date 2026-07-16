# Role and model policy

Status: **opt-in pilot policy**.

There are three authority roles: `root`, `peer`, and `implementer`. Only the root
controls external sessions, validation leases, acceptance, release, and teardown.

Use the supplied runtime profiles as explicit launch envelopes:

- `fi-root-lead` — sole controller; native subagents disabled;
- `fi-peer-scout` — read-only mechanism discovery; no difficult final verdict;
- `fi-peer-challenge` — read-only independent challenge and strongest alternative;
- `fi-implementer-mechanical` — bounded, well-specified writer;
- `fi-implementer-ambiguous` — high-coupling writer that audits assumptions first.

Model and effort choices live in those reviewed profile files, not in a second matrix.
They select capability and cost; they never grant claim or workflow authority. A
launch failure must not silently fall back to another profile.

Profiles are not security boundaries. Observe the effective model, effort,
permissions, sandbox, cwd/worktree, and disabled native-control surface at runtime.
Use a fresh session for clean-room review. Resume is continuity only until that full
envelope can be attested.

For the Codex pilot, a supported profile name is insufficient: root and coworker
operations require exact pack-source bytes plus v2 install-manifest provenance, and
their launch argv binds CLI overrides for the same-key envelope above project config.
Project-owned instructions, rules, and hooks remain visible by design; profiles do
not turn a trusted project into a security boundary.
