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

sync_guard="$tmp/sync-guard"
mkdir -p "$sync_guard/scripts" "$sync_guard/.claude/skills" "$sync_guard/.agents/skills"
cp "$root/scripts/sync-runtime-skills.sh" "$sync_guard/scripts/"
: > "$sync_guard/.claude/skills/last-known-good"
: > "$sync_guard/.agents/skills/last-known-good"
if sh "$sync_guard/scripts/sync-runtime-skills.sh" >/dev/null 2>&1
then
  fail "runtime projection sync should reject a missing canonical source"
fi
[ -f "$sync_guard/.claude/skills/last-known-good" ] \
  || fail "failed sync erased the Claude last-known-good projection"
[ -f "$sync_guard/.agents/skills/last-known-good" ] \
  || fail "failed sync erased the Codex last-known-good projection"

python3 - "$root" <<'PY'
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
canonical_root = root / "skills"
skill_dirs = sorted(p.parent.relative_to(root).as_posix() for p in canonical_root.rglob("SKILL.md"))
manifest = json.loads((root / ".claude-plugin/plugin.json").read_text())
registered = sorted(pathlib.PurePosixPath(p).as_posix().removeprefix("./") for p in manifest["skills"])
if skill_dirs != registered:
    raise SystemExit(f"manifest skill mismatch: dirs={skill_dirs} registered={registered}")
marketplace = json.loads((root / ".claude-plugin/marketplace.json").read_text())
entries = [p for p in marketplace.get("plugins", []) if p.get("name") == manifest.get("name")]
if len(entries) != 1 or entries[0].get("source") != "./":
    raise SystemExit("marketplace must expose exactly one local entry for the plugin manifest")
for relative in skill_dirs:
    skill = root / relative / "SKILL.md"
    interface = root / relative / "agents/openai.yaml"
    if not skill.is_file() or not interface.is_file():
        raise SystemExit(f"missing canonical Codex interface pair for {relative}")
    declared = next(
        (line.split(":", 1)[1].strip() for line in skill.read_text().splitlines() if line.startswith("name:")),
        None,
    )
    if not declared:
        raise SystemExit(f"skill missing name for {relative}")

codex_manifest = json.loads((root / ".codex-plugin/plugin.json").read_text())
if codex_manifest.get("skills") != "./skills/":
    raise SystemExit("Codex manifest must recursively expose the canonical plugin skills root")
if codex_manifest.get("name") != manifest.get("name") or codex_manifest.get("version") != manifest.get("version"):
    raise SystemExit("Claude/Codex plugin identity or version drift")

upstream = json.loads((root / "third_party/mattpocock-skills/upstream-plugin.json").read_text())
promoted = sorted(
    "skills/_third_party/mattpocock/" + p.removeprefix("./skills/")
    for p in upstream["skills"]
    if not p.endswith("/setup-matt-pocock-skills")
)
vendored = sorted(
    p.parent.relative_to(root).as_posix()
    for p in (root / "skills/_third_party/mattpocock").rglob("SKILL.md")
)
if promoted != vendored:
    raise SystemExit(f"vendored Matt allowlist mismatch: expected={promoted} actual={vendored}")
for forbidden in ("deprecated", "in-progress", "misc", "personal", "setup-matt-pocock-skills"):
    if (root / "skills/_third_party/mattpocock" / forbidden).exists():
        raise SystemExit(f"excluded Matt bucket/skill leaked into snapshot: {forbidden}")
if not (root / "third_party/mattpocock-skills/LICENSE").is_file():
    raise SystemExit("vendored Matt LICENSE is missing")
if "MIT License" not in (root / "third_party/mattpocock-skills/LICENSE").read_text():
    raise SystemExit("vendored Matt LICENSE does not contain the upstream notice")

first_party = sorted(p for p in skill_dirs if not p.startswith("skills/_third_party/"))
expected_first_party = sorted(
    [
        "skills/foundation-audit",
        "skills/adversarial-foundation-review",
        "skills/foundation-health",
    ]
)
if first_party != expected_first_party:
    raise SystemExit(f"first-party core skill set drifted: {first_party}")
if len(skill_dirs) != 24:
    raise SystemExit(f"expected 24 skills (3 first-party + 21 companion), found {len(skill_dirs)}")

for runtime_root, require_openai in ((root / ".claude/skills", False), (root / ".agents/skills", True)):
    runtime_skills = sorted(p.parent.relative_to(runtime_root).as_posix() for p in runtime_root.rglob("SKILL.md"))
    canonical_skills = sorted(p.removeprefix("skills/") for p in skill_dirs)
    if runtime_skills != canonical_skills:
        raise SystemExit(f"runtime projection drift at {runtime_root}: {runtime_skills}")
    canonical_files = {
        p.relative_to(canonical_root).as_posix(): p
        for p in canonical_root.rglob("*")
        if p.is_file()
    }
    if not require_openai:
        canonical_files = {
            relative: path
            for relative, path in canonical_files.items()
            if not relative.endswith("/agents/openai.yaml")
        }
    runtime_files = {
        p.relative_to(runtime_root).as_posix(): p
        for p in runtime_root.rglob("*")
        if p.is_file()
    }
    if set(runtime_files) != set(canonical_files):
        missing = sorted(set(canonical_files) - set(runtime_files))
        extra = sorted(set(runtime_files) - set(canonical_files))
        raise SystemExit(
            f"runtime projection file drift at {runtime_root}: missing={missing} extra={extra}"
        )
    for relative, canonical in canonical_files.items():
        if canonical.read_bytes() != runtime_files[relative].read_bytes():
            raise SystemExit(f"runtime projection content drift: {runtime_files[relative]}")
    for relative in canonical_skills:
        projected = runtime_root / relative
        openai = projected / "agents/openai.yaml"
        if require_openai and not openai.is_file():
            raise SystemExit(f"Codex projection missing openai.yaml: {openai}")
        if not require_openai and openai.exists():
            raise SystemExit(f"Claude projection leaked Codex metadata: {openai}")

ignore_template = root / "templates/gitignore/foundation-integrity.gitignore"
template_text = ignore_template.read_text()
if "# BEGIN foundation-integrity generated state" not in template_text or "# END foundation-integrity generated state" not in template_text:
    raise SystemExit("generated-state ignore template is missing stable markers")
active_ignores = {
    line.strip()
    for line in template_text.splitlines()
    if line.strip() and not line.lstrip().startswith("#")
}
if not {".foundation/", "docs/research/", "tmp/"}.issubset(active_ignores):
    raise SystemExit("generated-state ignore template must exclude .foundation, docs/research, and tmp content")
root_ignores = (root / ".gitignore").read_text()
for required in (".foundation/", "docs/research/*", "!docs/research/.gitkeep", "tmp/"):
    if required not in root_ignores:
        raise SystemExit(f"root .gitignore missing {required}")
for canonical in (
    "docs/foundation/receipts/",
    "docs/adr/",
    "docs/agents/",
    "CONTEXT.md",
    ".scratch/",
):
    if canonical in active_ignores:
        raise SystemExit(f"canonical evidence/config path must remain trackable: {canonical}")
research_keep = root / "docs/research/.gitkeep"
if not research_keep.is_file():
    raise SystemExit("docs/research must contain its source-repo .gitkeep")
for local_note in (root / "docs/research").rglob("*"):
    if local_note.is_file() and local_note != research_keep:
        ignored = subprocess.run(
            ["git", "check-ignore", "-q", str(local_note)],
            cwd=root,
            check=False,
        )
        if ignored.returncode != 0:
            raise SystemExit(f"research working note is not ignored: {local_note}")
for required_doc in (
    "docs/agents/foundation.md",
    "docs/agents/issue-tracker.md",
    "docs/agents/domain.md",
    "docs/agents/triage-labels.md",
    "docs/install/claude.md",
    "docs/install/codex.md",
):
    if not (root / required_doc).is_file():
        raise SystemExit(f"preconfigured companion document is missing: {required_doc}")

runtime_hook_forbidden = {
    root / "templates/hooks/claude-settings.json": '"command": "FI_BLOCK=1',
    root / "templates/hooks/codex-config.toml": "command = \"sh -c 'FI_BLOCK=1",
}
for runtime_hook, forbidden in runtime_hook_forbidden.items():
    if forbidden in runtime_hook.read_text():
        raise SystemExit(f"runtime hook sample must remain warn-by-default: {runtime_hook}")
pre_push = (root / "templates/hooks/git/pre-push").read_text()
if "export FI_BLOCK=1" not in pre_push:
    raise SystemExit("pre-push must remain the explicit blocking tier")
PY

(cd "$root" && shasum -a 256 -c third_party/mattpocock-skills/promoted-files.sha256 \
  >/dev/null) || fail "vendored Matt snapshot hash drift"

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
mkdir -p "$guard_repo/templates/hooks/scripts" "$guard_repo/templates/hooks" "$guard_repo/docs/foundation/receipts" "$guard_repo/src"
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
  "$guard_revision" "$guard_digest" "$guard_revision" > "$guard_repo/docs/foundation/receipts/ok.md"
(cd "$guard_repo" && FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) \
  || fail "valid v2 receipt should clear the surface guard"

git -C "$guard_repo" add .
git -C "$guard_repo" commit -qm guarded-base
range_base=$(git -C "$guard_repo" rev-parse HEAD)
printf 'changed-again\n' > "$guard_repo/src/base.txt"
range_oid=$(git -C "$guard_repo" hash-object "$guard_repo/src/base.txt")
range_digest=$(printf 'src/base.txt\t%s\n' "$range_oid" | shasum -a 256 | awk '{print $1}')
printf '<!-- foundation-integrity-receipt:v2\nclassification: FOUNDATION_OK\nroute: Feature-first\nreviewer: human:test\nverdict: upholds\noutcome: PROCEED\nrevision: %s\nchange-digest: %s\nevidence-ref: commit:%s\ncanonical-invariant: source remains authoritative.\nsurface-path: src/base.txt\n-->\n' \
  "$range_base" "$range_digest" "$range_base" > "$guard_repo/docs/foundation/receipts/ok.md"
git -C "$guard_repo" add .
git -C "$guard_repo" commit -qm guarded-change
range_head=$(git -C "$guard_repo" rev-parse HEAD)
(cd "$guard_repo" && FI_RANGE="$range_base..$range_head" FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) \
  || fail "valid range-bound v2 receipt should clear the surface guard"

# Make the blocking probe reach temporary-workspace creation; a clean worktree
# would legitimately exit before it needs TMPDIR.
printf 'changed-third\n' > "$guard_repo/src/base.txt"
bad_guard_tmp="$tmp/unavailable-tmp"
printf 'not-a-directory\n' > "$bad_guard_tmp"
if (cd "$guard_repo" && TMPDIR="$bad_guard_tmp" FI_BLOCK=1 sh templates/hooks/scripts/foundation-surface-guard.sh) >/dev/null 2>&1
then
  fail "blocking surface guard must fail closed when temporary storage is unavailable"
fi

echo "repo contracts: PASS"
