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

setting() {
  key=$1
  lock=$2
  awk -F '\t' -v key="$key" \
    '$1 == "setting" && $2 == key { print $3; exit }' "$lock"
}

assert_no_files() {
  path=$1
  [ ! -d "$path" ] || [ -z "$(find "$path" -type f -print -quit)" ] \
    || fail "unexpected managed files remain under $path"
}

missing_runtime="$tmp/missing-runtime"
mkdir -p "$missing_runtime"
if run_install --directory "$missing_runtime" >/dev/null 2>&1; then
  fail "bootstrap accepted a request without a runtime"
fi
[ ! -e "$missing_runtime/AGENTS.md" ] || fail "missing-runtime rejection mutated target"

conflicting_runtime="$tmp/conflicting-runtime"
mkdir -p "$conflicting_runtime"
if run_install --codex --claude --directory "$conflicting_runtime" >/dev/null 2>&1; then
  fail "bootstrap accepted conflicting runtime flags"
fi
[ ! -e "$conflicting_runtime/AGENTS.md" ] || fail "runtime conflict mutated target"

conflicting_preset="$tmp/conflicting-preset"
mkdir -p "$conflicting_preset"
if run_install --codex --core --full-opt --directory "$conflicting_preset" >/dev/null 2>&1; then
  fail "bootstrap accepted conflicting preset flags"
fi
[ ! -e "$conflicting_preset/AGENTS.md" ] || fail "preset conflict mutated target"

dry_run="$tmp/dry-run"
mkdir -p "$dry_run"
run_install --both --full-opt --dry-run --directory "$dry_run" >/dev/null \
  || fail "bootstrap dry-run failed"
[ ! -e "$dry_run/AGENTS.md" ] || fail "bootstrap dry-run wrote instructions"
[ ! -e "$dry_run/.foundation-integrity" ] || fail "bootstrap dry-run wrote adoption state"
[ ! -e "$dry_run/.foundation-integrity-install.lock" ] || fail "bootstrap dry-run acquired a target lock"

# Exercise the remote-resolution branch without trusting live network state: the
# curl double returns a GitHub-shaped commit response and the exact source archive.
mock_bin="$tmp/mock-bin"
mock_archive="$tmp/source.tar.gz"
mkdir -p "$mock_bin"
COPYFILE_DISABLE=1 tar -czf "$mock_archive" \
  --exclude='.git' --exclude='.foundation' \
  -C "$(dirname "$root")" "$(basename "$root")"
printf '%s\n' \
  '#!/bin/sh' \
  'set -eu' \
  'url=' \
  'output=' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -o) output=$2; shift 2 ;;' \
  '    -*) shift ;;' \
  '    *) url=$1; shift ;;' \
  '  esac' \
  'done' \
  '[ -z "${FI_MOCK_CURL_LOG:-}" ] || printf "%s\\n" "$url" >> "$FI_MOCK_CURL_LOG"' \
  'case "$url" in' \
  "  */commits/*) [ -n \"\$output\" ]; printf '%s\\n' '  \"sha\": \"2222222222222222222222222222222222222222\",' > \"\$output\" ;;" \
  '  */tar.gz/*) [ -n "$output" ]; cp "$FI_MOCK_ARCHIVE" "$output" ;;' \
  '  *) printf "unexpected curl URL: %s\\n" "$url" >&2; exit 3 ;;' \
  'esac' > "$mock_bin/curl"
chmod +x "$mock_bin/curl"
remote="$tmp/remote"
mock_log="$tmp/mock-curl.log"
mkdir -p "$remote"
PATH="$mock_bin:$PATH" FI_MOCK_ARCHIVE="$mock_archive" FI_MOCK_CURL_LOG="$mock_log" \
  bash "$root/scripts/install.sh" --codex --ref mock-branch --directory "$remote" >/dev/null \
  || fail "mocked remote bootstrap failed"
[ "$(count_skills "$remote/.agents/skills")" = 24 ] || fail "remote bootstrap omitted Codex skills"
remote_lock="$remote/.foundation-integrity/adoption.tsv"
[ "$(setting source-ref "$remote_lock")" = mock-branch ] || fail "remote bootstrap lost requested ref"
[ "$(setting source-revision "$remote_lock")" = 2222222222222222222222222222222222222222 ] \
  || fail "remote bootstrap did not bind the resolved commit"
[ "$(setting source-tree-state "$remote_lock")" = clean ] || fail "remote archive was not recorded clean"
grep -Fqx 'https://api.github.com/repos/long7400/foundation-integrity/commits/mock-branch' "$mock_log" \
  || fail "remote bootstrap did not request the expected ref endpoint"
grep -Fqx 'https://codeload.github.com/long7400/foundation-integrity/tar.gz/2222222222222222222222222222222222222222' "$mock_log" \
  || fail "remote bootstrap did not request the archive by resolved commit"

reserved_ref="$tmp/reserved-ref"
mkdir -p "$reserved_ref"
: > "$mock_log"
PATH="$mock_bin:$PATH" FI_MOCK_ARCHIVE="$mock_archive" FI_MOCK_CURL_LOG="$mock_log" \
  bash "$root/scripts/install.sh" --codex --ref 'topic#1' \
  --dry-run --directory "$reserved_ref" >/dev/null \
  || fail "reserved-character ref bootstrap failed"
grep -Fqx 'https://api.github.com/repos/long7400/foundation-integrity/commits/topic%231' "$mock_log" \
  || fail "bootstrap did not URL-encode a valid reserved ref character"
[ ! -e "$reserved_ref/.foundation-integrity" ] || fail "reserved-ref dry-run mutated target"

multi_source="$tmp/multi-source"
multi_archive="$tmp/multi-source.tar.gz"
mkdir -p "$multi_source/one" "$multi_source/two"
tar -czf "$multi_archive" -C "$multi_source" one two
multi_target="$tmp/multi-target"
mkdir -p "$multi_target"
if PATH="$mock_bin:$PATH" FI_MOCK_ARCHIVE="$multi_archive" \
  bash "$root/scripts/install.sh" --codex --ref mock-branch \
  --dry-run --directory "$multi_target" >/dev/null 2>&1
then
  fail "remote bootstrap accepted an archive with multiple roots"
fi
[ ! -e "$multi_target/AGENTS.md" ] || fail "multiple-root rejection mutated target"

symlink_source="$tmp/symlink-source"
symlink_archive="$tmp/symlink-source.tar.gz"
mkdir -p "$symlink_source/root/templates/setup"
printf '#!/bin/sh\n' > "$symlink_source/root/templates/setup/full-opt.sh"
ln -s full-opt.sh "$symlink_source/root/templates/setup/linked-adopter.sh"
tar -czf "$symlink_archive" -C "$symlink_source" root
symlink_target="$tmp/symlink-target"
mkdir -p "$symlink_target"
if PATH="$mock_bin:$PATH" FI_MOCK_ARCHIVE="$symlink_archive" \
  bash "$root/scripts/install.sh" --codex --ref mock-branch \
  --dry-run --directory "$symlink_target" >/dev/null 2>&1
then
  fail "remote bootstrap accepted an archive containing a symlink"
fi
[ ! -e "$symlink_target/AGENTS.md" ] || fail "archive-symlink rejection mutated target"

direct_ref="$tmp/direct-ref"
mkdir -p "$direct_ref"
PATH="$mock_bin:$PATH" FI_MOCK_ARCHIVE="$mock_archive" \
  bash "$root/scripts/install.sh" --codex \
  --ref AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA \
  --dry-run --directory "$direct_ref" > "$tmp/direct-ref.out" \
  || fail "direct commit bootstrap failed"
grep -Fq 'resolved commit: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$tmp/direct-ref.out" \
  || fail "direct commit ref was not normalized portably"
[ ! -e "$direct_ref/.foundation-integrity" ] || fail "direct-ref dry-run mutated target"

core="$tmp/core"
mkdir -p "$core"
run_install --codex --directory "$core" >/dev/null || fail "default core bootstrap failed"
[ "$(count_skills "$core/.agents/skills")" = 24 ] || fail "core bootstrap did not install 24 Codex skills"
[ ! -e "$core/.claude/skills" ] || fail "Codex core bootstrap leaked Claude skills"
[ -f "$core/templates/docs/why-foundation-integrity.md" ] || fail "core bootstrap omitted compact docs"
[ -f "$core/templates/adr/0000-template.md" ] || fail "core bootstrap omitted ADR template"
[ -x "$core/templates/setup/check-credential-permissions.sh" ] || fail "core bootstrap lost setup-helper mode"
[ "$(find "$core/docs/agents" -maxdepth 1 -type f | wc -l | tr -d ' ')" = 4 ] \
  || fail "core bootstrap did not install exactly four consumer docs"
[ ! -e "$core/templates/fitness" ] || fail "core bootstrap unexpectedly installed fitness"
[ ! -e "$core/templates/hooks" ] || fail "core bootstrap unexpectedly installed hooks"
[ ! -e "$core/templates/orchestration" ] || fail "core bootstrap unexpectedly installed orchestration"
core_lock="$core/.foundation-integrity/adoption.tsv"
[ "$(setting components "$core_lock")" = core ] || fail "core component ledger is wrong"
[ "$(setting source-ref "$core_lock")" = main ] || fail "bootstrap source ref is not recorded"
[ "$(setting source-revision "$core_lock")" = "$revision" ] || fail "bootstrap source revision is not recorded"

fitness="$tmp/fitness"
mkdir -p "$fitness"
run_install --claude --with-fitness --directory "$fitness" >/dev/null \
  || fail "Claude fitness bootstrap failed"
[ "$(count_skills "$fitness/.claude/skills")" = 24 ] || fail "fitness bootstrap did not install 24 Claude skills"
[ ! -e "$fitness/.agents/skills" ] || fail "Claude fitness bootstrap leaked Codex skills"
[ -f "$fitness/templates/fitness/proof-surface-selection.md" ] || fail "fitness option omitted fitness assets"
[ ! -e "$fitness/templates/hooks" ] || fail "fitness-only option unexpectedly installed hooks"
[ ! -e "$fitness/templates/orchestration" ] || fail "fitness-only option unexpectedly installed orchestration"
[ "$(setting components "$fitness/.foundation-integrity/adoption.tsv")" = core,fitness ] \
  || fail "fitness component ledger is wrong"

hooks="$tmp/hooks"
mkdir -p "$hooks"
git -C "$hooks" init -q
run_install --codex --with-hooks --directory "$hooks" >/dev/null \
  || fail "hooks bootstrap failed"
[ -f "$hooks/templates/fitness/proof-surface-selection.md" ] || fail "hooks option did not imply fitness"
[ -f "$hooks/templates/hooks/scripts/fitness-check.sh" ] || fail "hooks option omitted hook assets"
[ -x "$hooks/.git/hooks/pre-commit" ] || fail "hooks option did not wire warn-only pre-commit"
[ ! -e "$hooks/.git/hooks/pre-push" ] || fail "hooks option activated pre-push"
[ ! -e "$hooks/templates/orchestration" ] || fail "hooks option unexpectedly installed orchestration"
[ "$(setting components "$hooks/.foundation-integrity/adoption.tsv")" = core,fitness,hooks ] \
  || fail "hooks component ledger is wrong"

full="$tmp/full"
mkdir -p "$full"
git -C "$full" init -q
run_install --both --full-opt --directory "$full" >/dev/null || fail "full bootstrap failed"
[ "$(count_skills "$full/.agents/skills")" = 24 ] || fail "full bootstrap omitted Codex skills"
[ "$(count_skills "$full/.claude/skills")" = 24 ] || fail "full bootstrap omitted Claude skills"
for selected in templates/fitness templates/hooks templates/orchestration; do
  [ -d "$full/$selected" ] || fail "full bootstrap omitted $selected"
done
[ -x "$full/.git/hooks/pre-commit" ] || fail "full bootstrap did not wire pre-commit"
[ ! -e "$full/.git/hooks/pre-push" ] || fail "full bootstrap activated pre-push without opt-in"
[ ! -e "$full/.codex/config.toml" ] || fail "full bootstrap activated Codex project config"
[ ! -e "$full/.claude/settings.json" ] || fail "full bootstrap activated Claude project settings"
[ ! -e "$full/.foundation/orchestration" ] || fail "full bootstrap activated orchestration runtime state"
[ "$(setting components "$full/.foundation-integrity/adoption.tsv")" = core,fitness,hooks,orchestration ] \
  || fail "full component ledger is wrong"

mode_tamper="$full/templates/hooks/scripts/fitness-check.sh"
chmod 644 "$mode_tamper"
if run_install --both --full-opt --directory "$full" >/dev/null 2>&1; then
  fail "rerun accepted a managed executable-mode change"
fi
[ "$(stat -f '%Lp' "$mode_tamper" 2>/dev/null || stat -c '%a' "$mode_tamper")" = 644 ] \
  || fail "mode-conflict rejection changed the consumer mode"
[ ! -e "$full/.foundation-integrity-install.lock" ] || fail "failed rerun leaked its acquired lock"

external_identical="$tmp/external-identical"
mkdir -p "$external_identical/templates/fitness"
cp "$root/templates/fitness/README.md" "$external_identical/templates/fitness/README.md"
run_install --codex --full-opt --no-pre-commit --directory "$external_identical" >/dev/null \
  || fail "external-identical fixture install failed"
awk -F '\t' '$1 == "external" && $3 == "templates/fitness/README.md" { found = 1 } END { exit !found }' \
  "$external_identical/.foundation-integrity/adoption.tsv" \
  || fail "pre-existing identical file was silently claimed as managed"
run_install --codex --core --no-pre-commit --directory "$external_identical" >/dev/null \
  || fail "external-identical component downgrade failed"
cmp -s "$root/templates/fitness/README.md" "$external_identical/templates/fitness/README.md" \
  || fail "component downgrade removed or changed an external-identical file"
[ ! -e "$external_identical/templates/orchestration/coworker-protocol.md" ] \
  || fail "component downgrade retained an installer-owned optional file"

external_hook="$tmp/external-hook"
mkdir -p "$external_hook"
git -C "$external_hook" init -q
cp "$root/templates/hooks/git/pre-commit" "$external_hook/.git/hooks/pre-commit"
chmod +x "$external_hook/.git/hooks/pre-commit"
run_install --codex --full-opt --directory "$external_hook" >/dev/null \
  || fail "external-identical hook fixture install failed"
if awk -F '\t' '$1 == "hook" && $3 == ".git/hooks/pre-commit" { found = 1 } END { exit !found }' \
  "$external_hook/.foundation-integrity/adoption.tsv"
then
  fail "pre-existing identical hook was silently claimed as managed"
fi
run_install --codex --core --directory "$external_hook" >/dev/null \
  || fail "external-identical hook downgrade failed"
cmp -s "$root/templates/hooks/git/pre-commit" "$external_hook/.git/hooks/pre-commit" \
  || fail "component downgrade removed or changed an external-identical hook"

held_lock="$tmp/held-lock"
mkdir -p "$held_lock/.foundation-integrity-install.lock"
printf 'owner sentinel\n' > "$held_lock/.foundation-integrity-install.lock/owner"
if run_install --codex --directory "$held_lock" >/dev/null 2>&1; then
  fail "bootstrap acquired an already-held target lock"
fi
[ -f "$held_lock/.foundation-integrity-install.lock/owner" ] \
  || fail "failed lock acquisition removed another installer's lock"
[ ! -e "$held_lock/AGENTS.md" ] || fail "held-lock rejection mutated target"

replaced_lock="$tmp/replaced-lock"
mkdir -p "$replaced_lock"
run_install --both --full-opt --no-pre-commit --directory "$replaced_lock" \
  > "$tmp/replaced-lock.out" 2>&1 &
replaced_pid=$!
lock_seen=0
attempt=0
while [ "$attempt" -lt 1000 ]; do
  if [ -f "$replaced_lock/.foundation-integrity-install.lock/owner" ]; then
    lock_seen=1
    break
  fi
  attempt=$((attempt + 1))
  sleep 0.01
done
if [ "$lock_seen" != 1 ]; then
  wait "$replaced_pid" || true
  fail "could not observe the acquired lock for replacement test"
fi
rm -rf "$replaced_lock/.foundation-integrity-install.lock"
mkdir "$replaced_lock/.foundation-integrity-install.lock"
printf 'replacement owner\n' > "$replaced_lock/.foundation-integrity-install.lock/owner"
wait "$replaced_pid" || fail "installer failed after lock replacement fixture"
grep -Fxq 'replacement owner' "$replaced_lock/.foundation-integrity-install.lock/owner" \
  || fail "installer cleanup removed or rewrote a replacement lock"
rm -rf "$replaced_lock/.foundation-integrity-install.lock"

hardlink_target="$tmp/hardlink-target"
hardlink_external="$tmp/hardlink-external-skill.md"
mkdir -p "$hardlink_target/.agents/skills/foundation-audit"
cp "$root/.agents/skills/foundation-audit/SKILL.md" "$hardlink_external"
ln "$hardlink_external" "$hardlink_target/.agents/skills/foundation-audit/SKILL.md"
if run_install --codex --directory "$hardlink_target" >/dev/null 2>&1; then
  fail "bootstrap claimed a multiply linked managed file"
fi
cmp -s "$root/.agents/skills/foundation-audit/SKILL.md" "$hardlink_external" \
  || fail "hardlink rejection changed the external inode"
[ ! -e "$hardlink_target/AGENTS.md" ] || fail "hardlink rejection mutated instructions"

instruction_hardlink="$tmp/instruction-hardlink"
instruction_external="$tmp/instruction-external.md"
mkdir -p "$instruction_hardlink"
printf '# Shared instructions\n' > "$instruction_external"
ln "$instruction_external" "$instruction_hardlink/AGENTS.md"
if run_install --codex --directory "$instruction_hardlink" >/dev/null 2>&1; then
  fail "bootstrap managed a hardlinked instruction owner"
fi
grep -Fxq '# Shared instructions' "$instruction_external" \
  || fail "instruction-hardlink rejection changed the external inode"
[ ! -e "$instruction_hardlink/.foundation-integrity/adoption.tsv" ] \
  || fail "instruction-hardlink rejection wrote adoption state"

downgrade="$tmp/downgrade"
mkdir -p "$downgrade"
git -C "$downgrade" init -q
run_install --codex --full-opt --directory "$downgrade" >/dev/null \
  || fail "downgrade fixture full install failed"
run_install --codex --core --directory "$downgrade" >/dev/null \
  || fail "full-to-core downgrade failed"
assert_no_files "$downgrade/templates/fitness"
assert_no_files "$downgrade/templates/hooks"
assert_no_files "$downgrade/templates/orchestration"
[ ! -e "$downgrade/.git/hooks/pre-commit" ] || fail "core downgrade retained an unchanged managed pre-commit"
[ "$(setting components "$downgrade/.foundation-integrity/adoption.tsv")" = core ] \
  || fail "core downgrade ledger retained optional components"

downgrade_conflict="$tmp/downgrade-conflict"
mkdir -p "$downgrade_conflict"
git -C "$downgrade_conflict" init -q
run_install --codex --full-opt --directory "$downgrade_conflict" >/dev/null \
  || fail "downgrade-conflict fixture full install failed"
printf 'consumer edit\n' >> "$downgrade_conflict/templates/fitness/README.md"
if run_install --codex --core --directory "$downgrade_conflict" >/dev/null 2>&1; then
  fail "core downgrade removed a consumer-edited optional file"
fi
grep -Fq 'consumer edit' "$downgrade_conflict/templates/fitness/README.md" \
  || fail "downgrade conflict damaged the edited optional file"
[ -e "$downgrade_conflict/templates/orchestration/coworker-protocol.md" ] \
  || fail "downgrade conflict partially removed other optional components"
[ -x "$downgrade_conflict/.git/hooks/pre-commit" ] \
  || fail "downgrade conflict partially removed the managed hook"

printf '%s\n' 'install contracts: PASS'
