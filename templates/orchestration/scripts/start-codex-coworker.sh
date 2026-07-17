#!/bin/sh
# Start one fresh Codex coworker and emit a launch receipt on stdout.
set -eu

role=
if [ "${1:-}" = --role ]; then
  [ "$#" -ge 3 ] || { echo "usage: $0 [--role task-role] <unique-name> <fi-peer-*|fi-implementer-*|fi-glm-*> [cwd]" >&2; exit 2; }
  role=$2
  shift 2
fi
name=${1:-}
profile=${2:-}
cwd=${3:-$PWD}
timeout_ms=${FI_START_TIMEOUT_MS:-30000}
codex_bin=${CODEX_BIN:-codex}

if [ -z "$name" ] || [ -z "$profile" ]; then
  echo "usage: $0 [--role task-role] <unique-name> <fi-peer-*|fi-implementer-*|fi-glm-*> [cwd]" >&2
  exit 2
fi
case "$profile" in
  fi-peer-scout|fi-peer-challenge|fi-implementer-mechanical|fi-implementer-ambiguous|fi-glm-peer-scout|fi-glm-implementer-mechanical) ;;
  *) echo "start coworker: unsupported non-root profile: $profile" >&2; exit 2 ;;
esac
case "$timeout_ms" in ''|*[!0-9]*) echo "start coworker: invalid timeout" >&2; exit 2 ;; esac
[ "${HERDR_ENV:-}" = 1 ] || { echo "start coworker: HERDR_ENV=1 is required" >&2; exit 2; }
[ -d "$cwd" ] || { echo "start coworker: cwd does not exist: $cwd" >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { echo "start coworker: herdr not found" >&2; exit 2; }
command -v "$codex_bin" >/dev/null 2>&1 || { echo "start coworker: Codex executable not found" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FI_VALIDATION_TOKEN=${FI_VALIDATION_TOKEN:-} \
  sh "$script_dir/validation-lease.sh" verify >/dev/null \
  || { echo "start coworker: root validation authority is required before launch" >&2; exit 2; }

profile_attester=$script_dir/attest-codex-profile.py
if [ -n "$role" ]; then
  profile_attestation=$(python3 "$profile_attester" "$profile" --role "$role") || exit 2
else
  profile_attestation=$(python3 "$profile_attester" "$profile") || exit 2
fi
case "$profile" in
  fi-glm-*)
    [ -n "${FI_CLIPROXY_KEY:-}" ] \
      || { echo "start coworker: FI_CLIPROXY_KEY is required for GLM" >&2; exit 2; }
    sh "$script_dir/cliproxy-glm.sh" doctor >/dev/null \
      || { echo "start coworker: GLM gateway health check failed" >&2; exit 2; }
    ;;
esac
profile_values=$(printf '%s\n' "$profile_attestation" | python3 -c '
import json, sys
value = json.load(sys.stdin)
keys = ("model", "effort", "sandbox", "approval", "sha256", "device", "inode", "path", "profile_tier", "role", "role_sha256", "role_path")
print("\t".join("" if value.get(key) is None else str(value.get(key)) for key in keys))
') || exit 2
model=${profile_values%%	*}
rest=${profile_values#*	}
effort=${rest%%	*}
rest=${rest#*	}
sandbox=${rest%%	*}
rest=${rest#*	}
approval=${rest%%	*}
rest=${rest#*	}
profile_sha=${rest%%	*}
rest=${rest#*	}
profile_device=${rest%%	*}
rest=${rest#*	}
profile_inode=${rest%%	*}
rest=${rest#*	}
profile_path=${rest%%	*}
rest=${rest#*	}
profile_tier=${rest%%	*}
rest=${rest#*	}
attested_role=${rest%%	*}
rest=${rest#*	}
role_sha=${rest%%	*}
role_path=${rest#*	}

cwd=$(CDPATH= cd -- "$cwd" && pwd)
root_workspace=${FI_HERDR_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}
if [ -n "$root_workspace" ]; then
  creation=$(herdr tab create --workspace "$root_workspace" --cwd "$cwd" --label "$name" --no-focus)
else
  creation=$(herdr tab create --cwd "$cwd" --label "$name" --no-focus)
fi

ids=$(printf '%s\n' "$creation" | python3 -c '
import json, sys
obj = json.load(sys.stdin)
root = obj.get("result", {}).get("root_pane", {})
tab = obj.get("result", {}).get("tab", {})
values = (tab.get("workspace_id"), tab.get("tab_id"), root.get("pane_id"), root.get("terminal_id"))
if not all(isinstance(value, str) and value for value in values):
    raise SystemExit(1)
print("\t".join(values))
') || { echo "start coworker: Herdr response omitted creation IDs" >&2; exit 1; }
workspace_id=${ids%%	*}
rest=${ids#*	}
tab_id=${rest%%	*}
rest=${rest#*	}
pane_id=${rest%%	*}
terminal_id=${rest#*	}

command=$(FI_PROFILE_ATTESTATION=$profile_attestation FI_CODEX_BIN=$codex_bin python3 - <<'PY'
import json, os, shlex
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
args = [
    "env",
    "-u", "HERDR_ENV", "-u", "HERDR_PANE_ID", "-u", "HERDR_TAB_ID",
    "-u", "HERDR_WORKSPACE_ID", "-u", "HERDR_SOCKET_PATH",
    "-u", "HERDR_STARTUP_CWD", "-u", "FI_HERDR_WORKSPACE_ID",
    "-u", "FI_VALIDATION_TOKEN", "-u", "FI_VALIDATION_OWNER",
    "-u", "FI_VALIDATION_COMMAND", "-u", "FI_VALIDATION_AUTHORITY_FILE",
    "-u", "FI_VALIDATION_LOCK_DIR", "-u", "FI_ROOT_LAUNCH_RECEIPT",
    os.environ["FI_CODEX_BIN"], *profile["cli_args"],
]
print(shlex.join(args))
PY
)
if ! herdr pane run "$pane_id" "$command" >/dev/null; then
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  echo "start coworker: Codex launch failed" >&2
  exit 1
fi
if ! herdr wait agent-status "$pane_id" --status idle --timeout "$timeout_ms" >/dev/null; then
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  echo "start coworker: Codex did not become idle before timeout" >&2
  exit 1
fi
if ! herdr agent rename "$pane_id" "$name" >/dev/null; then
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  echo "start coworker: could not bind the unique agent name" >&2
  exit 1
fi

# A fresh background prompt can be classified as `done` merely because its initial
# readiness appeared while unseen. Normalize only this pre-task state, then restore
# focus to the root pane. Later `done` states must be collected, never auto-cleared.
ready_info=$(herdr agent get "$pane_id")
ready_status=$(printf '%s\n' "$ready_info" | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["agent"].get("agent_status", "unknown"))
')
if [ "$ready_status" = done ]; then
  herdr agent focus "$pane_id" >/dev/null
  herdr agent focus "$HERDR_PANE_ID" >/dev/null
  herdr wait agent-status "$pane_id" --status idle --timeout "$timeout_ms" >/dev/null \
    || { herdr tab close "$tab_id" >/dev/null 2>&1 || true; exit 1; }
elif [ "$ready_status" != idle ]; then
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  echo "start coworker: unexpected initial status $ready_status" >&2
  exit 1
fi

agent_info=$(herdr agent get "$pane_id")
process_info=$(herdr pane process-info --pane "$pane_id")
if [ -n "$role" ]; then
    final_profile_attestation=$(python3 "$profile_attester" "$profile" --role "$role") || {
    herdr tab close "$tab_id" >/dev/null 2>&1 || true
    exit 1
  }
else
    final_profile_attestation=$(python3 "$profile_attester" "$profile") || {
    herdr tab close "$tab_id" >/dev/null 2>&1 || true
    exit 1
  }
fi
[ "$final_profile_attestation" = "$profile_attestation" ] || {
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  echo "start coworker: profile provenance changed during launch" >&2
  exit 1
}

if ! receipt=$(FI_PROCESS_INFO=$process_info FI_AGENT_INFO=$agent_info \
FI_NAME=$name FI_PROFILE=$profile FI_PROFILE_PATH=$profile_path \
FI_PROFILE_SHA=$profile_sha FI_PROFILE_DEVICE=$profile_device \
FI_PROFILE_INODE=$profile_inode FI_CWD=$cwd \
FI_PROFILE_ATTESTATION=$profile_attestation \
FI_MODEL=$model FI_EFFORT=$effort FI_SANDBOX=$sandbox FI_APPROVAL=$approval \
FI_PROFILE_TIER=$profile_tier FI_TASK_ROLE=$attested_role \
FI_ROLE_SHA=$role_sha FI_ROLE_PATH=$role_path \
FI_WORKSPACE_ID=$workspace_id FI_TAB_ID=$tab_id FI_PANE_ID=$pane_id \
FI_TERMINAL_ID=$terminal_id python3 - <<'PY'
import json, os, pathlib, subprocess
process = json.loads(os.environ["FI_PROCESS_INFO"])["result"]["process_info"]
agent = json.loads(os.environ["FI_AGENT_INFO"])["result"]["agent"]
profile_attestation = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
expected_profile = os.environ["FI_PROFILE"]
expected_cwd = os.environ["FI_CWD"]
matches = []
for item in process.get("foreground_processes", []):
    argv = item.get("argv")
    if not isinstance(argv, list) or not argv:
        continue
    if pathlib.Path(str(argv[0])).name != "codex" or argv[1:] != profile_attestation["cli_args"]:
        continue
    if item.get("cwd") != expected_cwd:
        continue
    matches.append(item)
if len(matches) != 1:
    raise SystemExit("start coworker: effective Codex argv/cwd did not match the launch envelope")
process_pid = matches[0].get("pid")
if not isinstance(process_pid, int) or process_pid <= 1:
    raise SystemExit("start coworker: effective Codex process omitted pid")
process_started_at = subprocess.run(
    ["ps", "-o", "lstart=", "-p", str(process_pid)], check=False,
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
).stdout.strip()
if not process_started_at:
    raise SystemExit("start coworker: could not attest process start identity")
for key, expected in (
    ("workspace_id", os.environ["FI_WORKSPACE_ID"]),
    ("tab_id", os.environ["FI_TAB_ID"]),
    ("pane_id", os.environ["FI_PANE_ID"]),
    ("terminal_id", os.environ["FI_TERMINAL_ID"]),
    ("name", os.environ["FI_NAME"]),
):
    if agent.get(key) != expected:
        raise SystemExit(f"start coworker: live {key} does not match creation")
session = agent.get("agent_session")
session_id = session.get("value") if isinstance(session, dict) else None
if not isinstance(session_id, str) or not session_id:
    session_id = None
receipt = {
    "schema": "foundation-integrity-codex-launch:v2",
    "name": os.environ["FI_NAME"],
    "profile": expected_profile,
    "profile_sha256": os.environ["FI_PROFILE_SHA"],
    "profile_device": int(os.environ["FI_PROFILE_DEVICE"]),
    "profile_inode": int(os.environ["FI_PROFILE_INODE"]),
    "profile_path": os.environ["FI_PROFILE_PATH"],
    "profile_tier": os.environ["FI_PROFILE_TIER"],
    "profile_attestation": profile_attestation,
    "model": os.environ["FI_MODEL"],
    "effort": os.environ["FI_EFFORT"],
    "sandbox": os.environ["FI_SANDBOX"],
    "approval": os.environ["FI_APPROVAL"],
    "task_role": os.environ.get("FI_TASK_ROLE") or None,
    "role_sha256": os.environ.get("FI_ROLE_SHA") or None,
    "role_path": os.environ.get("FI_ROLE_PATH") or None,
    "developer_instructions_sha256": __import__("hashlib").sha256(
        profile_attestation["developer_instructions"].encode("utf-8")
    ).hexdigest(),
    "multi_agent": False,
    "multi_agent_v2": False,
    "cwd": expected_cwd,
    "workspace_id": os.environ["FI_WORKSPACE_ID"],
    "tab_id": os.environ["FI_TAB_ID"],
    "pane_id": os.environ["FI_PANE_ID"],
    "terminal_id": os.environ["FI_TERMINAL_ID"],
    "agent_session_id": session_id,
    "process_argv": matches[0]["argv"],
    "process_pid": process_pid,
    "process_started_at": process_started_at,
}
print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
PY
); then
  herdr tab close "$tab_id" >/dev/null 2>&1 || true
  exit 1
fi
printf '%s\n' "$receipt"
