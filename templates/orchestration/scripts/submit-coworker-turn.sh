#!/bin/sh
# Type once, submit, and verify a new turn on the pane bound by a launch receipt.
set -eu

receipt=${1:-}
timeout_ms=${FI_SUBMIT_TIMEOUT_MS:-3000}
if [ -z "$receipt" ] || [ ! -f "$receipt" ] || [ -L "$receipt" ]; then
  echo "usage: $0 <launch-receipt.json> < task-packet.md" >&2
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
print(f'{value.get("profile", "")}\t{value.get("codex_home", "")}')
PY
) || exit 2
expected_profile=${profile_binding%%	*}
expected_codex_home=${profile_binding#*	}
profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
  "$expected_profile" "$expected_codex_home") || exit 1
info=$(herdr agent get "$pane_id")
process_info=$(herdr pane process-info --pane "$pane_id")
FI_RECEIPT=$receipt FI_AGENT_INFO=$info FI_PROCESS_INFO=$process_info \
FI_PROFILE_ATTESTATION=$profile_attestation python3 - <<'PY'
import json, os, pathlib, subprocess
receipt = json.loads(pathlib.Path(os.environ["FI_RECEIPT"]).read_text(encoding="utf-8"))
agent = json.loads(os.environ["FI_AGENT_INFO"])["result"]["agent"]
process = json.loads(os.environ["FI_PROCESS_INFO"])["result"]["process_info"]
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
for receipt_key, profile_key in (
    ("profile", "profile"), ("profile_sha256", "sha256"),
    ("profile_device", "device"), ("profile_inode", "inode"),
    ("profile_path", "path"), ("codex_home", "codex_home"),
):
    if receipt.get(receipt_key) != profile.get(profile_key):
        raise SystemExit("submit coworker: profile provenance differs from launch receipt")
for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name"):
    if agent.get(key) != receipt.get(key):
        raise SystemExit(f"submit coworker: live {key} differs from launch receipt")
expected_session = receipt.get("agent_session_id")
live_session = agent.get("agent_session")
live_session = live_session.get("value") if isinstance(live_session, dict) else None
if expected_session and live_session != expected_session:
    raise SystemExit("submit coworker: live session differs from launch receipt")
if agent.get("agent_status") != "idle":
    raise SystemExit("submit coworker: target must be idle before a new turn")
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
