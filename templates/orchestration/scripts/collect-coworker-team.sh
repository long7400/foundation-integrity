#!/bin/sh
# Print only the bound Tech Lead synthesis after the relay marks it ready.
set -eu

receipt=${1:-}
if [ -z "$receipt" ]; then
  echo "usage: $0 TEAM_RECEIPT" >&2
  exit 2
fi
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
exec python3 "$script_dir/wait-coworker-team.py" collect "$receipt"
