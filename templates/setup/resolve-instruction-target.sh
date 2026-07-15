#!/bin/sh
# Resolve the canonical repo instruction target for setup-foundation-integrity.
# Output: AGENTS.md, CLAUDE.md, AMBIGUOUS, or NONE.
# Exit:   0 for a resolved file; 2 for ambiguous; 3 for neither file.
#
# This helper deliberately recognizes only high-confidence mechanical cases.
# Anything richer belongs to human/agent inspection, not clever parsing.
set -eu

root=${1:-.}
agents=$root/AGENTS.md
claude=$root/CLAUDE.md

claude_is_agents_shim() {
  awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*# CLAUDE\.md[[:space:]]*$/ { next }
    /^[[:space:]]*@(\.\/)?AGENTS\.md[[:space:]]*$/ { imports++; next }
    { substantive = 1 }
    END { exit !(imports == 1 && !substantive) }
  ' "$claude" 2>/dev/null
}

if [ -f "$agents" ] && [ ! -f "$claude" ]; then
  printf '%s\n' AGENTS.md
  exit 0
fi

if [ -f "$claude" ] && [ ! -f "$agents" ]; then
  printf '%s\n' CLAUDE.md
  exit 0
fi

if [ ! -f "$agents" ] && [ ! -f "$claude" ]; then
  printf '%s\n' NONE
  exit 3
fi

if claude_is_agents_shim; then
  printf '%s\n' AGENTS.md
  exit 0
fi

# Two non-forwarding files are an ownership question, even when only one currently
# contains the block. Existing content is evidence, not authority proof.
printf '%s\n' AMBIGUOUS
exit 2
