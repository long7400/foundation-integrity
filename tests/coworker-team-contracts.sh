#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/fi-coworker-team-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

codex_home=$tmp/codex-home
fake_bin=$tmp/bin
team_dir=$tmp/team
mkdir -p "$codex_home" "$fake_bin" "$team_dir/artifacts"
chmod 700 "$team_dir" "$team_dir/artifacts"
CODEX_HOME="$codex_home" sh \
  "$root/templates/orchestration/scripts/manage-codex-profiles.sh" install >/dev/null

tech_attestation=$(CODEX_HOME="$codex_home" python3 \
  "$root/templates/orchestration/scripts/attest-codex-profile.py" \
  fi-peer-challenge --role tech-lead) || fail "Tech Lead attestation failed"
printf '%s\n' "$tech_attestation" | python3 -c '
import json, sys
value = json.load(sys.stdin)
assert value["model"] == "gpt-5.6-sol"
assert value["base_effort"] == "medium"
assert value["effort"] == "high"
assert "Common task-role contract:" in value["developer_instructions"]
assert "Your task role is Tech Lead" in value["developer_instructions"]
assert "Your task role is Business Analyst" not in value["developer_instructions"]
' || fail "Tech Lead role envelope is not selective Sol high"
if CODEX_HOME="$codex_home" python3 \
  "$root/templates/orchestration/scripts/attest-codex-profile.py" \
  fi-implementer-mechanical --role tech-lead >/dev/null 2>&1; then
  fail "incompatible Tech Lead profile was accepted"
fi

stable_pid=$$
started_at=$(ps -o lstart= -p "$stable_pid" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
FI_ROOT=$root FI_HOME=$codex_home FI_TEAM=$team_dir FI_PID=$stable_pid \
FI_STARTED=$started_at python3 - <<'PY'
import hashlib, json, os, pathlib

root = pathlib.Path(os.environ["FI_ROOT"])
home = pathlib.Path(os.environ["FI_HOME"])
team = pathlib.Path(os.environ["FI_TEAM"])
pid = int(os.environ["FI_PID"])
started = os.environ["FI_STARTED"]
attester = root / "templates/orchestration/scripts/attest-codex-profile.py"

def attest(profile, role=None):
    import subprocess
    args = ["python3", str(attester), profile, str(home)]
    if role:
        args += ["--role", role]
    return json.loads(subprocess.check_output(args, text=True))

root_profile = attest("fi-root-lead")
root_receipt = {
    "schema": "foundation-integrity-codex-root-launch:v1",
    "workspace_id": "w1", "tab_id": "w1:t1", "pane_id": "w1:p1",
    "terminal_id": "term_1", "name": "fi-root-lead", "cwd": str(root),
    "process_pid": pid, "process_started_at": started,
    "process_argv": ["codex", *root_profile["cli_args"]], "profile": root_profile,
}

def coworker(filename, name, pane, tab, terminal, profile_name, role):
    profile = attest(profile_name, role)
    receipt = {
        "schema": "foundation-integrity-codex-launch:v2",
        "name": name, "profile": profile_name,
        "profile_sha256": profile["sha256"], "profile_device": profile["device"],
        "profile_inode": profile["inode"], "profile_path": profile["path"],
        "profile_tier": profile["profile_tier"], "codex_home": profile["codex_home"],
        "model": profile["model"], "effort": profile["effort"],
        "sandbox": profile["sandbox"], "approval": profile["approval"],
        "task_role": role, "role_sha256": profile["role_sha256"],
        "role_path": profile["role_path"],
        "developer_instructions_sha256": hashlib.sha256(
            profile["developer_instructions"].encode()
        ).hexdigest(),
        "multi_agent": False, "multi_agent_v2": False, "cwd": str(root),
        "workspace_id": "w1", "tab_id": tab, "pane_id": pane,
        "terminal_id": terminal, "agent_session_id": f"session-{pane.rsplit('p', 1)[-1]}",
        "process_argv": ["codex", *profile["cli_args"]],
        "process_pid": pid, "process_started_at": started,
    }
    (team / filename).write_text(json.dumps(receipt, sort_keys=True) + "\n")
    return receipt

(team / "root.launch.json").write_text(json.dumps(root_receipt, sort_keys=True) + "\n")
coworker("lead.launch.json", "team-lead", "w1:p2", "w1:t2", "term_2", "fi-peer-challenge", "tech-lead")
coworker("specialist-1.launch.json", "evidence-research", "w1:p3", "w1:t3", "term_3", "fi-peer-scout", "researcher")
coworker("specialist-2.launch.json", "contract-tester", "w1:p4", "w1:t4", "term_4", "fi-peer-challenge", "tester")
for path in team.glob("*.launch.json"):
    path.chmod(0o600)

def binding(name):
    path = team / name
    return {"receipt": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

team_receipt = {
    "schema": "foundation-integrity-coworker-team:v1",
    "team_name": "contract-team",
    "root": binding("root.launch.json"),
    "lead": binding("lead.launch.json"),
    "specialists": [binding("specialist-1.launch.json"), binding("specialist-2.launch.json")],
    "relay": {"workspace_id": "w1", "tab_id": "w1:t8", "pane_id": "w1:p8", "terminal_id": "term_8"},
    "timeout_ms": 5000, "poll_initial_ms": 25, "poll_max_ms": 50,
    "output_lines": 100, "submit_timeout_ms": 1,
}
(team / "team.json").write_text(json.dumps(team_receipt, sort_keys=True) + "\n")
(team / "team.json").chmod(0o600)
PY

fake_log=$tmp/herdr.log
root_calls=$tmp/root-calls
lead_calls=$tmp/lead-calls
lead_submitted=$tmp/lead-submitted
root_wake=$tmp/root-wake
printf '0\n' > "$root_calls"
printf '0\n' > "$lead_calls"
: > "$fake_log"

cat > "$fake_bin/herdr" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FAKE_LOG"
pane=${3:-}
case "$1:$2" in
  agent:get)
    case "$pane" in
      w1:p1)
        count=$(cat "$FAKE_ROOT_CALLS"); count=$((count + 1)); printf '%s\n' "$count" > "$FAKE_ROOT_CALLS"
        if [ -f "$FAKE_ROOT_WAKE" ]; then status=working
        elif [ "$count" -lt 3 ]; then status=working
        else status=idle
        fi
        printf '{"result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t1","pane_id":"w1:p1","terminal_id":"term_1","name":"fi-root-lead","agent_status":"%s","agent_session":{"value":"root-session"}}}}\n' "$status"
        ;;
      w1:p2)
        if [ -f "$FAKE_LEAD_SUBMITTED" ]; then
          count=$(cat "$FAKE_LEAD_CALLS"); count=$((count + 1)); printf '%s\n' "$count" > "$FAKE_LEAD_CALLS"
          [ "$count" -eq 1 ] && status=working || status=done
        else status=done
        fi
        printf '{"result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t2","pane_id":"w1:p2","terminal_id":"term_2","name":"team-lead","agent_status":"%s","agent_session":{"value":"session-2"}}}}\n' "$status"
        ;;
      w1:p3)
        printf '%s\n' '{"result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t3","pane_id":"w1:p3","terminal_id":"term_3","name":"evidence-research","agent_status":"done","agent_session":{"value":"session-3"}}}}'
        ;;
      w1:p4)
        printf '%s\n' '{"result":{"agent":{"agent":"codex","workspace_id":"w1","tab_id":"w1:t4","pane_id":"w1:p4","terminal_id":"term_4","name":"contract-tester","agent_status":"blocked","agent_session":{"value":"session-4"}}}}'
        ;;
      *) exit 2 ;;
    esac
    ;;
  pane:process-info)
    pane=${4:-}
    case "$pane" in
      w1:p1) receipt=$FAKE_TEAM_DIR/root.launch.json ;;
      w1:p2) receipt=$FAKE_TEAM_DIR/lead.launch.json ;;
      w1:p3) receipt=$FAKE_TEAM_DIR/specialist-1.launch.json ;;
      w1:p4) receipt=$FAKE_TEAM_DIR/specialist-2.launch.json ;;
      *) exit 2 ;;
    esac
    python3 - "$receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(json.dumps({"result": {"process_info": {"foreground_processes": [{
    "pid": value["process_pid"], "argv": value["process_argv"], "cwd": value["cwd"]
}]}}}, separators=(",", ":")))
PY
    ;;
  pane:read)
    case "$pane" in
      w1:p2) [ -f "$FAKE_LEAD_SUBMITTED" ] && printf 'lead-synthesis\n' || printf 'lead-planning\n' ;;
      w1:p3) printf 'research-specialist-raw\n' ;;
      w1:p4) printf 'tester-specialist-blocked-raw\n' ;;
      *) exit 2 ;;
    esac
    ;;
  agent:send)
    case "$pane" in
      w1:p2) : > "$FAKE_LEAD_SUBMITTED" ;;
      w1:p1) : > "$FAKE_ROOT_WAKE" ;;
      *) exit 2 ;;
    esac
    ;;
  pane:send-keys) ;;
  wait:agent-status)
    target=$3
    wanted=
    while [ "$#" -gt 0 ]; do
      [ "$1" != --status ] || { shift; wanted=$1; }
      shift || true
    done
    case "$target:$wanted" in
      w1:p2:working) [ -f "$FAKE_LEAD_SUBMITTED" ] ;;
      w1:p1:working) [ -f "$FAKE_ROOT_WAKE" ] ;;
      *) exit 1 ;;
    esac
    ;;
  pane:get)
    [ "$pane" = w1:p8 ] || exit 2
    printf '%s\n' '{"result":{"pane":{"workspace_id":"w1","tab_id":"w1:t8","pane_id":"w1:p8","terminal_id":"term_8"}}}'
    ;;
  tab:close) ;;
  *) exit 2 ;;
esac
SH
chmod +x "$fake_bin/herdr"

team_env() {
  env PATH="$fake_bin:$PATH" CODEX_HOME="$codex_home" FAKE_LOG="$fake_log" \
    FAKE_ROOT_CALLS="$root_calls" FAKE_LEAD_CALLS="$lead_calls" \
    FAKE_LEAD_SUBMITTED="$lead_submitted" FAKE_ROOT_WAKE="$root_wake" \
    FAKE_TEAM_DIR="$team_dir" "$@"
}

team_env python3 "$root/templates/orchestration/scripts/wait-coworker-team.py" \
  relay "$team_dir/team.json" || fail "team relay failed"

[ "$(grep -c '^agent send w1:p1 ' "$fake_log")" -eq 1 ] \
  || fail "root was not woken exactly once"
[ "$(cat "$root_calls")" -ge 3 ] || fail "relay woke root while it was still working"
[ "$(grep -c '^agent send w1:p2 ' "$fake_log")" -eq 1 ] \
  || fail "specialist artifact index was not submitted once to Tech Lead"
root_message=$(grep '^agent send w1:p1 ' "$fake_log")
case "$root_message" in
  *research-specialist-raw*|*tester-specialist-blocked-raw*)
    fail "raw specialist output leaked into the root wake" ;;
esac
printf '%s\n' "$root_message" | grep -Fq 'Tech Lead synthesis ready' \
  || fail "root wake did not point to Tech Lead synthesis"

result=$(team_env sh "$root/templates/orchestration/scripts/collect-coworker-team.sh" \
  "$team_dir/team.json") || fail "ready Tech Lead synthesis could not be collected"
[ "$result" = lead-synthesis ] || fail "collection returned something other than Tech Lead synthesis"

python3 - "$team_dir" <<'PY' || fail "team artifacts violate fan-in contract"
import json, pathlib, sys
team = pathlib.Path(sys.argv[1])
state = json.loads((team / "state.json").read_text())
assert state["phase"] == "synthesis-ready"
index = json.loads((team / "artifacts/specialist-index.json").read_text())
assert [item["task_role"] for item in index["specialists"]] == ["researcher", "tester"]
assert [item["status"] for item in index["specialists"]] == ["done", "blocked"]
for item in index["specialists"]:
    assert pathlib.Path(item["artifact"]).is_file()
PY

team_env python3 "$root/templates/orchestration/scripts/wait-coworker-team.py" \
  close "$team_dir/team.json" || fail "receipt-bound team teardown failed"
grep -Fq 'tab close w1:t8' "$fake_log" || fail "relay tab was not closed"
for tab in w1:t2 w1:t3 w1:t4; do
  grep -Fq "tab close $tab" "$fake_log" || fail "coworker tab was not closed: $tab"
done
if grep -Fq 'tab close w1:t1' "$fake_log"; then
  fail "team teardown closed the root tab"
fi

echo "coworker team contracts: PASS"
