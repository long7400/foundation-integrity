#!/bin/sh
# Bounded attention loop bound to a launch receipt. It never accepts the work.
set -eu

receipt=${1:-}
timeout_ms=${2:-120000}
lines=${3:-300}
if [ -z "$receipt" ] || [ ! -f "$receipt" ] || [ -L "$receipt" ]; then
  echo "usage: $0 <launch-receipt.json> [timeout-ms] [lines]" >&2
  exit 2
fi
case "$timeout_ms:$lines" in *[!0-9:]*) echo "wait coworker: invalid numeric argument" >&2; exit 2 ;; esac
command -v herdr >/dev/null 2>&1 || { echo "wait coworker: herdr not found" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

verify_process() {
  if [ -n "$expected_role" ]; then
    profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
      "$expected_profile" --role "$expected_role") || exit 1
  else
    profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
      "$expected_profile") || exit 1
  fi
  process_info=$(herdr pane process-info --pane "$expected_pane") || exit 1
  FI_RECEIPT=$receipt FI_PROCESS_INFO=$process_info \
    FI_PROFILE_ATTESTATION=$profile_attestation python3 - <<'PY'
import json, os, pathlib, stat, subprocess
receipt_path = pathlib.Path(os.environ["FI_RECEIPT"])
before = os.lstat(receipt_path)
receipt_bytes = receipt_path.read_bytes()
after = os.lstat(receipt_path)
if not stat.S_ISREG(before.st_mode) or (
    before.st_dev != after.st_dev or before.st_ino != after.st_ino
):
    raise SystemExit("wait coworker: launch receipt changed while being read")
receipt = json.loads(receipt_bytes)
process = json.loads(os.environ["FI_PROCESS_INFO"])["result"]["process_info"]
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
if receipt.get("profile_attestation") != profile:
    raise SystemExit("wait coworker: profile provenance differs from launch receipt")
digest = __import__("hashlib").sha256(profile["developer_instructions"].encode("utf-8")).hexdigest()
if receipt.get("developer_instructions_sha256") != digest:
    raise SystemExit("wait coworker: effective developer instructions differ from launch receipt")
matches = [
    item for item in process.get("foreground_processes", [])
    if item.get("argv") == receipt.get("process_argv")
    and item.get("cwd") == receipt.get("cwd")
    and item.get("pid") == receipt.get("process_pid")
]
if len(matches) != 1:
    raise SystemExit("wait coworker: effective process no longer matches launch receipt")
started_at = subprocess.run(
    ["ps", "-o", "lstart=", "-p", str(receipt.get("process_pid"))], check=False,
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
).stdout.strip()
if not started_at or started_at != receipt.get("process_started_at"):
    raise SystemExit("wait coworker: process start identity differs from launch receipt")
PY
}

expected=$(python3 - "$receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("schema") != "foundation-integrity-codex-launch:v2":
    raise SystemExit("wait coworker: invalid launch receipt schema")
keys = (
    "workspace_id", "tab_id", "pane_id", "terminal_id", "name",
    "agent_session_id", "profile", "task_role",
)
print("\t".join("" if value.get(key) is None else str(value.get(key)) for key in keys))
PY
) || exit 2
expected_workspace=${expected%%	*}
rest=${expected#*	}
expected_tab=${rest%%	*}
rest=${rest#*	}
expected_pane=${rest%%	*}
rest=${rest#*	}
expected_terminal=${rest%%	*}
rest=${rest#*	}
expected_name=${rest%%	*}
rest=${rest#*	}
expected_session=${rest%%	*}
rest=${rest#*	}
expected_profile=${rest%%	*}
rest=${rest#*	}
expected_role=${rest#*	}

# Reject a stale/reused pane before entering the attention loop. Recheck again at
# the terminal observation immediately before collecting output.
verify_process

attempts=$((timeout_ms / 500 + 1))
attempt=0
while [ "$attempt" -lt "$attempts" ]; do
  info=$(herdr agent get "$expected_pane") || exit 1
  parsed=$(printf '%s\n' "$info" | python3 -c '
import json, sys
agent = json.load(sys.stdin).get("result", {}).get("agent", {})
session = agent.get("agent_session")
session = session.get("value") if isinstance(session, dict) else ""
keys = ("workspace_id", "tab_id", "pane_id", "terminal_id", "name", "agent_status")
values = [agent.get(key) for key in keys]
if not all(isinstance(value, str) and value for value in values):
    raise SystemExit(1)
print("\t".join(values + [session or ""]))
') || { echo "wait coworker: invalid Herdr agent response" >&2; exit 1; }
  live_workspace=${parsed%%	*}
  rest=${parsed#*	}
  live_tab=${rest%%	*}
  rest=${rest#*	}
  live_pane=${rest%%	*}
  rest=${rest#*	}
  live_terminal=${rest%%	*}
  rest=${rest#*	}
  live_name=${rest%%	*}
  rest=${rest#*	}
  status=${rest%%	*}
  live_session=${rest#*	}
  [ "$live_workspace" = "$expected_workspace" ] \
    && [ "$live_tab" = "$expected_tab" ] \
    && [ "$live_pane" = "$expected_pane" ] \
    && [ "$live_terminal" = "$expected_terminal" ] \
    && [ "$live_name" = "$expected_name" ] \
    || { echo "wait coworker: live target differs from launch receipt" >&2; exit 1; }
  [ -z "$expected_session" ] || [ "$live_session" = "$expected_session" ] \
    || { echo "wait coworker: live session differs from launch receipt" >&2; exit 1; }
  case "$status" in
    idle|done)
      verify_process
      echo "wait coworker: attention status=$status pane=$expected_pane; root must inspect evidence" >&2
      herdr pane read "$expected_pane" --source recent-unwrapped --lines "$lines" --format text
      exit 0
      ;;
    blocked)
      verify_process
      echo "wait coworker: blocked pane=$expected_pane" >&2
      herdr pane read "$expected_pane" --source recent-unwrapped --lines "$lines" --format text
      exit 3
      ;;
    working|unknown) ;;
    *) echo "wait coworker: unexpected status=$status pane=$expected_pane" >&2 ;;
  esac
  attempt=$((attempt + 1))
  sleep 0.5
done

echo "wait coworker: timed out after ${timeout_ms}ms; inspect pane $expected_pane" >&2
exit 124
