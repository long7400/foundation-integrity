# Herdr + Codex adapter

This maps the [coworker protocol](../coworker-protocol.md) to fresh top-level Codex
sessions. It is not a skill, native subagent setup, or FirstMate installation.

## Effects and ownership

- Herdr owns PTYs, panes, input, bounded reads/waits, attention status, and optional
  display metadata.
- Project-owned envelope files own the reviewed model/effort, sandbox, approval,
  provider, role instruction, and both native-delegation feature disables. The
  launcher passes them as explicit CLI overrides; named Codex profiles are not used.
- Project `AGENTS.md` remains the durable instruction owner.
- The root owns the task graph, validation lease, acceptance, release, and teardown.

Herdr owns lifecycle status. The dedicated SessionStart hook may report the real Codex
session ID for continuity, while the display hook uses only `pane.report_metadata`.
Neither hook reports acceptance or takes over `report-agent` state authority.

## Project envelopes

Review the adopted files under `.orchestration/foundation/profiles/codex/`. The
shared attester verifies the project file, adoption ledger, and role card, then
derives the complete CLI envelope. No setup command writes profiles or manifests to
Codex home. Do not install a transport-control skill for coworkers. Only
`fi-root-lead` contains controller behavior; non-root profiles contain no Herdr
commands or topology.

One shared attester is used by root authorization, launch, submit, and wait. It
requires the project envelope's device/inode/hash to remain stable and its bytes to
match the adoption ledger or tracked source tree. A hand-written or drifted file is
not launch authority. The attester derives canonical CLI overrides for model,
effort, sandbox, approval, provider, both known native-delegation feature flags, and
role instructions. Receipts bind the observed argv and full project provenance.

Project `AGENTS.md`, model instruction sources, rules, and reviewed hooks remain
model-visible by design. The role developer instruction has higher authority than
those project instructions, but it is not semantic isolation from the project. The
pilot protects against same-key configuration replacement and accidental personnel
control; it is not a sandbox against a malicious trusted repository.

### Optional GLM-5.2 auxiliaries

The two lower-cost GLM profiles are a separate bounded compatibility tier. They do
not replace or share ownership with the five primary envelopes above:

- `fi-glm-peer-scout` — read-only mechanism inventory and evidence collection;
- `fi-glm-implementer-mechanical` — well-specified mechanical work in an explicit
  write scope.

Both use `glm-5.2` at `max`, cap `model_context_window` at 272,000, and point Codex
Responses traffic at a pinned loopback CLIProxyAPI gateway. The gateway translates
to Z.AI Chat Completions while keeping the default Codex provider unchanged.

```sh
sh .orchestration/foundation/scripts/cliproxy-glm.sh setup
sh .orchestration/foundation/scripts/cliproxy-glm.sh start
eval "$(sh .orchestration/foundation/scripts/cliproxy-glm.sh print-env)"
python3 .orchestration/foundation/scripts/attest-codex-profile.py fi-glm-peer-scout

sh .orchestration/foundation/scripts/cliproxy-glm.sh doctor
sh .orchestration/foundation/scripts/cliproxy-glm.sh remove
```

`setup` prompts without echo, verifies the pinned release checksum, binds the
project-local profile files by hash, writes owner-only state under
`.foundation/cliproxy-glm/`, generates a separate local client key, and binds only to
`127.0.0.1`. `remove` stops the process and deletes only this project's gateway
credentials/state; it never touches Codex home.

These two profiles are project-local and are bound by the project gateway manifest.
Launch additionally requires `FI_CLIPROXY_KEY` and a successful
gateway doctor check. Their complete session lifecycle still goes through Herdr—
creation, launch, task send, bounded wait, output inspection, and teardown—and the
root records gateway health plus a credentialed inference/tool smoke. Do not
substitute a native subagent or manually spawned terminal agent.

## Root workflow

From a plain shell in the intended Herdr root pane, pre-attest and `exec` the root.
The receipt path must be new and root-owned:

```sh
exec sh .orchestration/foundation/scripts/launch-codex-root.sh \
  "${TMPDIR:-/tmp}/fi-root.launch.json" "$PWD"
```

The `exec` preserves PID/start identity across the bootstrap-to-Codex boundary and
exports the receipt path into that root process. The bootstrap refuses an existing
receipt path. Keep it only for that live root; after revoke and root exit, remove it
from the root-selected temporary directory. Load-bearing role fields are repeated as
CLI overrides so project `.codex/config.toml` cannot re-enable native delegation or
replace the root envelope. Then, from the Codex root session:

```sh
herdr agent rename "${HERDR_PANE_ID:?}" fi-root-lead
export FI_VALIDATION_TOKEN="$(sh .orchestration/foundation/scripts/validation-lease.sh authorize)"

# Single-coworker path: start a fresh coworker and retain the bound launch receipt.
sh .orchestration/foundation/scripts/start-codex-coworker.sh \
  claim-falsifier fi-peer-challenge >"${TMPDIR:-/tmp}/claim-falsifier.launch.json"

# Type the packet once, press Enter, and verify the pane actually becomes working.
sh .orchestration/foundation/scripts/submit-coworker-turn.sh \
  "${TMPDIR:-/tmp}/claim-falsifier.launch.json" \
  < .orchestration/foundation/task-packet.md

# Stop waiting on idle, done, or blocked; print recent output for root inspection.
sh .orchestration/foundation/scripts/wait-coworker-turn.sh \
  "${TMPDIR:-/tmp}/claim-falsifier.launch.json" 120000 300
```

For a 2–4 person team, root owns every launch but semantic coordination goes through
one Tech Lead. First run the Tech Lead planning turn, then launch one to three
specialists with reviewed role overlays and submit their open packets:

```sh
sh .orchestration/foundation/scripts/start-codex-coworker.sh \
  --role tech-lead team-lead fi-peer-challenge \
  >"${TMPDIR:-/tmp}/team-lead.launch.json"
sh .orchestration/foundation/scripts/start-codex-coworker.sh \
  --role researcher evidence-research fi-peer-scout \
  >"${TMPDIR:-/tmp}/evidence-research.launch.json"
sh .orchestration/foundation/scripts/start-codex-coworker.sh \
  --role tester contract-tester fi-peer-challenge \
  >"${TMPDIR:-/tmp}/contract-tester.launch.json"

# Submit the Tech Lead planning packet and each specialist packet before fan-in.
# Each packet names the outcome and report route, never Herdr topology.

team_receipt=$(sh .orchestration/foundation/scripts/start-coworker-team.sh \
  foundation-review \
  "${TMPDIR:-/tmp}/team-lead.launch.json" \
  "${TMPDIR:-/tmp}/evidence-research.launch.json" \
  "${TMPDIR:-/tmp}/contract-tester.launch.json")
```

`start-coworker-team.sh` returns immediately after opening one background relay tab.
Root continues useful independent work and may invoke only the skills applicable to
that work, loading each body on demand. The relay uses one bounded fan-in loop with
backoff; it does not create model turns while statuses remain unchanged. It captures
each terminal specialist output once into a private `$TMPDIR`, passes one artifact
index to the Tech Lead, and waits for the synthesis. Specialists never send their raw
reports to root.

“Wake root” means one attention-only prompt after root becomes `idle`. The relay does
not interrupt a `working` root and does not poll through root model turns. The prompt
contains only the team receipt/collection command, never raw specialist output:

```sh
sh .orchestration/foundation/scripts/collect-coworker-team.sh "$team_receipt"

# After root validates and records its decision, close only receipt-owned tabs.
sh .orchestration/foundation/scripts/close-coworker-team.sh "$team_receipt"
```

If the synthesis is ready but wake submission fails, collection still succeeds and
the private state records `wake_error`. A relay failure may wake root once with a
transport-failure pointer; it cannot interpret specialist meaning, accept work, or
write canonical repository task state.

`agent send` only writes literal text. The submit primitive therefore presses Enter
and verifies `working`; if the first Enter races, it retries Enter only, never the task
text. Submit and wait re-check workspace, tab, pane, terminal, any observed Codex
session, and the foreground PID/start identity/argv/cwd against the launch receipt, so
a stale or same-command replacement cannot satisfy the workflow. Session continuity
may be unavailable before the first turn; PID/start identity remains mandatory. A
status result still does not mean the task is correct.

The launcher validates required profile fields and both native-delegation disables, derives the
same high-precedence CLI envelope, records the profile object/hash before launch,
rejects any object/content change before receipt, then observes the foreground Codex
PID/start identity/argv/cwd. This
attests the visible launch envelope against accidental concurrent replacement; it is
not a same-user security boundary and cannot expose every merged global config effect.

It removes inherited `HERDR_*` variables before starting the coworker. That keeps
transport IDs out of ordinary agent context but is not a security boundary against a
same-user process that deliberately discovers installed binaries or OS state.

The shell contract uses a fake transport only for deterministic command-shape and
failure tests. Before adopting or after a Herdr/Codex upgrade, run the opt-in real
process probe from a live `fi-root-lead` session after the profiles are installed:

```sh
export FI_CODEX_BIN=/absolute/path/from/audited-install-record/codex
export FI_CODEX_SHA256=<sha256-from-that-independent-record>
sh tests/codex-orchestration-acceptance.sh
sh tests/herdr-runtime-smoke.sh fi-peer-challenge
sh tests/herdr-runtime-smoke.sh --with-turn fi-peer-challenge
```

The first command is the Codex release tier: unlike portable repository contracts,
it fails closed when the declared absolute binary path or supplied SHA-256 is absent
or mismatched, then observes same-key merged configuration through that resolved path
without spending a model turn. This proves that the observed file bytes match the
operator-supplied digest; it does not authenticate the digest, interpreter chain, or
local verifier environment. Run it only with a trusted shell/Python/hash toolchain,
stable installation path, and digest from an authenticated independent record. Do
not derive the expected hash from the current `PATH` in the same command and call
that provenance. A release must not claim Codex envelope compatibility from
`tests/repo-contracts.sh` alone.

The default opens a real background Herdr tab, observes a live Codex PID and exact
receipt, checks the OS process environment for leaked root topology/capabilities,
and writes/reads real pane metadata without spending a model turn. `--with-turn`
additionally proves submit, `working`, bounded completion, output collection, and
the expected response. A unit stub is never presented as this integration proof.

For a second opinion, start a separate fresh `fi-peer-challenge` session and provide
the original question, source snapshot, and evidence boundary without the author's
persuasive narrative. Use `fi-peer-scout` only for bounded mechanism discovery; it
may point to a dangerous seam but must not settle a difficult foundation claim.

Before a heavy or flaky validation command:

```sh
export FI_VALIDATION_OWNER="${HERDR_PANE_ID:?}:root"
export FI_VALIDATION_COMMAND='sh tests/repo-contracts.sh'
sh .orchestration/foundation/scripts/validation-lease.sh acquire
sh tests/repo-contracts.sh
status=$?
sh .orchestration/foundation/scripts/validation-lease.sh release
exit "$status"
```

Authorization requires the live Codex pane to carry the operational root designation
`fi-root-lead`, run the exact CLI envelope derived from the current project, and
match the immutable facts recorded immediately before `exec`: pane IDs, PID/start,
cwd, argv, and project profile provenance with both delegation flags disabled. The capability is
then bound to that receipt, session-if-observed, and caller ancestry. Git repository-
selection variables are ignored and authority creation is exclusive, so linked
worktrees contend on one Git-common-dir authority and lease. This prevents accidental
peer, ordinary-session, or post-launch profile substitution authority, not malicious
same-user kernel-level impersonation. After all work and leases end, run
`validation-lease.sh revoke`; there is no automatic stale takeover.

## Pane telemetry

The Codex project hook runs `herdr-pane-telemetry.py` on `SessionStart`,
`PostCompact`, and `Stop`. Because coworker topology variables are sanitized, the
hook correlates its Codex ancestor PID with Herdr pane process information, then uses
only `pane.report_metadata` for display. Session continuity is handled by the separate
`herdr-codex-session.py` SessionStart hook; lifecycle state remains Herdr-owned. The
display fields are:

- context used/left using the same last-request calculation as Codex v0.144.5;
- top-level compact count;
- last request cache ratio and cached input tokens;
- cumulative session tokens (`spent`), which is not context occupancy;
- last observed Stop time and `idle since` time; and
- `hot?`, `cold?`, or `cache uncertain` as an explicitly fallible hint.

The hook reads current transcript records best-effort. Immediately after
`PostCompact` it reports context/cache as `pending`, because the newest token record
may still describe the pre-compact window. If fields disappear or parsing fails, it
clears those tokens and exits successfully. `idle since` is a timestamp, not a live
timer. A prior cache hit does not prove the next turn will hit cache or its quota cost.

Herdr v0.7.4 can render the tokens with:

```toml
[ui.sidebar.agents.rows_by_agent]
codex = [
  ["state_icon", "agent", "state_text"],
  ["$ctx", "$left", "$compact"],
  ["$cache_ratio", "$cached", "$cache_hint"],
  ["$spent", "$idle"],
  ["$last_turn"],
  ["workspace", "tab"],
]
```

Reload with `herdr server reload-config`. Metadata has a 24-hour TTL and is ephemeral
across pane/server lifecycle; it is an attention/economics aid, not task state.

### Another turn or a fresh session

The root may ask another turn in the same live session when the objective, role,
source snapshot, and acceptance contract are unchanged and the follow-up materially
benefits from the existing context. Prefer a fresh session when the role or question
changes, clean-room independence matters, context left is low, repeated compaction has
discarded useful detail, or the next task is broad enough to deserve a new evidence
boundary.

High last-turn cache ratio plus a short idle interval may make one more turn cheaper;
`hot?` is only an economic hint. It must not override context risk, independence, or
authority boundaries. A session ID may be recorded to explain continuity, but it is
never worker identity or correctness evidence.

## Resume and teardown

The pilot is fresh-only. `codex resume <id>` restores conversation continuity but has
not yet proved the same profile, developer instructions, sandbox, approval posture,
cwd, worktree, or acceptance contract. Use a fresh thread for accepted independent
review.

Before closing, read the response, preserve decisive evidence and disagreement, and
make the root decision. Close only pane/tab IDs present in this run's launch receipt.
Revoke the validation capability after its final lease. Never stop the Herdr server
from an active run.
