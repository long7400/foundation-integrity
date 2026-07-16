#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/fi-orchestration-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if rg -n '\.foundation/orchestration|role-model-matrix|run-contract|controller-lock' \
  "$root/README.md" "$root/templates/orchestration" "$root/templates/setup" \
  "$root/docs/install" >/dev/null; then
  fail "distribution retains retired orchestration state or declaration machinery"
fi

for profile in "$root"/templates/orchestration/profiles/codex/fi-peer-*.toml \
  "$root"/templates/orchestration/profiles/codex/fi-implementer-*.toml; do
  if rg -ni 'herdr|pane|department topology' "$profile" >/dev/null; then
    fail "non-root Codex profile exposes transport control: $profile"
  fi
done

for prompt in "$root"/templates/orchestration/profiles/claude/fi-peer-*.md \
  "$root"/templates/orchestration/profiles/claude/fi-implementer-*.md; do
  if rg -ni 'herdr|pane|department topology' "$prompt" >/dev/null; then
    fail "non-root Claude prompt exposes transport control: $prompt"
  fi
done
claude_launch=$root/templates/orchestration/profiles/claude/launch-commands.md
[ "$(rg -c '^claude ' "$claude_launch")" -eq 5 ] \
  || fail "Claude adapter does not define exactly five explicit launch envelopes"
[ "$(rg -c -- '--session-id "\$FI_SESSION_ID"' "$claude_launch")" -eq 5 ] \
  || fail "Claude launch envelopes do not require fresh explicit sessions"
[ "$(rg -c -- '--disallowedTools .*Agent,Task' "$claude_launch")" -eq 5 ] \
  || fail "Claude launch envelopes do not disable native personnel control"
rg -Fq 'currently Codex-only' "$root/templates/orchestration/runtime/claude.md" \
  || fail "Claude adapter overclaims receipt-bound lifecycle parity"

fake_bin=$tmp/bin
codex_home=$tmp/codex-home
mkdir -p "$fake_bin" "$codex_home"
fake_log=$tmp/herdr.log
fake_status=$tmp/status
fake_enters=$tmp/enters
printf 'idle\n' > "$fake_status"
printf '0\n' > "$fake_enters"

cat > "$fake_bin/herdr" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FAKE_LOG"
case "$1:$2" in
  tab:create)
    printf '%s\n' '{"id":"fake","result":{"root_pane":{"workspace_id":"w1","tab_id":"w1:t9","pane_id":"w1:p9","terminal_id":"term_9"},"tab":{"workspace_id":"w1","tab_id":"w1:t9"}}}'
    ;;
  agent:get)
    status=$(cat "$FAKE_STATUS_FILE")
    if [ "$3" = w1:p1 ]; then
      printf '{"id":"fake","result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t1","pane_id":"w1:p1","terminal_id":"term_1","name":"%s","agent_status":"working","agent_session":{"value":"root-session"}}}}\n' "${FAKE_ROOT_NAME:-fi-root-lead}"
    else
      terminal=${FAKE_TERMINAL_ID:-term_9}
      printf '{"id":"fake","result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t9","pane_id":"w1:p9","terminal_id":"%s","name":"%s","agent_status":"%s","agent_session":{"value":"%s"}}}}\n' "$terminal" "${FAKE_AGENT_NAME:-peer-a}" "$status" "${FAKE_AGENT_SESSION-session-9}"
    fi
    ;;
  agent:rename|agent:send|agent:focus|tab:close|pane:rename|pane:report-metadata|pane:report-agent-session) ;;
  pane:get)
    printf '%s\n' '{"id":"fake","result":{"pane":{"workspace_id":"w1","tab_id":"w1:t1","pane_id":"w1:p1","terminal_id":"term_1"}}}'
    ;;
  pane:run)
    if [ "${FAKE_REPLACE_PROFILE:-0}" = 1 ]; then
      cp "$FAKE_PROFILE_PATH" "$FAKE_PROFILE_PATH.replacement"
      mv "$FAKE_PROFILE_PATH.replacement" "$FAKE_PROFILE_PATH"
    fi
    ;;
  pane:process-info)
    pane=${4:-w1:p9}
    if [ "$pane" = w1:p1 ]; then
      if [ "${FAKE_ROOT_PROFILE:-fi-root-lead}" = fi-root-lead ]; then
        argv=${FAKE_ROOT_ARGV_JSON:-'["codex","--profile","fi-root-lead"]'}
      else
        argv=$(printf '["codex","--profile","%s"]' "$FAKE_ROOT_PROFILE")
      fi
      process_cwd=${FAKE_ROOT_PROCESS_CWD:-$FAKE_PROCESS_CWD}
    else
      argv=${FAKE_COWORKER_ARGV_JSON:-'["codex","--profile","fi-peer-challenge"]'}
      [ "${FAKE_BAD_ARGV:-0}" = 0 ] || argv='["codex"]'
      process_cwd=$FAKE_PROCESS_CWD
    fi
    caller=$(ps -o ppid= -p "$PPID" | tr -d ' ')
    printf '{"id":"fake","result":{"process_info":{"pane_id":"%s","foreground_processes":[{"pid":%s,"argv":%s,"cwd":"%s"}]}}}\n' "$pane" "${FAKE_PROCESS_PID:-$caller}" "$argv" "$process_cwd"
    ;;
  pane:list)
    printf '%s\n' '{"id":"fake","result":{"panes":[{"pane_id":"w1:p9"}]}}'
    ;;
  pane:send-keys)
    count=$(cat "$FAKE_ENTER_FILE")
    count=$((count + 1))
    printf '%s\n' "$count" > "$FAKE_ENTER_FILE"
    [ "$count" -lt 2 ] || printf 'working\n' > "$FAKE_STATUS_FILE"
    ;;
  wait:agent-status)
    wanted=
    while [ "$#" -gt 0 ]; do
      [ "$1" != --status ] || { shift; wanted=$1; }
      shift || true
    done
    [ "$(cat "$FAKE_STATUS_FILE")" = "$wanted" ]
    ;;
  pane:read) printf '%s\n' 'worker-output' ;;
  *) echo "fake herdr: unsupported $1 $2" >&2; exit 2 ;;
esac
SH
cat > "$fake_bin/codex" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$fake_bin/herdr" "$fake_bin/codex"
profile_manager=$root/templates/orchestration/scripts/manage-codex-profiles.sh
CODEX_HOME="$codex_home" sh "$profile_manager" install \
  || fail "canonical launch profile install failed"

lease=$root/templates/orchestration/scripts/validation-lease.sh
stable_pid=$$
control_repo=$tmp/control-repo
git init -q "$control_repo"
control_repo=$(CDPATH= cd -- "$control_repo" && pwd -P)
mkdir "$control_repo/.codex"
printf '%s\n' 'developer_instructions = "contradict the root role"' \
  '[features]' 'multi_agent = true' 'multi_agent_v2 = true' \
  > "$control_repo/.codex/config.toml"
root_started_at=$(ps -o lstart= -p "$stable_pid" \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
root_profile_attestation=$(CODEX_HOME="$codex_home" \
  python3 "$root/templates/orchestration/scripts/attest-codex-profile.py" fi-root-lead)
peer_profile_attestation=$(CODEX_HOME="$codex_home" \
  python3 "$root/templates/orchestration/scripts/attest-codex-profile.py" fi-peer-challenge)
root_argv_json=$(printf '%s\n' "$root_profile_attestation" | python3 -c \
  'import json,sys; value=json.load(sys.stdin); print(json.dumps(["codex", *value["cli_args"]], separators=(",", ":")))')
peer_argv_json=$(printf '%s\n' "$peer_profile_attestation" | python3 -c \
  'import json,sys; value=json.load(sys.stdin); print(json.dumps(["codex", *value["cli_args"]], separators=(",", ":")))')
write_root_receipt() {
  target=$1
  receipt_cwd=$2
  receipt_profile=$3
  corrupt=${4:-0}
  FI_TARGET="$target" FI_RECEIPT_CWD="$receipt_cwd" FI_RECEIPT_PROFILE="$receipt_profile" \
    FI_RECEIPT_PID="$stable_pid" FI_RECEIPT_STARTED="$root_started_at" \
    FI_RECEIPT_CORRUPT="$corrupt" python3 - <<'PY'
import json, os, pathlib
profile = json.loads(os.environ["FI_RECEIPT_PROFILE"])
if os.environ["FI_RECEIPT_CORRUPT"] == "1":
    profile["sha256"] = "prelaunch-noncanonical"
value = {
    "schema": "foundation-integrity-codex-root-launch:v1",
    "workspace_id": "w1", "tab_id": "w1:t1", "pane_id": "w1:p1",
    "terminal_id": "term_1", "name": "fi-root-lead",
    "cwd": os.environ["FI_RECEIPT_CWD"],
    "process_pid": int(os.environ["FI_RECEIPT_PID"]),
    "process_started_at": os.environ["FI_RECEIPT_STARTED"],
    "process_argv": ["codex", *profile["cli_args"]],
    "profile": profile,
}
pathlib.Path(os.environ["FI_TARGET"]).write_text(json.dumps(value, sort_keys=True) + "\n")
PY
}
root_receipt=$tmp/control-root.launch.json
write_root_receipt "$root_receipt" "$control_repo" "$root_profile_attestation"
bad_root_receipt=$tmp/control-root-bad.launch.json
write_root_receipt "$bad_root_receipt" "$control_repo" "$root_profile_attestation" 1
if (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
  FAKE_ROOT_NAME=fi-peer-challenge FAKE_PROCESS_PID="$stable_pid" \
  FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FAKE_ROOT_PROCESS_CWD="$control_repo" CODEX_HOME="$codex_home" \
  sh "$lease" authorize >/dev/null 2>&1); then
  fail "validation authority accepted a peer-designated pane as root"
fi
if (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
  FAKE_ROOT_PROFILE=fi-peer-challenge FAKE_PROCESS_PID="$stable_pid" \
  FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FAKE_ROOT_PROCESS_CWD="$control_repo" CODEX_HOME="$codex_home" \
  sh "$lease" authorize >/dev/null 2>&1); then
  fail "validation authority accepted a non-root Codex profile"
fi
if (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
  FAKE_PROCESS_PID="$stable_pid" FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" \
  FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
  FAKE_ENTER_FILE="$fake_enters" FAKE_PROCESS_CWD="$root" \
  FAKE_ROOT_PROCESS_CWD="$control_repo" CODEX_HOME="$codex_home" \
  FI_ROOT_LAUNCH_RECEIPT="$bad_root_receipt" sh "$lease" authorize >/dev/null 2>&1); then
  fail "validation authority accepted canonical disk state after a noncanonical root launch"
fi
if (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
  FAKE_PROCESS_PID="$stable_pid" FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" \
  FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
  FAKE_ENTER_FILE="$fake_enters" FAKE_PROCESS_CWD="$root" \
  FAKE_ROOT_PROCESS_CWD="$control_repo" CODEX_HOME="$codex_home" \
  sh "$lease" authorize >/dev/null 2>&1); then
  fail "validation authority accepted a root process without pre-launch provenance"
fi
root_token=$(cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
  FAKE_PROCESS_PID="$stable_pid" \
  FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FAKE_ROOT_PROCESS_CWD="$control_repo" CODEX_HOME="$codex_home" \
  FI_ROOT_LAUNCH_RECEIPT="$root_receipt" sh "$lease" authorize) \
  || fail "validation authority init for launch tests failed"

common_env() {
  (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
    HERDR_WORKSPACE_ID=w1 CODEX_HOME="$codex_home" FAKE_PROCESS_PID="$stable_pid" \
    FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
    FAKE_PROFILE_PATH="$codex_home/fi-peer-challenge.config.toml" \
    FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
    FAKE_PROCESS_CWD="$root" FAKE_ROOT_PROCESS_CWD="$control_repo" \
    FI_ROOT_LAUNCH_RECEIPT="$root_receipt" FI_VALIDATION_TOKEN="$root_token" "$@")
}

bootstrap_receipt=$tmp/bootstrap-root.launch.json
(cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 \
  HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" CODEX_HOME="$codex_home" CODEX_BIN="$fake_bin/codex" \
  sh "$root/templates/orchestration/scripts/launch-codex-root.sh" \
  "$bootstrap_receipt" "$control_repo") \
  || fail "root bootstrap launch failed"
python3 - "$bootstrap_receipt" <<'PY' || fail "root bootstrap receipt is incomplete"
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value["schema"] == "foundation-integrity-codex-root-launch:v1"
assert value["process_argv"] == ["codex", *value["profile"]["cli_args"]]
assert value["profile"]["profile"] == "fi-root-lead"
assert value["profile"]["multi_agent"] is False
assert value["profile"]["multi_agent_v2"] is False
PY
if (cd "$control_repo" && env PATH="$fake_bin:$PATH" HERDR_ENV=1 \
  HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=w1:t1 HERDR_PANE_ID=w1:p1 \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" CODEX_HOME="$codex_home" CODEX_BIN="$fake_bin/codex" \
  sh "$root/templates/orchestration/scripts/launch-codex-root.sh" \
  "$bootstrap_receipt" "$control_repo" >/dev/null 2>&1); then
  fail "root bootstrap overwrote an existing launch receipt"
fi

launch_receipt=$tmp/peer-a.launch.json
common_env sh "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-a fi-peer-challenge "$root" > "$launch_receipt" \
  || fail "fresh Codex coworker start failed"
python3 - "$launch_receipt" <<'PY' || fail "launch receipt is incomplete"
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value["schema"] == "foundation-integrity-codex-launch:v2"
assert value["name"] == "peer-a"
assert value["profile"] == "fi-peer-challenge"
assert value["multi_agent"] is False
assert value["multi_agent_v2"] is False
assert value["sandbox"] == "read-only"
assert len(value["profile_sha256"]) == 64
assert value["process_argv"][0:3] == ["codex", "--profile", "fi-peer-challenge"]
assert "features.multi_agent=false" in value["process_argv"]
assert "features.multi_agent_v2=false" in value["process_argv"]
assert value["agent_session_id"] == "session-9"
assert isinstance(value["process_pid"], int)
assert value["process_started_at"]
assert isinstance(value["profile_inode"], int)
PY
grep -Fq 'tab create' "$fake_log" || fail "start primitive did not create a background tab"
grep -Fq -- 'tab create --workspace w1' "$fake_log" \
  || fail "start primitive did not bind the root workspace"
grep -Fq -- '--label peer-a --no-focus' "$fake_log" \
  || fail "start primitive did not keep the root pane focused"
grep -Fq 'pane run w1:p9' "$fake_log" || fail "start primitive did not launch Codex"
for variable in HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_SOCKET_PATH HERDR_STARTUP_CWD \
  FI_HERDR_WORKSPACE_ID FI_VALIDATION_TOKEN FI_VALIDATION_OWNER FI_VALIDATION_COMMAND \
  FI_VALIDATION_AUTHORITY_FILE FI_VALIDATION_LOCK_DIR FI_ROOT_LAUNCH_RECEIPT; do
  grep -Fq -- "-u $variable" "$fake_log" || fail "launcher leaked $variable to coworker"
done
grep -Fq 'pane process-info --pane w1:p9' "$fake_log" \
  || fail "start primitive did not attest the foreground process"

empty_home=$tmp/empty-home
mkdir "$empty_home"
touch "$empty_home/fi-peer-challenge.config.toml"
if PATH="$fake_bin:$PATH" HERDR_ENV=1 CODEX_HOME="$empty_home" \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" \
  sh "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-empty fi-peer-challenge "$root" >/dev/null 2>&1; then
  fail "start primitive accepted an empty profile envelope"
fi
unowned_home=$tmp/unowned-home
mkdir "$unowned_home"
cp "$root/templates/orchestration/profiles/codex/fi-peer-challenge.config.toml" "$unowned_home/"
if common_env env CODEX_HOME="$unowned_home" sh \
  "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-unowned fi-peer-challenge "$root" >/dev/null 2>&1; then
  fail "start primitive accepted an unowned supported-name profile"
fi
if common_env env FAKE_BAD_ARGV=1 FAKE_AGENT_NAME=peer-bad \
  sh "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-bad fi-peer-challenge "$root" >/dev/null 2>&1; then
  fail "start primitive accepted a mismatched foreground argv"
fi
race_home=$tmp/race-home
mkdir "$race_home"
CODEX_HOME="$race_home" sh "$profile_manager" install \
  || fail "profile race fixture install failed"
if common_env env CODEX_HOME="$race_home" FAKE_REPLACE_PROFILE=1 \
  FAKE_PROFILE_PATH="$race_home/fi-peer-challenge.config.toml" sh \
  "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-profile-race fi-peer-challenge "$root" >/dev/null 2>&1; then
  fail "start primitive accepted a profile replaced during launch"
fi
if common_env sh "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  root-2 fi-root-lead "$root" >/dev/null 2>&1; then
  fail "coworker start accepted a second root profile"
fi

drift_receipt=$tmp/profile-drift.launch.json
common_env env FAKE_AGENT_NAME=peer-profile-drift sh \
  "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  peer-profile-drift fi-peer-challenge "$root" > "$drift_receipt" \
  || fail "profile drift fixture launch failed"
printf '# post-launch drift\n' >> "$codex_home/fi-peer-challenge.config.toml"
printf 'idle\n' > "$fake_status"
if printf 'should be rejected\n' | common_env sh \
  "$root/templates/orchestration/scripts/submit-coworker-turn.sh" \
  "$drift_receipt" >/dev/null 2>&1; then
  fail "submit accepted profile provenance drift after launch"
fi
printf 'done\n' > "$fake_status"
if common_env sh "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$drift_receipt" 10 20 >/dev/null 2>&1; then
  fail "wait accepted profile provenance drift after launch"
fi
cp "$root/templates/orchestration/profiles/codex/fi-peer-challenge.config.toml" \
  "$codex_home/fi-peer-challenge.config.toml"

: > "$fake_log"
printf 'idle\n' > "$fake_status"
printf '0\n' > "$fake_enters"
printf '%s\n' 'Investigate the open question without assuming the answer.' | \
  common_env env FI_SUBMIT_TIMEOUT_MS=1 \
  sh "$root/templates/orchestration/scripts/submit-coworker-turn.sh" \
  "$launch_receipt" >/dev/null || fail "verified submit failed"
[ "$(grep -c '^agent send w1:p9 ' "$fake_log")" -eq 1 ] \
  || fail "submit primitive typed the packet more than once"
[ "$(grep -c '^pane send-keys .* enter$' "$fake_log")" -eq 2 ] \
  || fail "submit primitive did not retry Enter only"

printf 'idle\n' > "$fake_status"
set +e
printf 'another task\n' | FAKE_TERMINAL_ID=stale common_env sh \
  "$root/templates/orchestration/scripts/submit-coworker-turn.sh" "$launch_receipt" \
  >/dev/null 2>&1
stale_status=$?
set -e
[ "$stale_status" -ne 0 ] || fail "submit accepted a target outside its launch receipt"

printf 'done\n' > "$fake_status"
if common_env env FAKE_BAD_ARGV=1 sh \
  "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$launch_receipt" 10 20 >/dev/null 2>&1; then
  fail "wait collected output after the launched process was replaced"
fi
if common_env env FAKE_PROCESS_PID="$PPID" sh \
  "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$launch_receipt" 10 20 >/dev/null 2>&1; then
  fail "wait accepted a replacement process with identical argv/cwd"
fi
tampered_receipt=$tmp/tampered-start.launch.json
python3 - "$launch_receipt" "$tampered_receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
value["process_started_at"] = "not-the-launched-process"
pathlib.Path(sys.argv[2]).write_text(json.dumps(value))
PY
if common_env sh "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$tampered_receipt" 10 20 >/dev/null 2>&1; then
  fail "wait ignored process start identity"
fi
output=$(common_env sh "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$launch_receipt" 10 20) || fail "wait primitive froze or rejected done"
[ "$output" = worker-output ] || fail "wait primitive did not collect pane output"

printf 'blocked\n' > "$fake_status"
set +e
common_env sh "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
  "$launch_receipt" 10 20 >/dev/null 2>&1
blocked_status=$?
set -e
[ "$blocked_status" -eq 3 ] || fail "wait primitive did not surface blocked distinctly"
common_env sh "$lease" revoke || fail "launch-test validation authority revoke failed"

profile_home=$tmp/profile-home
mkdir "$profile_home"
cp "$root/templates/orchestration/profiles/codex/fi-peer-scout.config.toml" \
  "$profile_home/fi-peer-scout.config.toml"
if CODEX_HOME="$profile_home" sh "$profile_manager" remove >/dev/null 2>&1; then
  fail "profile manager removed an identical file without ownership provenance"
fi
rm -f "$profile_home/fi-peer-scout.config.toml"
CODEX_HOME="$profile_home" sh "$profile_manager" install \
  || fail "profile manager install failed"
[ -f "$profile_home/foundation-integrity-profiles.json" ] \
  || fail "profile manager did not record ownership"
python3 - "$profile_home/foundation-integrity-profiles.json" <<'PY' \
  || fail "profile manager omitted object provenance"
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert value["schema"] == "foundation-integrity-codex-profiles:v2"
for record in value["files"].values():
    assert set(record) == {"device", "inode", "sha256"}
PY
if CODEX_HOME="$profile_home" sh "$profile_manager" install >/dev/null 2>&1; then
  fail "profile manager overwrote pre-existing profiles"
fi
printf '# drift\n' >> "$profile_home/fi-peer-scout.config.toml"
if CODEX_HOME="$profile_home" sh "$profile_manager" remove >/dev/null 2>&1; then
  fail "profile manager removed a drifted profile"
fi
[ -f "$profile_home/foundation-integrity-profiles.json" ] \
  && [ -f "$profile_home/fi-peer-scout.config.toml" ] \
  || fail "failed profile removal did not restore owned paths"
if find "$profile_home" -maxdepth 1 -name '.foundation-integrity-profile-removal-*' \
  -print -quit | grep -q .; then
  fail "failed profile removal left an unnecessary quarantine"
fi
cp "$root/templates/orchestration/profiles/codex/fi-peer-scout.config.toml" \
  "$profile_home/fi-peer-scout.config.toml"
CODEX_HOME="$profile_home" sh "$profile_manager" remove \
  || fail "profile manager could not remove matching profiles"

replacement_home=$tmp/replacement-home
mkdir "$replacement_home"
CODEX_HOME="$replacement_home" sh "$profile_manager" install \
  || fail "replacement provenance fixture install failed"
cp "$replacement_home/fi-peer-scout.config.toml" \
  "$replacement_home/fi-peer-scout.config.toml.replacement"
mv "$replacement_home/fi-peer-scout.config.toml.replacement" \
  "$replacement_home/fi-peer-scout.config.toml"
if CODEX_HOME="$replacement_home" sh "$profile_manager" remove >/dev/null 2>&1; then
  fail "profile manager deleted an identical replacement with different provenance"
fi
[ -f "$replacement_home/foundation-integrity-profiles.json" ] \
  && [ -f "$replacement_home/fi-peer-scout.config.toml" ] \
  || fail "identical replacement rejection did not restore public paths"

repo=$tmp/repo
git init -q "$repo"
repo=$(CDPATH= cd -- "$repo" && pwd -P)
git -C "$repo" config user.email fixture@example.invalid
git -C "$repo" config user.name fixture
printf 'x\n' > "$repo/file"
git -C "$repo" add file
git -C "$repo" commit -qm baseline
repo_root_receipt=$tmp/repo-root.launch.json
write_root_receipt "$repo_root_receipt" "$repo" "$root_profile_attestation"
repo_lease_env() {
  env PATH="$fake_bin:$PATH" HERDR_ENV=1 HERDR_PANE_ID=w1:p1 \
    FAKE_PROCESS_PID="$stable_pid" \
    FAKE_ROOT_ARGV_JSON="$root_argv_json" FAKE_COWORKER_ARGV_JSON="$peer_argv_json" \
    FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
    FAKE_PROCESS_CWD="$root" FAKE_ROOT_PROCESS_CWD="$repo" CODEX_HOME="$codex_home" \
    FI_ROOT_LAUNCH_RECEIPT="$repo_root_receipt" "$@"
}
bogus_authority=$tmp/bogus-validation.authority
bogus_lock=$tmp/bogus-validation.lock
other_repo=$tmp/other-repo
git init -q "$other_repo"
token_a=$tmp/token-a
token_b=$tmp/token-b
set +e
(cd "$repo" && repo_lease_env env FI_VALIDATION_AUTHORITY_FILE="$bogus_authority" \
  FI_VALIDATION_LOCK_DIR="$bogus_lock" GIT_DIR="$other_repo/.git" \
  GIT_WORK_TREE="$other_repo" sh "$lease" authorize > "$token_a" 2>/dev/null) &
pid_a=$!
(cd "$repo" && repo_lease_env env GIT_COMMON_DIR="$other_repo/.git" \
  sh "$lease" authorize > "$token_b" 2>/dev/null) &
pid_b=$!
wait "$pid_a"
rc_a=$?
wait "$pid_b"
rc_b=$?
set -e
[ $(( (rc_a == 0) + (rc_b == 0) )) -eq 1 ] \
  || fail "concurrent validation authorization did not elect exactly one root"
if [ "$rc_a" -eq 0 ]; then token=$(cat "$token_a"); else token=$(cat "$token_b"); fi
[ ! -e "$bogus_authority" ] && [ ! -e "$bogus_lock" ] \
  || fail "validation lease honored alternate authority/lock paths"
[ -f "$repo/.git/foundation-integrity-validation.authority" ] \
  && [ ! -e "$other_repo/.git/foundation-integrity-validation.authority" ] \
  || fail "Git environment redirected the canonical validation authority"
if (cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN=wrong sh "$lease" acquire >/dev/null 2>&1); then
  fail "validation lease accepted a self-asserted capability"
fi
(cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN="$token" FI_VALIDATION_OWNER=root-pane \
  FI_VALIDATION_COMMAND='heavy-test' sh "$lease" acquire >/dev/null) \
  || fail "validation lease acquire failed"
if (cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN=wrong FI_VALIDATION_OWNER=other-pane \
  sh "$lease" release >/dev/null 2>&1); then
  fail "validation lease allowed a foreign release"
fi
(cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN="$token" FI_VALIDATION_OWNER=root-pane \
  sh "$lease" release) || fail "validation lease owner could not release"
if (cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN="$token" HERDR_PANE_ID=w1:p8 \
  sh "$lease" verify >/dev/null 2>&1); then
  fail "validation capability was not bound to the root pane"
fi
(cd "$repo" && repo_lease_env env FI_VALIDATION_TOKEN="$token" sh "$lease" revoke) \
  || fail "validation authority revoke failed"

transcript=$tmp/transcript.jsonl
cat > "$transcript" <<'JSONL'
{"timestamp":"2026-07-16T12:00:00.000Z","type":"session_meta","payload":{"id":"fixture"}}
{"timestamp":"2026-07-16T12:30:00.000Z","type":"compacted","payload":{"window_number":1}}
{"timestamp":"2026-07-16T12:30:00.001Z","type":"event_msg","payload":{"type":"context_compacted"}}
{"timestamp":"2026-07-16T12:45:00.000Z","type":"compacted","payload":{"window_number":2}}
{"timestamp":"2026-07-16T12:45:00.001Z","type":"event_msg","payload":{"type":"context_compacted"}}
{"timestamp":"2026-07-16T12:50:00.000Z","type":"event_msg","payload":{"text":"quoted marker: \"type\":\"compacted\""}}
{"timestamp":"2026-07-16T13:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":150000},"last_token_usage":{"input_tokens":50000,"cached_input_tokens":45000,"total_tokens":60000},"model_context_window":100000}}}
JSONL
: > "$fake_log"
now=$(python3 -c 'import datetime as d; print(d.datetime(2026,7,16,13,10,tzinfo=d.timezone.utc).timestamp())')
printf '{"hook_event_name":"Stop","transcript_path":"%s"}\n' "$transcript" | \
  PATH="$fake_bin:$PATH" HERDR_PANE_ID=w1:p9 HERDR_BIN=herdr \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FI_TELEMETRY_NOW_EPOCH="$now" \
  python3 "$root/templates/hooks/scripts/herdr-pane-telemetry.py"
for expected in \
  '--token ctx=ctx 55%' \
  '--token left=left 45%' \
  '--token compact=compact 2' \
  '--token cache_ratio=cache 90%' \
  '--token cached=cached 45k' \
  '--token spent=spent 150k' \
  '--token idle=idle since 13:10Z' \
  '--token cache_hint=hot?'
do
  grep -Fq -- "$expected" "$fake_log" || fail "telemetry omitted $expected"
done

: > "$fake_log"
printf '{"hook_event_name":"PostCompact","transcript_path":"%s"}\n' "$transcript" | \
  PATH="$fake_bin:$PATH" HERDR_PANE_ID=w1:p9 HERDR_BIN=herdr \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FI_TELEMETRY_NOW_EPOCH="$now" \
  python3 "$root/templates/hooks/scripts/herdr-pane-telemetry.py"
grep -Fq -- '--token ctx=ctx pending' "$fake_log" \
  || fail "PostCompact retained stale context usage"
grep -Fq -- '--token cache_ratio=cache pending' "$fake_log" \
  || fail "PostCompact retained stale cache usage"
grep -Fq -- '--clear-token left' "$fake_log" \
  || fail "PostCompact did not clear stale context-left metadata"
grep -Fq -- '--clear-token cached' "$fake_log" \
  || fail "PostCompact did not clear stale cached-token metadata"

: > "$fake_log"
printf '{"hook_event_name":"SessionStart","session_id":"session-9","transcript_path":"%s"}\n' "$transcript" | \
  env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID \
  -u HERDR_SOCKET_PATH -u HERDR_STARTUP_CWD \
  PATH="$fake_bin:$PATH" HERDR_BIN=herdr \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_CWD="$root" FI_TELEMETRY_NOW_EPOCH="$now" \
  python3 "$root/templates/hooks/scripts/herdr-pane-telemetry.py"
grep -Fq 'pane list' "$fake_log" || fail "sanitized telemetry did not discover panes"
if grep -Fq 'report-agent-session' "$fake_log"; then
  fail "display telemetry wrote semantic session identity"
fi
grep -Fq 'pane report-metadata w1:p9' "$fake_log" \
  || fail "sanitized telemetry did not report pane metadata"

: > "$fake_log"
printf '{"hook_event_name":"SessionStart","session_id":"session-9"}\n' | \
  env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID \
  -u HERDR_SOCKET_PATH -u HERDR_STARTUP_CWD \
  PATH="$fake_bin:$PATH" HERDR_BIN=herdr \
  FAKE_LOG="$fake_log" FAKE_STATUS_FILE="$fake_status" FAKE_ENTER_FILE="$fake_enters" \
  FAKE_PROCESS_PID="$stable_pid" FAKE_PROCESS_CWD="$root" \
  python3 "$root/templates/hooks/scripts/herdr-codex-session.py"
grep -Fq 'pane report-agent-session w1:p9' "$fake_log" \
  || fail "session continuity hook did not report the Codex session"
if grep -Fq 'report-metadata' "$fake_log"; then
  fail "session continuity hook wrote display metadata"
fi

echo "orchestration contracts: PASS"
