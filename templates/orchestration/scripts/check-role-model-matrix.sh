#!/bin/sh
# Verify the exact user-approved dual-runtime role/model/work-class policy.
set -eu

file=${1:-}
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "usage: $0 <role-model-matrix.tsv>" >&2
  exit 2
fi

awk -F '\t' '
BEGIN {
  expected["codex/fi-root-lead"] = "root\tcontrol\tgpt-5.6-sol\txhigh\tworkspace-write\tfinal"
  expected["codex/fi-peer-scout"] = "peer\tscout\tgpt-5.6-luna\tmax\tread-only\tobservations"
  expected["codex/fi-peer-challenge"] = "peer\tchallenge\tgpt-5.6-sol\tmedium\tread-only\tcounterevidence"
  expected["codex/fi-implementer-mechanical"] = "implementer\tmechanical\tgpt-5.6-luna\tmax\tworkspace-write\tbounded"
  expected["codex/fi-implementer-ambiguous"] = "implementer\tambiguous\tgpt-5.6-sol\tmedium\tworkspace-write\tbounded"
  expected["claude/fi-root-lead"] = "root\tcontrol\tclaude-opus-4.8\tmax\tmanual\tfinal"
  expected["claude/fi-peer-scout"] = "peer\tscout\tclaude-haiku-4.5\tmedium\tdontAsk\tobservations"
  expected["claude/fi-peer-challenge"] = "peer\tchallenge\tclaude-opus-4.7\tmax\tdontAsk\tcounterevidence"
  expected["claude/fi-implementer-mechanical"] = "implementer\tmechanical\tclaude-haiku-4.5\tmedium\tacceptEdits\tbounded"
  expected["claude/fi-implementer-ambiguous"] = "implementer\tambiguous\tclaude-opus-4.7\tmax\tacceptEdits\tbounded"
}

function fail(msg) {
  print "role/model matrix: " msg > "/dev/stderr"
  bad = 1
}

/^# foundation-integrity-role-model-policy:v2$/ { header++; next }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

{
  if (NF != 8) {
    fail("expected 8 tab-separated fields at line " NR)
    next
  }
  key = $1 "/" $2
  actual = $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8
  if (seen[key]++) fail("duplicate profile " key)
  if (!(key in expected)) fail("unexpected profile " key)
  else if (actual != expected[key]) fail("mapping mismatch for " key)
}

END {
  if (header != 1) fail("expected exactly one v2 header")
  for (key in expected) if (!seen[key]) fail("missing profile " key)
  exit bad
}
' "$file"
