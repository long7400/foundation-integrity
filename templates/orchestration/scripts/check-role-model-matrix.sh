#!/bin/sh
# Verify the exact user-approved dual-runtime role/model policy.
set -eu

file=${1:-}
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "usage: $0 <role-model-matrix.tsv>" >&2
  exit 2
fi

awk -F '\t' '
BEGIN {
  expected["codex/fi-root-lead"] = "root-lead\tgpt-5.6-sol\txhigh\tworkspace-write\tfinal"
  expected["codex/fi-worker-medium"] = "worker-medium\tgpt-5.6-sol\tmedium\tread-only\tobservations"
  expected["codex/fi-implementer-medium"] = "implementer-medium\tgpt-5.6-sol\tmedium\tworkspace-write\tbounded"
  expected["codex/fi-peer-max"] = "peer-max\tgpt-5.6-luna\tmax\tread-only\tcorroborated"
  expected["codex/fi-implementer-max"] = "implementer-max\tgpt-5.6-luna\tmax\tworkspace-write\tbounded"
  expected["claude/fi-root-lead"] = "root-lead\tclaude-opus-4.8\tmax\tmanual\tfinal"
  expected["claude/fi-worker-medium"] = "worker-medium\tclaude-haiku-4.5\tmedium\tdontAsk\tobservations"
  expected["claude/fi-implementer-medium"] = "implementer-medium\tclaude-haiku-4.5\tmedium\tacceptEdits\tbounded"
  expected["claude/fi-peer-max"] = "peer-max\tclaude-opus-4.7\tmax\tdontAsk\tcorroborated"
  expected["claude/fi-implementer-max"] = "implementer-max\tclaude-opus-4.7\tmax\tacceptEdits\tbounded"
}

function fail(msg) {
  print "role/model matrix: " msg > "/dev/stderr"
  bad = 1
}

/^# foundation-integrity-role-model-policy:v1$/ { header++; next }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

{
  if (NF != 7) {
    fail("expected 7 tab-separated fields at line " NR)
    next
  }
  key = $1 "/" $2
  actual = $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7
  if (seen[key]++) fail("duplicate profile " key)
  if (!(key in expected)) fail("unexpected profile " key)
  else if (actual != expected[key]) fail("mapping mismatch for " key)
}

END {
  if (header != 1) fail("expected exactly one v1 header")
  for (key in expected) if (!seen[key]) fail("missing profile " key)
  exit bad
}
' "$file"
