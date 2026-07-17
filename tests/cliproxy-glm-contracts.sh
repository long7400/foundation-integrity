#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script="$root/templates/orchestration/scripts/cliproxy-glm.sh"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-cliproxy-contracts.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

project="$tmp/project"
mkdir -p "$project/.orchestration/foundation/scripts" "$project/.orchestration/foundation/profiles/codex"
cp "$script" "$project/.orchestration/foundation/scripts/cliproxy-glm.sh"
cp "$root/templates/orchestration/profiles/codex/fi-glm-"*.config.toml \
  "$project/.orchestration/foundation/profiles/codex/"
script="$project/.orchestration/foundation/scripts/cliproxy-glm.sh"
sh -n "$script"
if rg -n '^  stop \|\| true$' "$script" >/dev/null; then
  echo "cliproxy contract: remove can erase state after failed stop" >&2
  exit 1
fi
state="$project/.foundation/cliproxy-glm/state"
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

mkdir -p "$project/.foundation/cliproxy-glm"
printf '# malformed\n' >"$project/.foundation/cliproxy-glm/installed-profiles.tsv"
if sh "$script" remove >/dev/null 2>&1; then
  echo "cliproxy contract: malformed profile manifest was accepted" >&2
  exit 1
fi

echo "cliproxy lifecycle contracts: PASS"
