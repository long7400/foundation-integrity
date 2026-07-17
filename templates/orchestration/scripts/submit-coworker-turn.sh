#!/bin/sh
# Type once, submit, and verify a new turn on the pane bound by a launch receipt.
set -eu

collected_output=
if [ "${1:-}" = --collected-output ]; then
  [ "$#" -ge 3 ] || {
    echo "usage: $0 [--collected-output capture.json] <launch-receipt.json> < task-packet.md" >&2
    exit 2
  }
  collected_output=$2
  shift 2
fi
receipt=${1:-}
timeout_ms=${FI_SUBMIT_TIMEOUT_MS:-3000}
if [ -z "$receipt" ] || [ ! -f "$receipt" ] || [ -L "$receipt" ]; then
  echo "usage: $0 [--collected-output capture.json] <launch-receipt.json> < task-packet.md" >&2
  exit 2
fi
if [ -n "$collected_output" ] \
  && { [ ! -f "$collected_output" ] || [ -L "$collected_output" ]; }; then
  echo "submit coworker: collected output must be a regular non-symlink file" >&2
  exit 2
fi
case "$timeout_ms" in ''|*[!0-9]*) echo "submit coworker: invalid timeout" >&2; exit 2 ;; esac
command -v herdr >/dev/null 2>&1 || { echo "submit coworker: herdr not found" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

packet=$(cat)
[ -n "$packet" ] || { echo "submit coworker: empty task packet" >&2; exit 2; }

pane_id=$(python3 - "$receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("schema") != "foundation-integrity-codex-launch:v2":
    raise SystemExit("submit coworker: invalid launch receipt schema")
pane = value.get("pane_id")
if not isinstance(pane, str) or not pane:
    raise SystemExit("submit coworker: launch receipt omitted pane_id")
print(pane)
PY
) || exit 2
profile_binding=$(python3 - "$receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print(f'{value.get("profile", "")}\t{value.get("codex_home", "")}\t{value.get("task_role") or ""}')
PY
) || exit 2
expected_profile=${profile_binding%%	*}
rest=${profile_binding#*	}
expected_codex_home=${rest%%	*}
expected_role=${rest#*	}
if [ -n "$expected_role" ]; then
  profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
    "$expected_profile" "$expected_codex_home" --role "$expected_role") || exit 1
else
  profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
    "$expected_profile" "$expected_codex_home") || exit 1
fi
info=$(herdr agent get "$pane_id")
process_info=$(herdr pane process-info --pane "$pane_id")
FI_RECEIPT=$receipt FI_AGENT_INFO=$info FI_PROCESS_INFO=$process_info \
FI_PROFILE_ATTESTATION=$profile_attestation FI_COLLECTED_OUTPUT=$collected_output \
python3 - <<'PY'
import hashlib, json, os, pathlib, stat, subprocess
receipt_path = pathlib.Path(os.environ["FI_RECEIPT"])
receipt_bytes = receipt_path.read_bytes()
receipt = json.loads(receipt_bytes)
agent = json.loads(os.environ["FI_AGENT_INFO"])["result"]["agent"]
process = json.loads(os.environ["FI_PROCESS_INFO"])["result"]["process_info"]
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
for receipt_key, profile_key in (
    ("profile", "profile"), ("profile_sha256", "sha256"),
    ("profile_device", "device"), ("profile_inode", "inode"),
    ("profile_path", "path"), ("codex_home", "codex_home"),
    ("profile_tier", "profile_tier"), ("task_role", "role"),
    ("role_sha256", "role_sha256"), ("role_path", "role_path"),
):
    if receipt.get(receipt_key) != profile.get(profile_key):
        raise SystemExit("submit coworker: profile provenance differs from launch receipt")
digest = __import__("hashlib").sha256(profile["developer_instructions"].encode("utf-8")).hexdigest()
if receipt.get("developer_instructions_sha256") != digest:
    raise SystemExit("submit coworker: effective developer instructions differ from launch receipt")
for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name"):
    if agent.get(key) != receipt.get(key):
        raise SystemExit(f"submit coworker: live {key} differs from launch receipt")
expected_session = receipt.get("agent_session_id")
live_session = agent.get("agent_session")
live_session = live_session.get("value") if isinstance(live_session, dict) else None
if expected_session and live_session != expected_session:
    raise SystemExit("submit coworker: live session differs from launch receipt")
status = agent.get("agent_status")
if status != "idle":
    capture_value = os.environ.get("FI_COLLECTED_OUTPUT", "")
    if status != "done" or not capture_value:
        raise SystemExit("submit coworker: target must be idle, or done with bound collected output")
    capture_path = pathlib.Path(capture_value)
    metadata = os.lstat(capture_path)
    if not stat.S_ISREG(metadata.st_mode):
        raise SystemExit("submit coworker: collected output is not a regular file")
    capture = json.loads(capture_path.read_text(encoding="utf-8"))
    if capture.get("schema") != "foundation-integrity-coworker-capture:v1":
        raise SystemExit("submit coworker: invalid collected output schema")
    expected = {
        "receipt_sha256": hashlib.sha256(receipt_bytes).hexdigest(),
        "pane_id": receipt.get("pane_id"),
        "agent_session_id": receipt.get("agent_session_id"),
        "status": "done",
    }
    for key, value in expected.items():
        if capture.get(key) != value:
            raise SystemExit("submit coworker: collected output does not bind the completed turn")
    output = capture.get("output")
    if not isinstance(output, str) or not output:
        raise SystemExit("submit coworker: collected output is empty")
    if capture.get("output_sha256") != hashlib.sha256(output.encode("utf-8")).hexdigest():
        raise SystemExit("submit coworker: collected output hash is invalid")
expected_argv = receipt.get("process_argv")
matches = [item for item in process.get("foreground_processes", [])
           if item.get("argv") == expected_argv
           and item.get("cwd") == receipt.get("cwd")
           and item.get("pid") == receipt.get("process_pid")]
if len(matches) != 1:
    raise SystemExit("submit coworker: effective process no longer matches launch receipt")
started_at = subprocess.run(
    ["ps", "-o", "lstart=", "-p", str(receipt.get("process_pid"))], check=False,
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
).stdout.strip()
if not started_at or started_at != receipt.get("process_started_at"):
    raise SystemExit("submit coworker: process start identity differs from launch receipt")
PY

# `agent send` writes literal text but does not press Enter. Never repeat this call:
# duplicated task packets are harder to detect than a missed Enter.
herdr agent send "$pane_id" "$packet" >/dev/null

attempt=1
while [ "$attempt" -le 2 ]; do
  herdr pane send-keys "$pane_id" enter >/dev/null
  if herdr wait agent-status "$pane_id" --status working --timeout "$timeout_ms" >/dev/null 2>&1; then
    herdr agent get "$pane_id"
    exit 0
  fi
  attempt=$((attempt + 1))
done

echo "submit coworker: packet was typed once but no working transition was observed" >&2
echo "inspect pane $pane_id before retrying; do not retype the packet blindly" >&2
exit 1
