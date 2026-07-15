#!/bin/sh
# Acquire/release a transparent root controller lock for one pilot run.
# This is a liveness guard, not semantic task state. It deliberately has no
# automatic stale takeover; a human must inspect and remove a stale lock.
set -eu

action=${1:-}
lock_dir=${FI_CONTROLLER_LOCK_DIR:-.foundation/orchestration/controller.lock}
run_id=${FI_RUN_ID:-}
controller=${FI_CONTROLLER_ID:-${USER:-unknown}:$$}
lock_dir=$(printf '%s\n' "$lock_dir" | sed 's://*:/:g')

usage() {
  echo "usage: $0 acquire|release|status" >&2
  exit 2
}

case "$action" in acquire|release|status) ;; *) usage ;; esac

case "$lock_dir" in
  ''|*..*|*\|*) echo "controller lock: unsafe path" >&2; exit 2 ;;
esac

parent=${lock_dir%/*}
[ "$parent" = "$lock_dir" ] || mkdir -p "$parent"

case "$action" in
  acquire)
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "controller lock: already held at $lock_dir" >&2
      [ -f "$lock_dir/owner" ] && cat "$lock_dir/owner" >&2 || true
      exit 1
    fi
    umask 077
    printf '%s\n' "$controller" > "$lock_dir/owner"
    printf '%s\n' "$run_id" > "$lock_dir/run-id"
    printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" > "$lock_dir/acquired-at"
    printf '%s\n' "$lock_dir"
    ;;
  release)
    [ -d "$lock_dir" ] || { echo "controller lock: not held" >&2; exit 1; }
    [ -f "$lock_dir/owner" ] || { echo "controller lock: missing owner metadata" >&2; exit 2; }
    owner=$(cat "$lock_dir/owner")
    [ "$owner" = "$controller" ] || { echo "controller lock: owner mismatch" >&2; exit 1; }
    rm -f "$lock_dir/owner" "$lock_dir/run-id" "$lock_dir/acquired-at"
    rmdir "$lock_dir"
    ;;
  status)
    if [ -d "$lock_dir" ]; then
      echo "held"
      [ -f "$lock_dir/owner" ] && sed 's/^/owner: /' "$lock_dir/owner"
      [ -f "$lock_dir/run-id" ] && sed 's/^/run-id: /' "$lock_dir/run-id"
      exit 0
    fi
    echo "free"
    ;;
esac
