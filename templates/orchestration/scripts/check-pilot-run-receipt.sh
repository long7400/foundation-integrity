#!/bin/sh
# Validate machine-bound identity plus content-digested pilot artifacts.
set -eu

contract=${1:-}
receipt=${2:-}
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
matrix=${3:-"$script_dir/../role-model-matrix.tsv"}
if [ -z "$contract" ] || [ ! -f "$contract" ] || [ -z "$receipt" ] || [ ! -f "$receipt" ] || [ ! -f "$matrix" ]; then
  echo "usage: $0 <run-contract.tsv> <pilot-run-receipt.md> [role-model-matrix.tsv]" >&2
  exit 2
fi

sh "$script_dir/check-run-contract.sh" "$contract" "$matrix" || exit 1

root=${FI_ARTIFACT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-receipt.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    echo "pilot receipt: no SHA-256 command available" >&2
    exit 2
  fi
}

contract_hash=$(hash_file "$contract")
matrix_hash=$(hash_file "$matrix")
current_state_path=$(awk -F '\t' '
  $1 == "setting" && $2 == "current_state_path" { count++; value = $3 }
  END { if (count != 1 || value == "") exit 1; print value }
' "$contract") || {
  echo "pilot receipt: contract needs exactly one current_state_path setting" >&2
  exit 1
}
runtime=$(awk -F '\t' '
  $1 == "setting" && $2 == "runtime" { count++; value = $3 }
  END { if (count != 1 || value == "") exit 1; print value }
' "$contract") || {
  echo "pilot receipt: contract needs exactly one runtime setting" >&2
  exit 1
}
write_isolation=$(awk -F '\t' '
  $1 == "actor" && $3 == "implementer" { found = 1 }
  END { print found ? "pass" : "not-applicable" }
' "$contract")

awk -v expected_contract_hash="$contract_hash" -v expected_matrix_hash="$matrix_hash" -v expected_state="$current_state_path" -v expected_runtime="$runtime" -v expected_write_isolation="$write_isolation" -v fields_out="$tmp/fields" '
function fail(msg) {
  print "pilot receipt: " msg > "/dev/stderr"
  bad = 1
}

/^<!-- foundation-integrity-coworker-pilot:v2$/ {
  blocks++
  inside = 1
  next
}

/^-->$/ {
  if (inside) {
    inside = 0
    closed++
  }
  next
}

inside {
  separator = index($0, ":")
  if (!separator) {
    fail("invalid field line " NR)
    next
  }
  key = substr($0, 1, separator - 1)
  value = substr($0, separator + 1)
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  if (key !~ /^(run-id|contract-sha256|role-model-matrix-sha256|runtime|current-state-path|current-state-revision|current-state-sha256|worker-artifact-path|worker-artifact-sha256|transcript-path|transcript-sha256|write-isolation|session-policy|baseline-artifact-path|baseline-artifact-sha256|pilot-artifact-path|pilot-artifact-sha256|incremental-value|coordination-cost|decision)$/) {
    fail("unknown field " key)
  }
  if (seen[key]++) fail("duplicate field " key)
  values[key] = value
  print key "\t" value > fields_out
  next
}

END {
  if (blocks != 1 || closed != 1 || inside) fail("expected exactly one closed v2 block")
  required[1] = "run-id"
  required[2] = "contract-sha256"
  required[3] = "role-model-matrix-sha256"
  required[4] = "runtime"
  required[5] = "current-state-path"
  required[6] = "current-state-revision"
  required[7] = "current-state-sha256"
  required[8] = "worker-artifact-path"
  required[9] = "worker-artifact-sha256"
  required[10] = "transcript-path"
  required[11] = "transcript-sha256"
  required[12] = "write-isolation"
  required[13] = "session-policy"
  required[14] = "baseline-artifact-path"
  required[15] = "pilot-artifact-path"
  required[16] = "baseline-artifact-sha256"
  required[17] = "pilot-artifact-sha256"
  required[18] = "incremental-value"
  required[19] = "coordination-cost"
  required[20] = "decision"
  for (i = 1; i <= 20; i++) {
    key = required[i]
    if (values[key] == "") fail("missing field " key)
  }
  if (length(values["contract-sha256"]) != 64 || values["contract-sha256"] ~ /[^0-9a-fA-F]/) fail("contract-sha256 must be 64 hex characters")
  if (length(values["role-model-matrix-sha256"]) != 64 || values["role-model-matrix-sha256"] ~ /[^0-9a-fA-F]/) fail("role-model-matrix-sha256 must be 64 hex characters")
  if (values["contract-sha256"] != expected_contract_hash) fail("contract-sha256 does not match the contract")
  if (values["role-model-matrix-sha256"] != expected_matrix_hash) fail("role-model-matrix-sha256 does not match the matrix")
  if (values["runtime"] != expected_runtime) fail("runtime does not match the contract")
  if (values["current-state-path"] != expected_state) fail("current-state-path does not match the contract")
  for (key in values) {
    if (key ~ /sha256$/ && (length(values[key]) != 64 || values[key] ~ /[^0-9a-fA-F]/)) fail(key " must be 64 hex characters")
  }
  if (values["write-isolation"] != expected_write_isolation) fail("write-isolation must be " expected_write_isolation " for this contract")
  if (values["session-policy"] != "fresh-only") fail("session-policy must be fresh-only")
  if (values["decision"] !~ /^(keep|amend|remove|inconclusive)$/) fail("invalid decision")
  exit bad
}
' "$receipt"

field() {
  awk -F '\t' -v key="$1" '$1 == key { count++; value = substr($0, index($0, "\t") + 1) } END { if (count != 1) exit 1; print value }' "$tmp/fields"
}

safe_repo_path() {
  case "$1" in
    ''|/*|*..*|./*|*/|*//*|*'['*|*']'*|*'?'*|*'*'*) return 1 ;;
  esac
  return 0
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "pilot receipt: no SHA-256 command available" >&2
    exit 2
  fi
}

check_artifact() {
  label=$1
  path=$2
  expected=$3
  safe_repo_path "$path" || { echo "pilot receipt: $label path is not canonical" >&2; exit 1; }
  case "$path" in
    .foundation/orchestration/*) ;;
    *) echo "pilot receipt: $label must remain under ignored .foundation/orchestration/: $path" >&2; exit 1 ;;
  esac
  [ -f "$root/$path" ] || { echo "pilot receipt: $label is missing: $path" >&2; exit 1; }
  actual=$(sha256_file "$root/$path")
  [ "$actual" = "$expected" ] || { echo "pilot receipt: $label digest mismatch" >&2; exit 1; }
}

current_state_sha=$(field current-state-sha256)
worker_artifact_path=$(field worker-artifact-path)
worker_artifact_sha=$(field worker-artifact-sha256)
transcript_path=$(field transcript-path)
transcript_sha=$(field transcript-sha256)
baseline_path=$(field baseline-artifact-path)
baseline_sha=$(field baseline-artifact-sha256)
pilot_path=$(field pilot-artifact-path)
pilot_sha=$(field pilot-artifact-sha256)
check_artifact "current-state" "$current_state_path" "$current_state_sha"
check_artifact "worker artifact" "$worker_artifact_path" "$worker_artifact_sha"
check_artifact "transcript" "$transcript_path" "$transcript_sha"
check_artifact "baseline artifact" "$baseline_path" "$baseline_sha"
check_artifact "pilot artifact" "$pilot_path" "$pilot_sha"
