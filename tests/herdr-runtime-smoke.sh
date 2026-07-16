#!/bin/sh
# Opt-in real Herdr/Codex probe. --with-turn exercises the complete turn path.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
with_turn=0
if [ "${1:-}" = --with-turn ]; then
  with_turn=1
  shift
fi
profile=${1:-fi-peer-challenge}
receipt=$(mktemp "${TMPDIR:-/tmp}/fi-herdr-runtime.XXXXXX")
transcript=$(mktemp "${TMPDIR:-/tmp}/fi-herdr-telemetry.XXXXXX")
owns_authority=0
tab_id=

cleanup() {
  [ -z "$tab_id" ] || herdr tab close "$tab_id" >/dev/null 2>&1 || true
  if [ "$owns_authority" = 1 ] && [ -n "${FI_VALIDATION_TOKEN:-}" ]; then
    FI_VALIDATION_TOKEN=$FI_VALIDATION_TOKEN \
      sh "$root/templates/orchestration/scripts/validation-lease.sh" revoke \
      >/dev/null 2>&1 || true
  fi
  rm -f "$receipt" "$transcript"
}
trap cleanup EXIT HUP INT TERM

[ "${HERDR_ENV:-}" = 1 ] || { echo "runtime smoke: HERDR_ENV=1 is required" >&2; exit 2; }
command -v herdr >/dev/null 2>&1 || { echo "runtime smoke: herdr not found" >&2; exit 2; }
command -v codex >/dev/null 2>&1 || { echo "runtime smoke: codex not found" >&2; exit 2; }

if [ -z "${FI_VALIDATION_TOKEN:-}" ]; then
  FI_VALIDATION_TOKEN=$(sh "$root/templates/orchestration/scripts/validation-lease.sh" authorize)
  export FI_VALIDATION_TOKEN
  owns_authority=1
else
  sh "$root/templates/orchestration/scripts/validation-lease.sh" verify
fi

HERDR_ENV=1 sh "$root/templates/orchestration/scripts/start-codex-coworker.sh" \
  "runtime-smoke-$$" "$profile" "$root" > "$receipt"

values=$(python3 - "$receipt" <<'PY'
import json, pathlib, sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text())
print("\t".join((value["tab_id"], value["pane_id"], value["terminal_id"])))
PY
)
tab_id=${values%%	*}
rest=${values#*	}
pane_id=${rest%%	*}

process_info=$(herdr pane process-info --pane "$pane_id")
pid=$(printf '%s\n' "$process_info" | python3 -c '
import json, sys
items = json.load(sys.stdin)["result"]["process_info"]["foreground_processes"]
matches = [item for item in items if item.get("argv", [None])[0] == "codex"]
if len(matches) != 1:
    raise SystemExit(1)
print(matches[0]["pid"])
') || { echo "runtime smoke: no live Codex foreground process" >&2; exit 1; }
kill -0 "$pid" 2>/dev/null || { echo "runtime smoke: Codex PID is not live" >&2; exit 1; }

if ps eww -p "$pid" | rg -q \
  '(^| )(HERDR_(ENV|PANE_ID|TAB_ID|WORKSPACE_ID|SOCKET_PATH|STARTUP_CWD)|FI_(HERDR_WORKSPACE_ID|ROOT_LAUNCH_RECEIPT|VALIDATION_TOKEN|VALIDATION_OWNER|VALIDATION_COMMAND|VALIDATION_AUTHORITY_FILE|VALIDATION_LOCK_DIR))='; then
  echo "runtime smoke: root topology/capability leaked into coworker environment" >&2
  exit 1
fi

herdr agent get "$pane_id" | python3 -c '
import json, sys
agent = json.load(sys.stdin)["result"]["agent"]
if agent.get("agent_status") != "idle":
    raise SystemExit("runtime smoke: coworker is not idle")
' || exit 1

cat > "$transcript" <<'JSONL'
{"timestamp":"2026-07-16T13:00:00.000Z","type":"compacted","payload":{"window_number":1}}
{"timestamp":"2026-07-16T13:05:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":150000},"last_token_usage":{"input_tokens":50000,"cached_input_tokens":45000,"total_tokens":60000},"model_context_window":100000}}}
JSONL
printf '{"hook_event_name":"Stop","transcript_path":"%s"}\n' "$transcript" | \
  HERDR_PANE_ID="$pane_id" HERDR_BIN=herdr FI_TELEMETRY_NOW_EPOCH=1784197800 \
  python3 "$root/templates/hooks/scripts/herdr-pane-telemetry.py"
herdr pane get "$pane_id" | python3 -c '
import json, sys
tokens = json.load(sys.stdin)["result"]["pane"].get("tokens", {})
expected = {
    "ctx": "ctx 55%", "left": "left 45%", "compact": "compact 1",
    "cache_ratio": "cache 90%", "cached": "cached 45k", "spent": "spent 150k",
}
if any(tokens.get(key) != value for key, value in expected.items()):
    raise SystemExit(f"runtime smoke: real metadata mismatch: {tokens}")
' || exit 1

if [ "$with_turn" = 1 ]; then
  printf '%s\n' 'Reply with exactly RUNTIME_SMOKE_OK and nothing else.' | \
    sh "$root/templates/orchestration/scripts/submit-coworker-turn.sh" "$receipt" \
    >/dev/null
  output=$(sh "$root/templates/orchestration/scripts/wait-coworker-turn.sh" \
    "$receipt" 180000 120)
  printf '%s\n' "$output" | grep -Fq 'RUNTIME_SMOKE_OK' || {
    echo "runtime smoke: completed turn omitted RUNTIME_SMOKE_OK" >&2
    exit 1
  }
fi

mode=launch
[ "$with_turn" = 0 ] || mode=full-turn
echo "Herdr runtime smoke: PASS mode=$mode pane=$pane_id pid=$pid"
