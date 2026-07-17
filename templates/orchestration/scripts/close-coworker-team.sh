#!/bin/sh
# Root-authorized teardown for exactly the relay and coworkers bound by a team receipt.
set -eu

receipt=${1:-}
if [ -z "$receipt" ]; then
  echo "usage: $0 TEAM_RECEIPT" >&2
  exit 2
fi
[ "${HERDR_ENV:-}" = 1 ] || { echo "close coworker team: HERDR_ENV=1 is required" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
FI_VALIDATION_TOKEN=${FI_VALIDATION_TOKEN:-} \
  sh "$script_dir/validation-lease.sh" verify >/dev/null \
  || { echo "close coworker team: root validation authority is required" >&2; exit 2; }
exec python3 "$script_dir/wait-coworker-team.py" close "$receipt"
