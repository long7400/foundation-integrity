#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-tests.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_target() {
  expected=$1
  dir=$2
  set +e
  out=$(sh "$root/templates/setup/resolve-instruction-target.sh" "$dir" 2>&1)
  rc=$?
  set -e
  [ "$out" = "$expected" ] || fail "target for $dir: expected $expected, got $out"
  case "$expected" in
    AMBIGUOUS) [ "$rc" -eq 2 ] || fail "AMBIGUOUS should exit 2" ;;
    NONE) [ "$rc" -eq 3 ] || fail "NONE should exit 3" ;;
    *) [ "$rc" -eq 0 ] || fail "$expected should exit 0" ;;
  esac
}

mkdir -p \
  "$tmp/only-agents" \
  "$tmp/only-claude" \
  "$tmp/shim" \
  "$tmp/substantive-shim" \
  "$tmp/agents-owner" \
  "$tmp/claude-owner" \
  "$tmp/ambiguous" \
  "$tmp/duplicate-shim" \
  "$tmp/none"

printf '# Rules\n' > "$tmp/only-agents/AGENTS.md"
printf '# Rules\n' > "$tmp/only-claude/CLAUDE.md"
printf '## Personal Operating Rules\n' > "$tmp/shim/AGENTS.md"
printf '# CLAUDE.md\n\n@AGENTS.md\n' > "$tmp/shim/CLAUDE.md"
printf '## Personal Operating Rules\n' > "$tmp/substantive-shim/AGENTS.md"
printf '# CLAUDE.md\n\n@AGENTS.md\n\nAlways use the local release checklist.\n' \
  > "$tmp/substantive-shim/CLAUDE.md"
printf '## Foundation Integrity\n' > "$tmp/agents-owner/AGENTS.md"
printf '# Claude notes\n' > "$tmp/agents-owner/CLAUDE.md"
printf '# Agent notes\n' > "$tmp/claude-owner/AGENTS.md"
printf '## Foundation Integrity\n' > "$tmp/claude-owner/CLAUDE.md"
printf '# Agent notes\n' > "$tmp/ambiguous/AGENTS.md"
printf '# Claude notes\n' > "$tmp/ambiguous/CLAUDE.md"
printf '## Foundation Integrity\n' > "$tmp/duplicate-shim/AGENTS.md"
printf '## Foundation Integrity\n\n@AGENTS.md\n' > "$tmp/duplicate-shim/CLAUDE.md"

expect_target AGENTS.md "$tmp/only-agents"
expect_target CLAUDE.md "$tmp/only-claude"
expect_target AGENTS.md "$tmp/shim"
expect_target AMBIGUOUS "$tmp/substantive-shim"
expect_target AMBIGUOUS "$tmp/agents-owner"
expect_target AMBIGUOUS "$tmp/claude-owner"
expect_target AMBIGUOUS "$tmp/ambiguous"
expect_target AMBIGUOUS "$tmp/duplicate-shim"
expect_target NONE "$tmp/none"
expect_target AGENTS.md "$root"

python3 - "$root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
skills = sorted(p.name for p in (root / "skills").iterdir() if p.is_dir())
manifest = json.loads((root / ".claude-plugin/plugin.json").read_text())
registered = sorted(pathlib.PurePosixPath(p).name for p in manifest["skills"])
if skills != registered:
    raise SystemExit(f"manifest skill mismatch: dirs={skills} registered={registered}")
marketplace = json.loads((root / ".claude-plugin/marketplace.json").read_text())
entries = [p for p in marketplace.get("plugins", []) if p.get("name") == manifest.get("name")]
if len(entries) != 1 or entries[0].get("source") != "./":
    raise SystemExit("marketplace must expose exactly one local entry for the plugin manifest")
for name in skills:
    skill = root / "skills" / name / "SKILL.md"
    interface = root / "skills" / name / "agents/openai.yaml"
    if not skill.is_file() or not interface.is_file():
        raise SystemExit(f"missing dual-runtime pair for {name}")
    declared = next(
        (line.split(":", 1)[1].strip() for line in skill.read_text().splitlines() if line.startswith("name:")),
        None,
    )
    if declared != name:
        raise SystemExit(f"skill name mismatch for {name}: {declared}")
PY

sh "$root/templates/orchestration/scripts/check-role-model-matrix.sh" \
  "$root/templates/orchestration/role-model-matrix.tsv" \
  || fail "valid role/model matrix rejected"

python3 - "$root" <<'PY'
import pathlib
import re
import shlex
import sys

root = pathlib.Path(sys.argv[1])
orchestration = root / "templates/orchestration"
rows = []
for line in (orchestration / "role-model-matrix.tsv").read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    fields = line.split("\t")
    if len(fields) != 7:
        raise SystemExit(f"invalid matrix row: {line!r}")
    rows.append(fields)

if len(rows) != 10:
    raise SystemExit(f"expected 10 canonical profiles, found {len(rows)}")

for runtime, profile, role, model, effort, access, _claim in rows:
    if runtime == "codex":
        path = orchestration / "profiles/codex" / f"{profile}.config.toml"
        if not path.is_file():
            raise SystemExit(f"missing Codex profile template: {path}")
        profile_text = path.read_text()

        def scalar(key):
            match = re.search(rf'^{re.escape(key)}\s*=\s*"([^"]*)"\s*$', profile_text, re.MULTILINE)
            return match.group(1) if match else None

        expected_approval = "never" if access == "read-only" else "on-request"
        expected = {
            "model": model,
            "model_reasoning_effort": effort,
            "sandbox_mode": access,
            "approval_policy": expected_approval,
        }
        for key, value in expected.items():
            actual = scalar(key)
            if actual != value:
                raise SystemExit(f"{path}: expected {key}={value!r}, got {actual!r}")
        if not re.search(r'^\[features\]\s*$', profile_text, re.MULTILINE):
            raise SystemExit(f"{path}: missing features table")
        if not re.search(r'^multi_agent\s*=\s*false\s*$', profile_text, re.MULTILINE):
            raise SystemExit(f"{path}: native multi-agent features must be false")
        if re.search(r'^\[+skills(?:\.|\])', profile_text, re.MULTILINE):
            raise SystemExit(f"{path}: profile must not configure a transport skill")
        prompt_match = re.search(r'developer_instructions\s*=\s*"""(.*?)"""', profile_text, re.DOTALL)
        prompt = prompt_match.group(1).lower() if prompt_match else ""
        if role == "root-lead":
            if "herdr" not in prompt:
                raise SystemExit(f"{path}: root profile must contain the explicit controller adapter")
        else:
            for forbidden in ("herdr", "terminal multiplexer", "session backend", "session topology", "external session", "department topology"):
                if forbidden in prompt:
                    raise SystemExit(f"{path}: non-root prompt leaks transport/topology term {forbidden!r}")
    else:
        role_file = orchestration / "profiles/claude" / f"{role}.md"
        if not role_file.is_file():
            raise SystemExit(f"missing Claude role prompt: {role_file}")
        prompt = role_file.read_text().lower()
        if role == "root-lead":
            if "herdr" not in prompt:
                raise SystemExit(f"{role_file}: root prompt must contain the explicit controller adapter")
        else:
            for forbidden in ("herdr", "terminal multiplexer", "session backend", "session topology", "external session", "department topology"):
                if forbidden in prompt:
                    raise SystemExit(f"{role_file}: non-root prompt leaks transport/topology term {forbidden!r}")

shared = (orchestration / "shared-coworker-instructions.md").read_text().lower()
for forbidden in ("herdr", "terminal multiplexer", "session backend", "session topology", "department topology"):
    if forbidden in shared:
        raise SystemExit(f"shared coworker instructions leak transport/topology term {forbidden!r}")

commands = {}
for line in (orchestration / "profiles/claude/launch-commands.md").read_text().splitlines():
    if not line.startswith("claude "):
        continue
    argv = shlex.split(line)
    if "--name" not in argv:
        raise SystemExit(f"Claude launch command lacks --name: {line}")
    commands[argv[argv.index("--name") + 1]] = argv

claude_rows = [row for row in rows if row[0] == "claude"]
if set(commands) != {row[1] for row in claude_rows}:
    raise SystemExit(f"Claude launch command/profile mismatch: {sorted(commands)}")

def flag_value(argv, flag):
    try:
        return argv[argv.index(flag) + 1]
    except (ValueError, IndexError):
        raise SystemExit(f"missing {flag} in {' '.join(argv)}")

for _runtime, profile, role, model, effort, access, _claim in claude_rows:
    argv = commands[profile]
    if flag_value(argv, "--model") != model or flag_value(argv, "--effort") != effort:
        raise SystemExit(f"{profile}: model/effort drift")
    if flag_value(argv, "--permission-mode") != access:
        raise SystemExit(f"{profile}: permission-mode drift")
    if flag_value(argv, "--setting-sources") != "project,local":
        raise SystemExit(f"{profile}: settings sources must be project,local")
    if flag_value(argv, "--settings") != "$HOME/.claude/settings.json":
        raise SystemExit(f"{profile}: must load the canonical user settings directly")
    if "--strict-mcp-config" not in argv or "--session-id" not in argv:
        raise SystemExit(f"{profile}: strict MCP and fresh session identity are required")
    denied = flag_value(argv, "--disallowedTools")
    for tool in ("Agent", "Task", "SendMessage"):
        if tool not in denied.split(","):
            raise SystemExit(f"{profile}: native coordination tool {tool} is not denied")
    prompt_path = flag_value(argv, "--append-system-prompt-file")
    if not prompt_path.endswith(f"/{role}.md"):
        raise SystemExit(f"{profile}: wrong role prompt {prompt_path}")
    if role in {"worker-medium", "peer-max"}:
        allowed = set(flag_value(argv, "--tools").split(","))
        if allowed - {"Read", "Glob", "Grep", "WebSearch", "WebFetch"}:
            raise SystemExit(f"{profile}: read-only allowlist contains write/exec tools")

for forbidden in ("--agent", "--agents", "--background", "--bg"):
    if any(forbidden in argv for argv in commands.values()):
        raise SystemExit(f"Claude launch commands must not use {forbidden}")
PY

for script in \
  "$root"/templates/hooks/scripts/*.sh \
  "$root"/templates/hooks/git/pre-commit \
  "$root"/templates/hooks/git/pre-push \
  "$root"/templates/setup/*.sh \
  "$root"/templates/orchestration/scripts/*.sh
do
  sh -n "$script" || fail "shell syntax: $script"
done

sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$root/templates/orchestration/run-contract.tsv" \
  || fail "valid orchestration contract rejected"

awk -F '\t' 'BEGIN { OFS = FS } $1 == "setting" && $2 == "runtime" { $3 = "claude" } { print }' \
  "$root/templates/orchestration/run-contract.tsv" > "$tmp/valid-claude-contract.tsv"
sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/valid-claude-contract.tsv" \
  || fail "valid Claude orchestration contract rejected"

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/bad-contract.tsv"
printf 'actor\troot-2\troot\tcontrol\t-\t.foundation/orchestration/root-2.md\n' \
  >> "$tmp/bad-contract.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/bad-contract.tsv" >/dev/null 2>&1
then
  fail "duplicate root contract should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/duplicate-setting.tsv"
printf 'setting\tnative_subagents\tdisabled\n' >> "$tmp/duplicate-setting.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/duplicate-setting.tsv" >/dev/null 2>&1
then
  fail "duplicate setting contract should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/unscoped-implementer.tsv"
printf 'actor\timpl\timplementer\timplementation\t-\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/unscoped-implementer.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/unscoped-implementer.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/unscoped-implementer.tsv" >/dev/null 2>&1
then
  fail "implementer without write scope should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/valid-implementer.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:src/feature\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/valid-implementer.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/valid-implementer.tsv"
sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/valid-implementer.tsv" \
  || fail "bounded implementer scope should pass"

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/unbounded-implementer.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:.\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/unbounded-implementer.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/unbounded-implementer.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/unbounded-implementer.tsv" >/dev/null 2>&1
then
  fail "root-wide implementer scope should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/noncanonical-implementer.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:src/./feature\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/noncanonical-implementer.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/noncanonical-implementer.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/noncanonical-implementer.tsv" >/dev/null 2>&1
then
  fail "noncanonical implementer scope should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/overlapping-implementers.tsv"
printf 'actor\timpl-a\timplementer\timplementation-a\tpath:src\t.foundation/orchestration/impl-a.md\n' \
  >> "$tmp/overlapping-implementers.tsv"
printf 'profile\timpl-a\tfi-implementer-medium\n' >> "$tmp/overlapping-implementers.tsv"
printf 'actor\timpl-b\timplementer\timplementation-b\tpath:src/domain\t.foundation/orchestration/impl-b.md\n' \
  >> "$tmp/overlapping-implementers.tsv"
printf 'profile\timpl-b\tfi-implementer-max\n' >> "$tmp/overlapping-implementers.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/overlapping-implementers.tsv" >/dev/null 2>&1
then
  fail "overlapping implementer scopes should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/root-state-overlap.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:.foundation/orchestration\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/root-state-overlap.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/root-state-overlap.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/root-state-overlap.tsv" >/dev/null 2>&1
then
  fail "implementer scope overlapping root current state should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/worker-artifact-overlap.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:.foundation/orchestration/impl\t.foundation/orchestration/impl/report.md\n' \
  >> "$tmp/worker-artifact-overlap.tsv"
printf 'profile\timpl\tfi-implementer-medium\n' >> "$tmp/worker-artifact-overlap.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/worker-artifact-overlap.tsv" >/dev/null 2>&1
then
  fail "implementer scope overlapping its canonical artifact should fail"
fi

awk -F '\t' 'BEGIN { OFS = FS } $1 == "setting" && $2 == "current_state_path" { $3 = ".foundation/orchestration/other.md" } { print }' \
  "$root/templates/orchestration/run-contract.tsv" > "$tmp/mismatched-current-state.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/mismatched-current-state.tsv" >/dev/null 2>&1
then
  fail "mismatched current-state path should fail"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/wrong-role-profile.tsv"
printf 'actor\timpl\timplementer\timplementation\tpath:src/feature\t.foundation/orchestration/impl.md\n' \
  >> "$tmp/wrong-role-profile.tsv"
printf 'profile\timpl\tfi-worker-medium\n' >> "$tmp/wrong-role-profile.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/wrong-role-profile.tsv" >/dev/null 2>&1
then
  fail "implementer bound to worker profile should fail"
fi

awk -F '\t' 'BEGIN { OFS = FS } $1 == "lock" { $3 = "worker-a" } { print }' \
  "$root/templates/orchestration/run-contract.tsv" > "$tmp/worker-lock-owner.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/worker-lock-owner.tsv" >/dev/null 2>&1
then
  fail "canonical validation lock must remain root-owned"
fi

cp "$root/templates/orchestration/run-contract.tsv" "$tmp/monitor-role.tsv"
printf 'actor\tmonitor-a\tmonitor\tattention-polling\t-\t.foundation/orchestration/monitor-a.md\n' \
  >> "$tmp/monitor-role.tsv"
printf 'profile\tmonitor-a\tfi-worker-medium\n' >> "$tmp/monitor-role.tsv"
if sh "$root/templates/orchestration/scripts/check-run-contract.sh" \
  "$tmp/monitor-role.tsv" >/dev/null 2>&1
then
  fail "monitor must not be a coworker role"
fi

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    sha256sum "$1" | awk '{ print $1 }'
  fi
}

contract_hash=$(hash_file "$root/templates/orchestration/run-contract.tsv")
matrix_hash=$(hash_file "$root/templates/orchestration/role-model-matrix.tsv")
current_state_path=$(awk -F '\t' '$1 == "setting" && $2 == "current_state_path" { print $3 }' \
  "$root/templates/orchestration/run-contract.tsv")
runtime=$(awk -F '\t' '$1 == "setting" && $2 == "runtime" { print $3 }' \
  "$root/templates/orchestration/run-contract.tsv")

mkdir -p "$tmp/artifacts/.foundation/orchestration" "$tmp/artifacts/evidence"
printf 'root current state\n' > "$tmp/artifacts/$current_state_path"
printf 'worker output\n' > "$tmp/artifacts/evidence/worker.md"
printf 'transport transcript\n' > "$tmp/artifacts/evidence/transcript.txt"
printf 'baseline result\n' > "$tmp/artifacts/evidence/baseline.md"
printf 'pilot result\n' > "$tmp/artifacts/evidence/pilot.md"
current_state_hash=$(hash_file "$tmp/artifacts/$current_state_path")
worker_hash=$(hash_file "$tmp/artifacts/evidence/worker.md")
transcript_hash=$(hash_file "$tmp/artifacts/evidence/transcript.txt")
baseline_hash=$(hash_file "$tmp/artifacts/evidence/baseline.md")
pilot_hash=$(hash_file "$tmp/artifacts/evidence/pilot.md")
printf '<!-- foundation-integrity-coworker-pilot:v2\nrun-id: test-run\ncontract-sha256: %s\nrole-model-matrix-sha256: %s\nruntime: %s\ncurrent-state-path: %s\ncurrent-state-revision: test-revision\ncurrent-state-sha256: %s\nworker-artifact-path: evidence/worker.md\nworker-artifact-sha256: %s\ntranscript-path: evidence/transcript.txt\ntranscript-sha256: %s\nwrite-isolation: pass\nsession-policy: fresh-only\nbaseline-artifact-path: evidence/baseline.md\nbaseline-artifact-sha256: %s\npilot-artifact-path: evidence/pilot.md\npilot-artifact-sha256: %s\nincremental-value: material-counterevidence\ncoordination-cost: 4-turns\ndecision: keep\n-->\n' \
  "$contract_hash" "$matrix_hash" "$runtime" "$current_state_path" "$current_state_hash" \
  "$worker_hash" "$transcript_hash" "$baseline_hash" "$pilot_hash" > "$tmp/valid-pilot-receipt.md"
FI_ARTIFACT_ROOT="$tmp/artifacts" sh "$root/templates/orchestration/scripts/check-pilot-run-receipt.sh" \
  "$root/templates/orchestration/run-contract.tsv" "$tmp/valid-pilot-receipt.md" \
  "$root/templates/orchestration/role-model-matrix.tsv" \
  || fail "valid pilot receipt rejected"

awk '$1 == "current-state-path:" { print "current-state-path: .foundation/orchestration/other.md"; next } { print }' \
  "$tmp/valid-pilot-receipt.md" > "$tmp/mismatched-pilot-receipt.md"
if FI_ARTIFACT_ROOT="$tmp/artifacts" sh "$root/templates/orchestration/scripts/check-pilot-run-receipt.sh" \
  "$root/templates/orchestration/run-contract.tsv" "$tmp/mismatched-pilot-receipt.md" \
  "$root/templates/orchestration/role-model-matrix.tsv" >/dev/null 2>&1
then
  fail "pilot receipt with mismatched current-state path should fail"
fi

awk '$1 == "worker-artifact-sha256:" { print "worker-artifact-sha256: 0000000000000000000000000000000000000000000000000000000000000000"; next } { print }' \
  "$tmp/valid-pilot-receipt.md" > "$tmp/bad-artifact-digest.md"
if FI_ARTIFACT_ROOT="$tmp/artifacts" sh "$root/templates/orchestration/scripts/check-pilot-run-receipt.sh" \
  "$root/templates/orchestration/run-contract.tsv" "$tmp/bad-artifact-digest.md" \
  "$root/templates/orchestration/role-model-matrix.tsv" >/dev/null 2>&1
then
  fail "pilot receipt with mismatched artifact digest should fail"
fi

lock_dir="$tmp/controller.lock"
FI_CONTROLLER_LOCK_DIR="$lock_dir" FI_CONTROLLER_ID=test-root FI_RUN_ID=test-run \
  sh "$root/templates/orchestration/scripts/controller-lock.sh" acquire >/dev/null \
  || fail "controller lock acquire failed"
if FI_CONTROLLER_LOCK_DIR="$lock_dir" FI_CONTROLLER_ID=other-root \
  sh "$root/templates/orchestration/scripts/controller-lock.sh" acquire >/dev/null 2>&1
then
  fail "second controller should not acquire the lock"
fi
if FI_CONTROLLER_LOCK_DIR="$lock_dir" FI_CONTROLLER_ID=other-root \
  sh "$root/templates/orchestration/scripts/controller-lock.sh" release >/dev/null 2>&1
then
  fail "non-owner should not release the controller lock"
fi
FI_CONTROLLER_LOCK_DIR="$lock_dir" FI_CONTROLLER_ID=test-root \
  sh "$root/templates/orchestration/scripts/controller-lock.sh" release \
  || fail "controller lock release failed"

printf '{}\n' > "$tmp/credentials.json"
chmod 600 "$tmp/credentials.json"
sh "$root/templates/setup/check-credential-permissions.sh" "$tmp/credentials.json" \
  || fail "owner-only credential settings should pass"
chmod 644 "$tmp/credentials.json"
if sh "$root/templates/setup/check-credential-permissions.sh" "$tmp/credentials.json" >/dev/null 2>&1
then
  fail "group-readable credential settings should fail"
fi

guard_repo="$tmp/guard-repo"
mkdir -p "$guard_repo/templates/hooks/scripts" "$guard_repo/templates/hooks" "$guard_repo/.foundation/receipts" "$guard_repo/src"
cp "$root/templates/hooks/scripts/foundation-surface-guard.sh" "$guard_repo/templates/hooks/scripts/"
printf 'src/**\n' > "$guard_repo/templates/hooks/foundation-surface.txt"
printf 'base\n' > "$guard_repo/src/base.txt"
git -C "$guard_repo" init -q
git -C "$guard_repo" config user.email test@example.invalid
git -C "$guard_repo" config user.name test
git -C "$guard_repo" add .
git -C "$guard_repo" commit -qm base
printf 'changed\n' > "$guard_repo/src/base.txt"
guard_revision=$(git -C "$guard_repo" rev-parse HEAD)
guard_oid=$(git -C "$guard_repo" hash-object "$guard_repo/src/base.txt")
guard_digest=$(printf 'src/base.txt\t%s\n' "$guard_oid" | shasum -a 256 | awk '{print $1}')
printf '<!-- foundation-integrity-receipt:v2\nclassification: FOUNDATION_OK\nroute: Feature-first\nreviewer: human:test\nverdict: upholds\noutcome: PROCEED\nrevision: %s\nchange-digest: %s\nevidence-ref: commit:%s\ncanonical-invariant: source remains authoritative.\nsurface-path: src/base.txt\n-->\n' \
  "$guard_revision" "$guard_digest" "$guard_revision" > "$guard_repo/.foundation/receipts/ok.md"
(cd "$guard_repo" && FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) \
  || fail "valid v2 receipt should clear the surface guard"

git -C "$guard_repo" add .
git -C "$guard_repo" commit -qm guarded-base
range_base=$(git -C "$guard_repo" rev-parse HEAD)
printf 'changed-again\n' > "$guard_repo/src/base.txt"
range_oid=$(git -C "$guard_repo" hash-object "$guard_repo/src/base.txt")
range_digest=$(printf 'src/base.txt\t%s\n' "$range_oid" | shasum -a 256 | awk '{print $1}')
printf '<!-- foundation-integrity-receipt:v2\nclassification: FOUNDATION_OK\nroute: Feature-first\nreviewer: human:test\nverdict: upholds\noutcome: PROCEED\nrevision: %s\nchange-digest: %s\nevidence-ref: commit:%s\ncanonical-invariant: source remains authoritative.\nsurface-path: src/base.txt\n-->\n' \
  "$range_base" "$range_digest" "$range_base" > "$guard_repo/.foundation/receipts/ok.md"
git -C "$guard_repo" add .
git -C "$guard_repo" commit -qm guarded-change
range_head=$(git -C "$guard_repo" rev-parse HEAD)
(cd "$guard_repo" && FI_RANGE="$range_base..$range_head" FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) \
  || fail "valid range-bound v2 receipt should clear the surface guard"

bad_guard_tmp="$tmp/unavailable-tmp"
printf 'not-a-directory\n' > "$bad_guard_tmp"
if (cd "$guard_repo" && TMPDIR="$bad_guard_tmp" FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) >/dev/null 2>&1
then
  fail "blocking surface guard must fail closed when temporary storage is unavailable"
fi

echo "repo contracts: PASS"
