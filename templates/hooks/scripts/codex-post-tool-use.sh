#!/usr/bin/env sh
# Codex project hook adapter. Codex supplies one JSON event on stdin.
# The underlying guard remains the canonical implementation; this adapter keeps
# advisory findings non-blocking and adds a concise model-visible context message.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp "${TMPDIR:-/tmp}/foundation-integrity-codex-hook.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM

if "$here/foundation-surface-guard.sh" 2>"$tmp"; then
  exit 0
fi

cat "$tmp" >&2
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Foundation Integrity found a foundation-surface change without a clearing receipt. Read the hook diagnostic and run foundation-audit before freezing the change."}}'
exit 0
