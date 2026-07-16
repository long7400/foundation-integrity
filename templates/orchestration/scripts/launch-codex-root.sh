#!/bin/sh
# Pre-attest the canonical root envelope, record it, then preserve PID/start via exec.
set -eu

receipt=${1:-}
cwd=${2:-$PWD}
codex_home=${CODEX_HOME:-${HOME:?}/.codex}
codex_bin=${CODEX_BIN:-codex}
if [ -z "$receipt" ]; then
  echo "usage: $0 <new-root-launch-receipt.json> [repo-root]" >&2
  exit 2
fi
case "$receipt" in /*) ;; *) echo "root launch: receipt path must be absolute" >&2; exit 2 ;; esac
[ ! -e "$receipt" ] && [ ! -L "$receipt" ] \
  || { echo "root launch: receipt already exists: $receipt" >&2; exit 1; }
[ -d "$cwd" ] || { echo "root launch: cwd does not exist: $cwd" >&2; exit 2; }
[ "${HERDR_ENV:-}" = 1 ] || { echo "root launch: HERDR_ENV=1 is required" >&2; exit 2; }
: "${HERDR_WORKSPACE_ID:?root launch: HERDR_WORKSPACE_ID is required}"
: "${HERDR_TAB_ID:?root launch: HERDR_TAB_ID is required}"
: "${HERDR_PANE_ID:?root launch: HERDR_PANE_ID is required}"
command -v herdr >/dev/null 2>&1 || { echo "root launch: herdr not found" >&2; exit 2; }
command -v "$codex_bin" >/dev/null 2>&1 || { echo "root launch: Codex executable not found" >&2; exit 2; }

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cwd=$(CDPATH= cd -- "$cwd" && pwd -P)
pane_identity=$(herdr pane get "$HERDR_PANE_ID" | python3 -c '
import json, sys
pane = json.load(sys.stdin)["result"]["pane"]
keys = ("workspace_id", "tab_id", "pane_id", "terminal_id")
values = [pane.get(key) for key in keys]
if not all(isinstance(value, str) and value for value in values):
    raise SystemExit("root launch: Herdr pane identity is incomplete")
print("\t".join(values))
') || exit 1
workspace_id=${pane_identity%%	*}
rest=${pane_identity#*	}
tab_id=${rest%%	*}
rest=${rest#*	}
pane_id=${rest%%	*}
terminal_id=${rest#*	}
[ "$workspace_id" = "$HERDR_WORKSPACE_ID" ] \
  && [ "$tab_id" = "$HERDR_TAB_ID" ] && [ "$pane_id" = "$HERDR_PANE_ID" ] \
  || { echo "root launch: live pane differs from inherited Herdr identity" >&2; exit 1; }
profile_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
  fi-root-lead "$codex_home") || exit 2
started_at=$(ps -o lstart= -p "$$" \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ -n "$started_at" ] || { echo "root launch: process start identity unavailable" >&2; exit 1; }

FI_PROFILE_ATTESTATION=$profile_attestation FI_RECEIPT=$receipt FI_PID=$$ \
FI_STARTED_AT=$started_at FI_CWD=$cwd FI_WORKSPACE_ID=$workspace_id \
FI_TAB_ID=$tab_id FI_PANE_ID=$pane_id FI_TERMINAL_ID=$terminal_id python3 - <<'PY'
import json, os
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
value = {
    "schema": "foundation-integrity-codex-root-launch:v1",
    "workspace_id": os.environ["FI_WORKSPACE_ID"],
    "tab_id": os.environ["FI_TAB_ID"],
    "pane_id": os.environ["FI_PANE_ID"],
    "terminal_id": os.environ["FI_TERMINAL_ID"],
    "name": "fi-root-lead",
    "cwd": os.environ["FI_CWD"],
    "process_pid": int(os.environ["FI_PID"]),
    "process_started_at": os.environ["FI_STARTED_AT"],
    "process_argv": ["codex", *profile["cli_args"]],
    "profile": profile,
}
content = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
descriptor = os.open(os.environ["FI_RECEIPT"], flags, 0o600)
try:
    view = memoryview(content)
    while view:
        written = os.write(descriptor, view)
        if written <= 0:
            raise OSError("short root receipt write")
        view = view[written:]
    os.fsync(descriptor)
finally:
    os.close(descriptor)
PY
trap 'unlink "$receipt" >/dev/null 2>&1 || true' EXIT HUP INT TERM

final_attestation=$(python3 "$script_dir/attest-codex-profile.py" \
  fi-root-lead "$codex_home") || exit 1
[ "$final_attestation" = "$profile_attestation" ] \
  || { echo "root launch: profile provenance changed before exec" >&2; exit 1; }
herdr pane rename "$HERDR_PANE_ID" fi-root-lead >/dev/null
export FI_ROOT_LAUNCH_RECEIPT=$receipt
cd "$cwd"
FI_PROFILE_ATTESTATION=$profile_attestation FI_CODEX_BIN=$codex_bin exec python3 -c '
import json, os
profile = json.loads(os.environ["FI_PROFILE_ATTESTATION"])
binary = os.environ["FI_CODEX_BIN"]
os.execvp(binary, [binary, *profile["cli_args"]])
'
