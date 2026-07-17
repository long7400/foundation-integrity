#!/bin/sh
# Start one private, non-agent team relay and return its immutable receipt path.
set -eu

team_name=${1:-}
lead_receipt=${2:-}
if [ "$#" -ge 2 ]; then shift 2; else shift "$#"; fi
if [ -z "$team_name" ] || [ -z "$lead_receipt" ] || [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 TEAM_NAME TECH_LEAD_RECEIPT SPECIALIST_RECEIPT [SPECIALIST_RECEIPT ...]" >&2
  exit 2
fi
case "$team_name" in
  *[!A-Za-z0-9._-]*|'') echo "start coworker team: invalid team name" >&2; exit 2 ;;
esac
[ "${#team_name}" -le 64 ] || { echo "start coworker team: team name is too long" >&2; exit 2; }
[ "${HERDR_ENV:-}" = 1 ] || { echo "start coworker team: HERDR_ENV=1 is required" >&2; exit 2; }
: "${FI_ROOT_LAUNCH_RECEIPT:?start coworker team: FI_ROOT_LAUNCH_RECEIPT is required}"
case "$FI_ROOT_LAUNCH_RECEIPT" in
  /*) ;;
  *) echo "start coworker team: root launch receipt path must be absolute" >&2; exit 2 ;;
esac
command -v herdr >/dev/null 2>&1 || { echo "start coworker team: herdr not found" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FI_VALIDATION_TOKEN=${FI_VALIDATION_TOKEN:-} \
  sh "$script_dir/validation-lease.sh" verify >/dev/null \
  || { echo "start coworker team: root validation authority is required" >&2; exit 2; }

timeout_ms=${FI_TEAM_TIMEOUT_MS:-900000}
poll_initial_ms=${FI_TEAM_POLL_INITIAL_MS:-250}
poll_max_ms=${FI_TEAM_POLL_MAX_MS:-5000}
output_lines=${FI_TEAM_OUTPUT_LINES:-600}
submit_timeout_ms=${FI_SUBMIT_TIMEOUT_MS:-3000}
case "$timeout_ms:$poll_initial_ms:$poll_max_ms:$output_lines:$submit_timeout_ms" in
  *[!0-9:]*) echo "start coworker team: invalid numeric configuration" >&2; exit 2 ;;
esac
for receipt_path in "$FI_ROOT_LAUNCH_RECEIPT" "$lead_receipt" "$@"; do
  [ -f "$receipt_path" ] && [ ! -L "$receipt_path" ] \
    || { echo "start coworker team: receipt must be a regular non-symlink file: $receipt_path" >&2; exit 2; }
done

umask 077
team_dir=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-team.${team_name}.XXXXXX")
cleanup=1
relay_tab=
cleanup_on_exit() {
  if [ "$cleanup" = 1 ]; then
    [ -z "$relay_tab" ] || herdr tab close "$relay_tab" >/dev/null 2>&1 || true
    rm -rf "$team_dir"
  fi
}
trap cleanup_on_exit EXIT HUP INT TERM
mkdir "$team_dir/artifacts"
chmod 700 "$team_dir" "$team_dir/artifacts"
cp "$FI_ROOT_LAUNCH_RECEIPT" "$team_dir/root.launch.json"
cp "$lead_receipt" "$team_dir/lead.launch.json"
index=1
for specialist in "$@"; do
  cp "$specialist" "$team_dir/specialist-$index.launch.json"
  index=$((index + 1))
done
chmod 600 "$team_dir"/*.launch.json

root_values=$(python3 - "$team_dir/root.launch.json" "$team_dir/lead.launch.json" "$team_dir"/specialist-*.launch.json <<'PY'
import json, pathlib, sys
root = json.loads(pathlib.Path(sys.argv[1]).read_text())
lead = json.loads(pathlib.Path(sys.argv[2]).read_text())
specialists = [json.loads(pathlib.Path(path).read_text()) for path in sys.argv[3:]]
if root.get("schema") != "foundation-integrity-codex-root-launch:v1":
    raise SystemExit("start coworker team: invalid root receipt")
if lead.get("schema") != "foundation-integrity-codex-launch:v2" or lead.get("task_role") != "tech-lead":
    raise SystemExit("start coworker team: lead must use a role-bound tech-lead receipt")
if not 1 <= len(specialists) <= 3:
    raise SystemExit("start coworker team: one to three specialists are required")
if any(value.get("schema") != "foundation-integrity-codex-launch:v2" for value in specialists):
    raise SystemExit("start coworker team: invalid specialist receipt")
if any(value.get("task_role") in (None, "tech-lead") for value in specialists):
    raise SystemExit("start coworker team: each specialist needs a non-lead task role")
members = [lead, *specialists]
workspace = root.get("workspace_id")
if not isinstance(workspace, str) or not workspace or any(value.get("workspace_id") != workspace for value in members):
    raise SystemExit("start coworker team: all coworkers must share the root workspace")
identities = [(value.get("tab_id"), value.get("pane_id"), value.get("name")) for value in members]
if len(set(identities)) != len(identities):
    raise SystemExit("start coworker team: coworker receipts must be unique")
print(f'{workspace}\t{root.get("cwd", "")}')
PY
) || exit 2
workspace_id=${root_values%%	*}
root_cwd=${root_values#*	}
[ -d "$root_cwd" ] || { echo "start coworker team: root cwd is unavailable" >&2; exit 2; }

creation=$(herdr tab create --workspace "$workspace_id" --cwd "$root_cwd" \
  --label "relay-$team_name" --no-focus)
relay_ids=$(printf '%s\n' "$creation" | python3 -c '
import json, sys
value = json.load(sys.stdin)
pane = value.get("result", {}).get("root_pane", {})
tab = value.get("result", {}).get("tab", {})
values = (tab.get("workspace_id"), tab.get("tab_id"), pane.get("pane_id"), pane.get("terminal_id"))
if not all(isinstance(item, str) and item for item in values):
    raise SystemExit(1)
print("\t".join(values))
') || { echo "start coworker team: Herdr response omitted relay IDs" >&2; exit 1; }
relay_workspace=${relay_ids%%	*}
rest=${relay_ids#*	}
relay_tab=${rest%%	*}
rest=${rest#*	}
relay_pane=${rest%%	*}
relay_terminal=${rest#*	}
[ "$relay_workspace" = "$workspace_id" ] \
  || { echo "start coworker team: relay workspace differs from root" >&2; exit 1; }

team_receipt=$team_dir/team.json
FI_TEAM_DIR=$team_dir FI_TEAM_RECEIPT=$team_receipt FI_TEAM_NAME=$team_name \
FI_TIMEOUT_MS=$timeout_ms FI_POLL_INITIAL_MS=$poll_initial_ms \
FI_POLL_MAX_MS=$poll_max_ms FI_OUTPUT_LINES=$output_lines \
FI_SUBMIT_TIMEOUT_MS=$submit_timeout_ms FI_RELAY_WORKSPACE=$relay_workspace \
FI_RELAY_TAB=$relay_tab FI_RELAY_PANE=$relay_pane FI_RELAY_TERMINAL=$relay_terminal \
python3 - <<'PY'
import hashlib, json, os, pathlib

team_dir = pathlib.Path(os.environ["FI_TEAM_DIR"])
def binding(name):
    path = team_dir / name
    return {"receipt": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

specialists = [binding(path.name) for path in sorted(team_dir.glob("specialist-*.launch.json"))]
value = {
    "schema": "foundation-integrity-coworker-team:v1",
    "team_name": os.environ["FI_TEAM_NAME"],
    "root": binding("root.launch.json"),
    "lead": binding("lead.launch.json"),
    "specialists": specialists,
    "relay": {
        "workspace_id": os.environ["FI_RELAY_WORKSPACE"],
        "tab_id": os.environ["FI_RELAY_TAB"],
        "pane_id": os.environ["FI_RELAY_PANE"],
        "terminal_id": os.environ["FI_RELAY_TERMINAL"],
    },
    "timeout_ms": int(os.environ["FI_TIMEOUT_MS"]),
    "poll_initial_ms": int(os.environ["FI_POLL_INITIAL_MS"]),
    "poll_max_ms": int(os.environ["FI_POLL_MAX_MS"]),
    "output_lines": int(os.environ["FI_OUTPUT_LINES"]),
    "submit_timeout_ms": int(os.environ["FI_SUBMIT_TIMEOUT_MS"]),
}
content = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
descriptor = os.open(os.environ["FI_TEAM_RECEIPT"], flags, 0o600)
try:
    os.write(descriptor, content)
    os.fsync(descriptor)
finally:
    os.close(descriptor)
PY

relay_command=$(FI_RELAY_SCRIPT="$script_dir/wait-coworker-team.py" \
FI_TEAM_RECEIPT=$team_receipt python3 - <<'PY'
import os, shlex
args = [
    "env",
    "-u", "HERDR_PANE_ID", "-u", "HERDR_TAB_ID", "-u", "HERDR_WORKSPACE_ID",
    "-u", "HERDR_STARTUP_CWD", "-u", "FI_HERDR_WORKSPACE_ID",
    "-u", "FI_VALIDATION_TOKEN", "-u", "FI_VALIDATION_OWNER",
    "-u", "FI_VALIDATION_COMMAND", "-u", "FI_VALIDATION_AUTHORITY_FILE",
    "-u", "FI_VALIDATION_LOCK_DIR", "-u", "FI_ROOT_LAUNCH_RECEIPT",
    "-u", "FI_CLIPROXY_KEY",
    "python3", os.environ["FI_RELAY_SCRIPT"], "relay", os.environ["FI_TEAM_RECEIPT"],
]
print(shlex.join(args))
PY
)
if ! herdr pane run "$relay_pane" "$relay_command" >/dev/null; then
  echo "start coworker team: relay launch failed" >&2
  exit 1
fi

cleanup=0
trap - EXIT HUP INT TERM
printf '%s\n' "$team_receipt"
