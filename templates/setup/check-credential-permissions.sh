#!/bin/sh
# Fail when a credential-bearing settings file is readable or writable by group/other.
# Values are never printed. Pass explicit paths; default is Claude's user settings.
set -eu

if [ "$#" -eq 0 ]; then
  set -- "$HOME/.claude/settings.json"
fi

mode_of() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

owner_of() {
  stat -f '%u' "$1" 2>/dev/null || stat -c '%u' "$1" 2>/dev/null
}

status=0
for file in "$@"; do
  if [ ! -f "$file" ]; then
    echo "credential permissions: missing file: $file" >&2
    status=1
    continue
  fi
  mode=$(mode_of "$file" || true)
  owner=$(owner_of "$file" || true)
  if [ -z "$mode" ] || [ -z "$owner" ]; then
    echo "credential permissions: cannot inspect metadata: $file" >&2
    status=1
    continue
  fi
  case "$mode" in
    600|0600|400|0400) ;;
    *) echo "credential permissions: $file must be owner-only (0600 recommended); found $mode" >&2; status=1 ;;
  esac
  if [ "$owner" != "$(id -u)" ]; then
    echo "credential permissions: $file is not owned by the current user" >&2
    status=1
  fi
done

exit "$status"
