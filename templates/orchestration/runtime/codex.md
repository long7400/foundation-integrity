# Herdr + Codex adapter

This maps the [coworker protocol](../coworker-protocol.md) to fresh top-level Codex
sessions. It is not a skill, native subagent setup, or FirstMate installation.

## Effects and ownership

- Herdr owns PTYs, panes, input, bounded reads/waits, attention status, and optional
  display metadata.
- Codex profiles own the reviewed model/effort, sandbox, approval, role instruction,
  and both native-delegation feature disables for a process launched with that
  profile.
- Project `AGENTS.md` remains the durable instruction owner.
- The root owns the task graph, validation lease, acceptance, release, and teardown.

Herdr owns lifecycle status. The dedicated SessionStart hook may report the real Codex
session ID for continuity, while the display hook uses only `pane.report_metadata`.
Neither hook reports acceptance or takes over `report-agent` state authority.

## Profiles

Review and explicitly install the five envelopes before enabling the Codex pilot:

```sh
sh .orchestration/foundation/scripts/manage-codex-profiles.sh status
sh .orchestration/foundation/scripts/manage-codex-profiles.sh install
```

This affects only future `codex --profile fi-*` launches. It does not modify Herdr,
ordinary Codex sessions, the base instruction file, or an already-running thread.
Do not install a transport-control skill for coworkers. Only `fi-root-lead` contains
controller behavior; non-root profiles contain no Herdr commands or topology.

The manager creates every destination exclusively instead of claiming or overwriting
a path checked earlier, then writes an owner-only
`foundation-integrity-profiles.json` manifest in Codex home. Removal atomically moves
that manifest and the owned profiles into a private
quarantine, verifies hashes there, and only then deletes them; a raced replacement at
the public path is never removed. An identical user-created file without provenance
is never deleted, and drift requires explicit manual reconciliation.

One shared attester is used by root authorization, launch, submit, and wait. It
requires the installed object's device/inode/hash to match the v2 owner manifest and
its bytes to match the reviewed profile shipped beside the scripts. A hand-written
or drifted file with a supported name is not launch authority. Because trusted
project config has higher precedence than a named profile, the attester also derives
canonical CLI overrides for model, effort, sandbox, approval, both known
native-delegation feature flags, and role instructions. Root and coworker launch
receipts bind the observed launch argv, not every mutable runtime setting.

Project `AGENTS.md`, model instruction sources, rules, and reviewed hooks remain
model-visible by design. The role developer instruction has higher authority than
those project instructions, but it is not semantic isolation from the project. The
pilot protects against same-key configuration replacement and accidental personnel
control; it is not a sandbox against a malicious trusted repository.

Remove matching files after no live session depends on them:

```sh
sh .orchestration/foundation/scripts/manage-codex-profiles.sh remove
```

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
codex --profile fi-glm-peer-scout

sh .orchestration/foundation/scripts/cliproxy-glm.sh doctor
sh .orchestration/foundation/scripts/cliproxy-glm.sh remove
```

`setup` prompts without echo, verifies the pinned release checksum, refuses a
differing destination profile, writes owner-only state, generates a separate local
client key, and binds only to `127.0.0.1`. `remove` stops the process, removes only
unchanged GLM profile copies, and deletes this gateway's credentials/state.

These two profiles are intentionally outside the primary v2 profile attester and
receipt-bound coworker launcher. If the root uses them as external coworkers, the
complete session lifecycle must still go through Herdr—creation, launch, task send,
bounded wait, output inspection, and teardown—and the root must record gateway health
plus a credentialed inference/tool smoke. Do not substitute a native subagent or a
manually spawned terminal agent.

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

# 1. Start a fresh coworker and retain the bound launch receipt.
sh .orchestration/foundation/scripts/start-codex-coworker.sh \
  claim-falsifier fi-peer-challenge >"${TMPDIR:-/tmp}/claim-falsifier.launch.json"

# 2. Type the packet once, press Enter, and verify the pane actually becomes working.
sh .orchestration/foundation/scripts/submit-coworker-turn.sh \
  "${TMPDIR:-/tmp}/claim-falsifier.launch.json" \
  < .orchestration/foundation/task-packet.md

# 3. Stop waiting on idle, done, or blocked; print recent output for root inspection.
sh .orchestration/foundation/scripts/wait-coworker-turn.sh \
  "${TMPDIR:-/tmp}/claim-falsifier.launch.json" 120000 300
```

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
`fi-root-lead`, run `codex --profile fi-root-lead` from the current worktree, and match
the immutable facts recorded immediately before `exec`: pane IDs, PID/start, cwd,
argv, and canonical v2 profile provenance with both delegation flags disabled. The capability is
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
