#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-install-tests.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

revision=1111111111111111111111111111111111111111

run_install() {
  FI_INSTALL_SOURCE_ROOT="$root" \
  FI_SOURCE_REVISION="$revision" \
    bash "$root/scripts/install.sh" "$@"
}

count_skills() {
  find "$1" -name SKILL.md -type f | wc -l | tr -d ' '
}

assert_installed_skill_refs() {
  target=$1
  python3 - "$target" <<'PY'
import pathlib
import re
import sys

target = pathlib.Path(sys.argv[1])
skill_roots = [target / ".agents/skills", target / ".claude/skills"]
stale_refs = (
    "templates/claude-md-block.md",
    "templates/adr/",
    "templates/docs/",
    "templates/fitness/",
    "templates/hooks/",
    ".foundation-integrity/hooks/",
)

for skill_root in skill_roots:
    if not skill_root.is_dir():
        continue
    for skill in skill_root.rglob("*"):
        if not skill.is_file() or skill.suffix not in {".md", ".yaml", ".yml", ".txt", ".toml"}:
            continue
        body = skill.read_text()
        for stale in stale_refs:
            if stale in body:
                raise SystemExit(f"installed skill retains stale reference {stale!r}: {skill}")
        if "/_third_party/" not in skill.as_posix() and "arxiv.org" in body:
            raise SystemExit(f"installed first-party skill retains paper URL: {skill}")
        for reference in re.findall(r"`((?:docs/(?:foundation|agents)/)[^`]+)`", body):
            relative = reference.split("#", 1)[0].rstrip("/")
            if not (target / relative).exists():
                raise SystemExit(f"installed skill reference does not resolve: {skill}: {reference}")
PY
}

assert_ignore_unmanaged_content_preserved() {
  before=$1
  after=$2
  python3 - "$before" "$after" <<'PY'
import pathlib
import sys

def unmanaged(path):
    inside = False
    out = []
    for line in pathlib.Path(path).read_text().splitlines(keepends=True):
        if line.rstrip("\n") == "# BEGIN foundation-integrity generated state":
            inside = True
        if not inside:
            out.append(line)
        if line.rstrip("\n") == "# END foundation-integrity generated state":
            inside = False
    return out

before = unmanaged(sys.argv[1])
after = unmanaged(sys.argv[2])
position = 0
for line in before:
    try:
        position = after.index(line, position) + 1
    except ValueError:
        raise SystemExit("installer changed unmanaged .gitignore content")
PY
}

setting() {
  key=$1
  lock=$2
  awk -F '\t' -v key="$key" \
    '$1 == "setting" && $2 == key { print $3; exit }' "$lock"
}

assert_full_common() {
  target=$1
  [ -f "$target/AGENTS.md" ] || fail "full-opt omitted AGENTS.md"
  [ -f "$target/docs/foundation/fitness/proof-surface-selection.md" ] \
    || fail "full-opt omitted fitness guidance"
  [ -f "$target/.orchestration/foundation/coworker-protocol.md" ] \
    || fail "full-opt omitted orchestration policy"
  [ -x "$target/.git/hooks/pre-commit" ] \
    || fail "full-opt omitted warn-only pre-commit"
  [ ! -e "$target/.git/hooks/pre-push" ] \
    || fail "full-opt enabled pre-push without explicit opt-in"
  for ignored in .foundation/ .orchestration/ .codex/ .agents/ docs/research/ tmp/; do
    grep -Fqx "$ignored" "$target/.gitignore" \
      || fail "full-opt ignore block missing $ignored"
  done
  assert_installed_skill_refs "$target" \
    || fail "installed skill references do not match the adopted layout"
  lock=$target/.foundation-integrity/adoption.tsv
  [ -f "$lock" ] || fail "full-opt omitted adoption lock"
  [ "$(setting components "$lock")" = full-opt ] \
    || fail "adoption lock does not record the only supported payload"
  for managed in .orchestration/foundation/README.md; do
    git -C "$target" check-ignore -q -- "$managed" \
      || fail "consumer ignore block does not hide $managed"
    awk -F '\t' -v path="$managed" \
      '$1 == "file" && $3 == path { found = 1 } END { exit !found }' "$lock" \
      || fail "adoption lock does not bind ignored managed file $managed"
  done
  for managed in .agents/skills/foundation-audit/SKILL.md .codex/hooks.json; do
    [ -e "$target/$managed" ] || continue
    git -C "$target" check-ignore -q -- "$managed" \
      || fail "consumer ignore block does not hide $managed"
    awk -F '\t' -v path="$managed" \
      '$1 == "file" && $3 == path { found = 1 } END { exit !found }' "$lock" \
      || fail "adoption lock does not bind ignored managed file $managed"
  done
}

missing_runtime="$tmp/missing-runtime"
mkdir -p "$missing_runtime"
if run_install --directory "$missing_runtime" >/dev/null 2>&1; then
  fail "bootstrap accepted a request without a runtime"
fi
[ ! -e "$missing_runtime/AGENTS.md" ] || fail "invalid request mutated target"

conflicting_runtime="$tmp/conflicting-runtime"
mkdir -p "$conflicting_runtime"
if run_install --codex --claude --directory "$conflicting_runtime" >/dev/null 2>&1; then
  fail "bootstrap accepted conflicting runtime flags"
fi
[ ! -e "$conflicting_runtime/AGENTS.md" ] || fail "runtime conflict mutated target"

unsupported="$tmp/unsupported"
mkdir -p "$unsupported"
if run_install --codex --core --directory "$unsupported" >/dev/null 2>&1; then
  fail "bootstrap accepted the removed core payload"
fi
[ ! -e "$unsupported/AGENTS.md" ] || fail "unsupported payload mutated target"

dry_run="$tmp/dry-run"
mkdir -p "$dry_run"
run_install --both --full-opt --dry-run --directory "$dry_run" >/dev/null \
  || fail "full-opt dry-run failed"
[ ! -e "$dry_run/AGENTS.md" ] || fail "dry-run wrote AGENTS.md"
[ ! -e "$dry_run/.foundation-integrity" ] || fail "dry-run wrote adoption state"

codex="$tmp/codex"
mkdir -p "$codex"
git -C "$codex" init -q
printf '# consumer gitignore\nconsumer-cache/\n' > "$codex/.gitignore"
cp "$codex/.gitignore" "$tmp/codex-gitignore-before"
run_install --codex --directory "$codex" >/dev/null || fail "Codex full-opt install failed"
assert_full_common "$codex"
assert_ignore_unmanaged_content_preserved "$tmp/codex-gitignore-before" "$codex/.gitignore" \
  || fail "full-opt install changed unmanaged .gitignore content"
[ "$(count_skills "$codex/.agents/skills")" = 24 ] || fail "Codex install omitted skills"
diff -qr "$root/.agents/skills" "$codex/.agents/skills" >/dev/null \
  || fail "Codex install changed projected skill content"
[ ! -e "$codex/.claude/skills" ] || fail "Codex install leaked Claude skills"
[ -x "$codex/.codex/hooks/scripts/fitness-check.sh" ] || fail "Codex hook scripts missing"
[ ! -e "$codex/.foundation-integrity/hooks" ] || fail "Codex install retained a separate legacy hook tree"
[ -f "$codex/.codex/hooks.json" ] || fail "Codex hooks.json missing"
[ ! -e "$codex/.claude/settings.json" ] || fail "Codex install leaked Claude settings"
[ -d "$codex/.orchestration/foundation/profiles/codex" ] \
  || fail "Codex orchestration profiles missing"
[ ! -e "$codex/.orchestration/foundation/profiles/claude" ] \
  || fail "Codex install leaked Claude orchestration profiles"
cmp -s "$root/templates/setup/AGENTS.md" "$codex/AGENTS.md" \
  || fail "installed AGENTS.md differs from the generic source"
grep -Fq '.codex/hooks/scripts/codex-post-tool-use.sh' "$codex/.codex/hooks.json" \
  || fail "Codex hook config retains the legacy script path"
(cd "$codex" && sh .git/hooks/pre-commit >/dev/null 2>&1) \
  || fail "Codex runtime-neutral pre-commit loader did not run"

agents_before=$(shasum -a 256 "$codex/AGENTS.md" | awk '{ print $1 }')
mkdir -p "$codex/.agents/skills/consumer-owned"
printf '%s\n' '---' 'name: consumer-owned' 'description: fixture' '---' \
  > "$codex/.agents/skills/consumer-owned/SKILL.md"
run_install --codex --full-opt --directory "$codex" >/dev/null \
  || fail "Codex full-opt install is not idempotent"
[ "$agents_before" = "$(shasum -a 256 "$codex/AGENTS.md" | awk '{ print $1 }')" ] \
  || fail "idempotent install changed AGENTS.md"
[ -f "$codex/.agents/skills/consumer-owned/SKILL.md" ] \
  || fail "idempotent install removed an unrelated consumer skill"

git -C "$codex" config user.email fixture@example.invalid
git -C "$codex" config user.name 'Foundation Integrity fixture'
git -C "$codex" add -A
git -C "$codex" commit -qm baseline >/dev/null 2>&1
mkdir -p "$codex/src/api"
printf 'export const contract = 1;\n' > "$codex/src/api/contract.ts"
if (cd "$codex" && sh .codex/hooks/scripts/foundation-surface-guard.sh \
  >"$tmp/codex-guard.out" 2>"$tmp/codex-guard.err"); then
  fail "moved Codex surface guard missed a foundation-surface change"
fi
grep -Fq 'foundation-surface change without a valid decision' "$tmp/codex-guard.err" \
  || fail "moved Codex surface guard omitted its diagnostic"

chmod 644 "$codex/.codex/hooks/scripts/fitness-check.sh"
if run_install --codex --directory "$codex" >/dev/null 2>&1; then
  fail "rerun accepted a managed hook mode change"
fi

existing="$tmp/existing-agents"
mkdir -p "$existing"
git -C "$existing" init -q
printf '# Consumer rules\n' > "$existing/AGENTS.md"
printf '# Claude rules\n' > "$existing/CLAUDE.md"
run_install --codex --directory "$existing" >/dev/null \
  || fail "install rejected an existing AGENTS.md"
grep -Fqx '# Consumer rules' "$existing/AGENTS.md" \
  || fail "install changed the consumer AGENTS.md"
grep -Fqx '# Claude rules' "$existing/CLAUDE.md" \
  || fail "install changed the consumer CLAUDE.md"

claude_only="$tmp/claude-only"
mkdir -p "$claude_only"
git -C "$claude_only" init -q
printf '# Claude-only rules\n' > "$claude_only/CLAUDE.md"
run_install --codex --directory "$claude_only" >/dev/null \
  || fail "install rejected a target with only CLAUDE.md"
cmp -s "$root/templates/setup/AGENTS.md" "$claude_only/AGENTS.md" \
  || fail "CLAUDE-only target did not receive the generic AGENTS.md bootstrap"
grep -Fqx '# Claude-only rules' "$claude_only/CLAUDE.md" \
  || fail "install changed the consumer CLAUDE.md when bootstrapping AGENTS.md"

claude="$tmp/claude"
mkdir -p "$claude"
git -C "$claude" init -q
run_install --claude --directory "$claude" >/dev/null || fail "Claude full-opt install failed"
assert_full_common "$claude"
[ "$(count_skills "$claude/.claude/skills")" = 24 ] || fail "Claude install omitted skills"
diff -qr "$root/.claude/skills" "$claude/.claude/skills" >/dev/null \
  || fail "Claude install changed projected skill content"
[ ! -e "$claude/.agents/skills" ] || fail "Claude install leaked Codex skills"
[ -x "$claude/.claude/hooks/scripts/fitness-check.sh" ] || fail "Claude hook scripts missing"
[ ! -e "$claude/.foundation-integrity/hooks" ] || fail "Claude install retained a separate legacy hook tree"
[ -f "$claude/.claude/settings.json" ] || fail "Claude settings missing"
[ ! -e "$claude/.codex/hooks.json" ] || fail "Claude install leaked Codex hook config"
grep -Fq '.claude/hooks/scripts/foundation-surface-guard.sh' "$claude/.claude/settings.json" \
  || fail "Claude settings retain the legacy script path"
(cd "$claude" && sh .git/hooks/pre-commit >/dev/null 2>&1) \
  || fail "Claude runtime-neutral pre-commit loader did not run"

both="$tmp/both"
mkdir -p "$both"
git -C "$both" init -q
run_install --both --full-opt --directory "$both" >/dev/null || fail "both-runtime install failed"
assert_full_common "$both"
[ "$(count_skills "$both/.agents/skills")" = 24 ] || fail "both-runtime Codex skills missing"
[ "$(count_skills "$both/.claude/skills")" = 24 ] || fail "both-runtime Claude skills missing"
diff -qr "$root/.agents/skills" "$both/.agents/skills" >/dev/null \
  || fail "both-runtime Codex skill content drifted"
diff -qr "$root/.claude/skills" "$both/.claude/skills" >/dev/null \
  || fail "both-runtime Claude skill content drifted"
[ -x "$both/.codex/hooks/scripts/fitness-check.sh" ] || fail "both-runtime Codex scripts missing"
[ -x "$both/.claude/hooks/scripts/fitness-check.sh" ] || fail "both-runtime Claude scripts missing"
[ -d "$both/.orchestration/foundation/profiles/codex" ] \
  && [ -d "$both/.orchestration/foundation/profiles/claude" ] \
  || fail "both-runtime orchestration profiles missing"

for shared in foundation-surface.txt foundation-surface-guard.sh fitness-check.sh; do
  cmp -s "$both/.codex/hooks/scripts/$shared" "$both/.claude/hooks/scripts/$shared" \
    || fail "both-runtime copies diverged for $shared"
done

both_ledger=$both/.foundation-integrity/adoption.tsv
both_ledger_saved=$tmp/both-adoption.tsv
cp "$both_ledger" "$both_ledger_saved"
assert_invalid_git_owner() {
  label=$1
  (cd "$both" && sh .git/hooks/pre-commit >/dev/null 2>"$tmp/invalid-owner.err") \
    || fail "$label made warn-only pre-commit blocking"
  grep -Eq 'no valid runtime owner|recorded runtime hook scripts are incomplete' \
    "$tmp/invalid-owner.err" || fail "$label omitted the pre-commit ownership warning"
  if (cd "$both" && printf '' | sh .git/hooks/pre-push >/dev/null 2>&1); then
    fail "$label allowed pre-push without a valid runtime owner"
  fi
}

rm -f "$both_ledger"
assert_invalid_git_owner "missing adoption ledger"
cp "$both_ledger_saved" "$both_ledger"

awk -F '\t' '$1 == "setting" && $2 == "runtime" { next } { print }' \
  "$both_ledger_saved" > "$both_ledger"
assert_invalid_git_owner "missing runtime setting"

awk -F '\t' -v OFS='\t' \
  '$1 == "setting" && $2 == "runtime" { $3 = "invalid" } { print }' \
  "$both_ledger_saved" > "$both_ledger"
assert_invalid_git_owner "invalid runtime setting"

awk -F '\t' -v OFS='\t' \
  '$1 == "setting" && $2 == "runtime" { $3 = "claude" } { print }' \
  "$both_ledger_saved" > "$both_ledger"
mv "$both/.claude/hooks/scripts" "$both/.claude/hooks/scripts.off"
assert_invalid_git_owner "runtime and hook-directory mismatch"
mv "$both/.claude/hooks/scripts.off" "$both/.claude/hooks/scripts"
cp "$both_ledger_saved" "$both_ledger"

cp "$both/.codex/hooks/scripts/fitness-check.sh" "$both/.claude/hooks/scripts/fitness-check.sh"
printf '# diverged consumer copy\n' >> "$both/.claude/hooks/scripts/fitness-check.sh"
if (cd "$both" && printf '' | sh .git/hooks/pre-push >/dev/null 2>&1); then
  fail "both-runtime git loader ignored diverging hook copies"
fi

legacy_source="$tmp/legacy-source"
mkdir -p "$legacy_source"
git -C "$root" archive HEAD | tar -x -C "$legacy_source"
python3 - "$legacy_source" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
full_opt = root / "templates/setup/full-opt.sh"
body = full_opt.read_text()
old = "codex_hook_root=.codex/hooks/scripts"
new = "codex_hook_root=.foundation-integrity/hooks"
if body.count(old) != 1:
    raise SystemExit("legacy fixture could not locate the current Codex hook owner")
full_opt.write_text(body.replace(old, new))

codex_hooks = root / "templates/hooks/codex-hooks.json"
body = codex_hooks.read_text()
old = ".codex/hooks/scripts/"
new = ".foundation-integrity/hooks/"
if old not in body:
    raise SystemExit("legacy fixture could not locate current Codex hook references")
codex_hooks.write_text(body.replace(old, new))
PY
legacy="$tmp/legacy"
mkdir -p "$legacy"
git -C "$legacy" init -q
FI_INSTALL_SOURCE_ROOT="$legacy_source" \
FI_SOURCE_REVISION="$revision" \
  bash "$legacy_source/scripts/install.sh" --codex --full-opt --directory "$legacy" >/dev/null \
  || fail "legacy v2 fixture install failed"
[ -x "$legacy/.foundation-integrity/hooks/fitness-check.sh" ] \
  || fail "legacy fixture did not create the old hook tree"
printf '# Legacy instructions\n' > "$legacy/CLAUDE.md"
python3 - "$legacy/.foundation-integrity/adoption.tsv" "$legacy/CLAUDE.md" <<'PY'
import hashlib
import pathlib
import sys

adoption = pathlib.Path(sys.argv[1])
instruction = pathlib.Path(sys.argv[2])
lines = adoption.read_text().splitlines()
settings = {}
records = []
for line in lines[1:]:
    parts = line.split("\t")
    if parts[0] == "setting":
        settings[parts[1]] = parts[2]
    else:
        records.append(line)

def digest(items):
    return hashlib.sha256("".join(item + "\n" for item in sorted(items)).encode()).hexdigest()

instruction_hash = hashlib.sha256(instruction.read_bytes()).hexdigest()
content_records = [
    f"runtime\t{settings['runtime']}",
    f"components\t{settings['components']}",
    *records,
    f"instruction-block\t{instruction_hash}\tCLAUDE.md",
    f"ignore-block\t{settings['ignore-block-sha256']}\t.gitignore",
]
content_hash = digest(content_records)
payload_records = [
    *content_records,
    f"distribution-version\t{settings['distribution-version']}",
    f"source-repository\t{settings['source-repository']}",
    f"source-ref\t{settings['source-ref']}",
    f"source-revision\t{settings['source-revision']}",
    f"source-tree-state\t{settings['source-tree-state']}",
    f"content-sha256\t{content_hash}",
]
payload_hash = digest(payload_records)

out = ["# foundation-integrity-adoption:v2"]
for key in (
    "distribution-version", "source-repository", "source-ref", "source-revision",
    "source-tree-state", "content-sha256", "payload-sha256", "runtime", "components",
    "ignore-block-sha256",
):
    value = content_hash if key == "content-sha256" else payload_hash if key == "payload-sha256" else settings[key]
    out.append(f"setting\t{key}\t{value}")
out.extend(records)
out.append("setting\tinstruction-target\tCLAUDE.md")
out.append(f"setting\tinstruction-block-sha256\t{instruction_hash}")
adoption.write_text("\n".join(out) + "\n")
PY
if FI_TEST_INTERRUPT_AFTER=after-first-add run_install --codex --directory "$legacy" >/dev/null 2>&1; then
  fail "v2-to-v3 migration ignored the interruption probe"
fi
[ -f "$legacy/.foundation/migrations/foundation-integrity-v2-v3.tsv" ] \
  || fail "interrupted migration did not leave its recovery journal"
FI_TEST_INTERRUPT_AFTER= run_install --codex --directory "$legacy" >/dev/null \
  || fail "v2-to-v3 migration recovery failed"
[ -x "$legacy/.codex/hooks/scripts/fitness-check.sh" ] \
  || fail "migration omitted the new Codex hook scripts"
[ ! -e "$legacy/.foundation-integrity/hooks/fitness-check.sh" ] \
  || fail "migration retained the old hook script tree"
if [ -d "$legacy/.foundation-integrity/hooks" ] \
  && find "$legacy/.foundation-integrity/hooks" -type f -o -type l \
    | grep -q .; then
  fail "migration retained files in the old hook tree"
fi
[ ! -e "$legacy/.foundation/migrations/foundation-integrity-v2-v3.tsv" ] \
  || fail "migration recovery journal was not retired"
[ -f "$legacy/AGENTS.md" ] || fail "migration omitted the generic AGENTS bootstrap"
diff -qr "$root/.agents/skills" "$legacy/.agents/skills" >/dev/null \
  || fail "migration left skill projection content stale"

conflict="$tmp/conflict"
mkdir -p "$conflict/.codex" "$conflict/.claude"
git -C "$conflict" init -q
printf '{"hooks":{"Stop":[]}}\n' > "$conflict/.codex/hooks.json"
printf '{"permissions":{"allow":[]}}\n' > "$conflict/.claude/settings.json"
if run_install --both --directory "$conflict" >/dev/null 2>&1; then
  fail "install overwrote a differing runtime hook config"
fi
[ -f "$conflict/.codex/hooks.json" ] && [ -f "$conflict/.claude/settings.json" ] \
  || fail "runtime config conflict damaged existing files"
[ ! -e "$conflict/AGENTS.md" ] || fail "preflight conflict partially installed AGENTS.md"
[ ! -e "$conflict/.agents/skills" ] || fail "preflight conflict partially installed skills"

pre_push="$tmp/pre-push"
mkdir -p "$pre_push"
git -C "$pre_push" init -q
run_install --codex --with-pre-push --directory "$pre_push" >/dev/null \
  || fail "explicit pre-push install failed"
[ -x "$pre_push/.git/hooks/pre-push" ] || fail "explicit pre-push hook missing"
grep -Fq 'export FI_BLOCK=1' "$pre_push/.git/hooks/pre-push" \
  || fail "pre-push hook is not blocking"
(cd "$pre_push" && printf '' | sh .git/hooks/pre-push >/dev/null 2>&1) \
  || fail "explicit pre-push loader did not run"
git -C "$pre_push" config user.email fixture@example.invalid
git -C "$pre_push" config user.name 'Foundation Integrity fixture'
printf 'baseline\n' > "$pre_push/baseline.txt"
git -C "$pre_push" add -A
git -C "$pre_push" commit -qm baseline >/dev/null 2>&1
base=$(git -C "$pre_push" rev-parse HEAD)
mkdir -p "$pre_push/src/api"
printf 'export const contract = 1;\n' > "$pre_push/src/api/contract.ts"
git -C "$pre_push" add src/api/contract.ts
git -C "$pre_push" commit -qm surface-change >/dev/null 2>&1
head=$(git -C "$pre_push" rev-parse HEAD)
if printf 'refs/heads/main %s refs/heads/main %s\n' "$head" "$base" \
  | (cd "$pre_push" && sh .git/hooks/pre-push origin fixture >/dev/null 2>&1); then
  fail "blocking pre-push missed a committed foundation-surface change"
fi

echo "install contracts: PASS"
