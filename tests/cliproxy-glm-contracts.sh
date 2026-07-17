#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script="$root/templates/orchestration/scripts/cliproxy-glm.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-cliproxy-contracts.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sh -n "$script"
export XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" XDG_DATA_HOME="$tmp/data" CODEX_HOME="$tmp/codex"
state="$XDG_STATE_HOME/foundation-integrity/cliproxy-glm"
mkdir -p "$state/lifecycle.lock"
printf '%s\n%s\n' "$$" "$(ps -p $$ -o lstart=)" >"$state/lifecycle.lock/owner-pid"
if sh "$script" stop >/dev/null 2>&1; then
  echo "cliproxy contract: live lifecycle lock was bypassed" >&2
  exit 1
fi
rm -rf "$state/lifecycle.lock"

sleep 20 & innocent=$!
printf '%s\n' "$innocent" >"$state/cliproxy.pid"
sh "$script" stop >/dev/null 2>&1 || true
kill -0 "$innocent" 2>/dev/null
kill "$innocent" 2>/dev/null || true

mkdir -p "$XDG_CONFIG_HOME/foundation-integrity/cliproxy-glm"
printf '# malformed\n' >"$XDG_CONFIG_HOME/foundation-integrity/cliproxy-glm/installed-profiles.tsv"
if sh "$script" remove >/dev/null 2>&1; then
  echo "cliproxy contract: malformed profile manifest was accepted" >&2
  exit 1
fi

echo "cliproxy lifecycle contracts: PASS"
