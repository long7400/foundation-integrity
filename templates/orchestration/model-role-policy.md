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

Two optional cost-saving envelopes use `glm-5.2` only for the two bounded work
classes:

- `fi-glm-peer-scout` — read-only discovery and evidence collection;
- `fi-glm-implementer-mechanical` — well-specified mechanical implementation in an
  explicit write scope.

They use `model_reasoning_effort = "max"`, cap the context window at 272,000 tokens,
and never replace the five primary profiles or the default provider. They are not
approved for root, challenge, ambiguous implementation, or final acceptance.

Model and effort choices live in those reviewed profile files, not in a second matrix.
They select capability and cost; they never grant claim or workflow authority. A
launch failure must not silently fall back to another profile.

The GLM profiles are owned separately by the pinned loopback gateway lifecycle:
`cliproxy-glm.sh setup` installs only those two profiles and records their hashes;
`remove` deletes only unchanged copies plus gateway state and credentials. The
primary five-profile manager and v2 attester do not claim those paths. This avoids a
second owner while keeping custom-provider availability and removal explicit.

Profiles are not security boundaries. Observe the effective model, effort,
permissions, sandbox, cwd/worktree, and disabled native-control surface at runtime.
Use a fresh session for clean-room review. Resume is continuity only until that full
envelope can be attested.

For the Codex pilot, a supported profile name is insufficient: root and coworker
operations require exact pack-source bytes plus v2 install-manifest provenance, and
their launch argv binds CLI overrides for the same-key envelope above project config.
Project-owned instructions, rules, and hooks remain visible by design; profiles do
not turn a trusted project into a security boundary.

The two GLM auxiliaries are a bounded compatibility tier rather than part of that
five-profile receipt-bound launcher. If used as external coworkers, Herdr must still
own creation, task delivery, bounded waits, output inspection, and teardown; a plain
terminal or native subagent is not an acceptable substitute. Gateway health and a
credentialed smoke are separate acceptance evidence.
