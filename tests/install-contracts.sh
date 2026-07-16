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
[ -f "$core/docs/foundation/why-foundation-integrity.md" ] || fail "core bootstrap omitted compact docs"
[ -f "$core/docs/adr/0000-template.md" ] || fail "core bootstrap omitted ADR template"
[ ! -e "$core/templates" ] || fail "core bootstrap retained a top-level templates directory"
[ ! -e "$core/templates/setup" ] || fail "core bootstrap copied distribution setup sources"
[ "$(find "$core/docs/agents" -maxdepth 1 -type f | wc -l | tr -d ' ')" = 4 ] \
  || fail "core bootstrap did not install exactly four consumer docs"
[ ! -e "$core/docs/foundation/fitness" ] || fail "core bootstrap unexpectedly installed fitness"
[ ! -e "$core/.foundation-integrity/hooks" ] || fail "core bootstrap unexpectedly installed hooks"
[ ! -e "$core/.orchestration/foundation" ] || fail "core bootstrap unexpectedly installed orchestration"
grep -Fqx 'docs/adr/*.md' "$core/.gitignore" || fail "core bootstrap did not ignore personal ADR history"
grep -Fqx '!docs/adr/0000-template.md' "$core/.gitignore" || fail "core bootstrap ignored the ADR template"
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
[ -f "$fitness/docs/foundation/fitness/proof-surface-selection.md" ] || fail "fitness option omitted fitness assets"
[ ! -e "$fitness/.foundation-integrity/hooks" ] || fail "fitness-only option unexpectedly installed hooks"
[ ! -e "$fitness/.orchestration/foundation" ] || fail "fitness-only option unexpectedly installed orchestration"
[ "$(setting components "$fitness/.foundation-integrity/adoption.tsv")" = core,fitness ] \
  || fail "fitness component ledger is wrong"

orchestration_codex="$tmp/orchestration-codex"
mkdir -p "$orchestration_codex"
run_install --codex --with-orchestration --directory "$orchestration_codex" >/dev/null \
  || fail "Codex orchestration bootstrap failed"
[ -d "$orchestration_codex/.orchestration/foundation/profiles/codex" ] \
  || fail "Codex orchestration omitted Codex profiles"
[ ! -e "$orchestration_codex/.orchestration/foundation/profiles/claude" ] \
  || fail "Codex orchestration copied Claude profiles"
[ -f "$orchestration_codex/.orchestration/foundation/runtime/codex.md" ] \
  || fail "Codex orchestration omitted the selected adapter"
[ ! -e "$orchestration_codex/.orchestration/foundation/runtime/claude.md" ] \
  || fail "Codex orchestration copied the Claude adapter"
[ -f "$orchestration_codex/.orchestration/foundation/run-contract.tsv" ] \
  || fail "single-runtime orchestration omitted its contract"
grep -Fq '../coworker-protocol.md' \
  "$orchestration_codex/.orchestration/foundation/runtime/codex.md" \
  || fail "installed Codex adapter retained its pre-move coworker-protocol link"
grep -Fq '../profiles/codex/' \
  "$orchestration_codex/.orchestration/foundation/runtime/codex.md" \
  || fail "installed Codex adapter retained its pre-move profile link"
grep -Fq '../run-contract.tsv' \
  "$orchestration_codex/.orchestration/foundation/runtime/codex.md" \
  || fail "installed Codex adapter retained its pre-move contract link"
[ -f "$orchestration_codex/.orchestration/foundation/runtime/../coworker-protocol.md" ] \
  || fail "installed Codex adapter points at a missing coworker protocol"
[ -d "$orchestration_codex/.orchestration/foundation/runtime/../profiles/codex" ] \
  || fail "installed Codex adapter points at missing Codex profiles"
[ -f "$orchestration_codex/.orchestration/foundation/runtime/../run-contract.tsv" ] \
  || fail "installed Codex adapter points at a missing run contract"
[ ! -e "$orchestration_codex/.foundation/orchestration" ] \
  || fail "orchestration adoption created live runtime state"
[ ! -e "$orchestration_codex/templates" ] \
  || fail "orchestration adoption retained a top-level templates directory"

hooks="$tmp/hooks"
mkdir -p "$hooks"
git -C "$hooks" init -q
run_install --codex --with-hooks --directory "$hooks" >/dev/null \
  || fail "hooks bootstrap failed"
[ ! -e "$hooks/docs/foundation/fitness" ] || fail "hooks option unexpectedly installed fitness guidance"
[ -f "$hooks/.foundation-integrity/hooks/fitness-check.sh" ] || fail "hooks option omitted hook assets"
[ -f "$hooks/.codex/hooks.json" ] || fail "hooks option omitted Codex project hook config"
[ ! -e "$hooks/.claude/settings.json" ] || fail "Codex hooks option leaked Claude project config"
grep -Fq '.foundation-integrity/hooks/codex-post-tool-use.sh' "$hooks/.codex/hooks.json" \
  || fail "Codex project hook does not resolve the managed adapter"
grep -Fq 'Bash|Edit|Write|apply_patch' "$hooks/.codex/hooks.json" \
  || fail "Codex project hook misses shell or patch-based writes"
[ -x "$hooks/.git/hooks/pre-commit" ] || fail "hooks option did not wire warn-only pre-commit"
[ ! -e "$hooks/.git/hooks/pre-push" ] || fail "hooks option activated pre-push"
[ ! -e "$hooks/.orchestration/foundation" ] || fail "hooks option unexpectedly installed orchestration"
[ "$(setting components "$hooks/.foundation-integrity/adoption.tsv")" = core,hooks ] \
  || fail "hooks component ledger is wrong"
[ ! -e "$hooks/templates" ] || fail "hooks bootstrap retained a top-level templates directory"

full="$tmp/full"
mkdir -p "$full"
git -C "$full" init -q
run_install --both --full-opt --directory "$full" >/dev/null || fail "full bootstrap failed"
[ "$(count_skills "$full/.agents/skills")" = 24 ] || fail "full bootstrap omitted Codex skills"
[ "$(count_skills "$full/.claude/skills")" = 24 ] || fail "full bootstrap omitted Claude skills"
for selected in docs/foundation/fitness .foundation-integrity/hooks .orchestration/foundation; do
  [ -d "$full/$selected" ] || fail "full bootstrap omitted $selected"
done
[ -x "$full/.git/hooks/pre-commit" ] || fail "full bootstrap did not wire pre-commit"
[ ! -e "$full/.git/hooks/pre-push" ] || fail "full bootstrap activated pre-push without opt-in"
[ -f "$full/.codex/hooks.json" ] || fail "full bootstrap omitted Codex project hook config"
[ -f "$full/.claude/settings.json" ] || fail "full bootstrap omitted Claude project hook config"
grep -Fq 'Bash|Edit|Write|MultiEdit' "$full/.claude/settings.json" \
  || fail "Claude project hook misses shell-based writes"
[ -d "$full/.orchestration/foundation/profiles/codex" ] || fail "full bootstrap omitted Codex orchestration profiles"
[ -d "$full/.orchestration/foundation/profiles/claude" ] || fail "full bootstrap omitted Claude orchestration profiles"
grep -Fq '../coworker-protocol.md' "$full/.orchestration/foundation/runtime/claude.md" \
  || fail "installed Claude adapter retained its pre-move coworker-protocol link"
grep -Fq '../profiles/claude/' "$full/.orchestration/foundation/runtime/claude.md" \
  || fail "installed Claude adapter retained its pre-move profile link"
[ -f "$full/.orchestration/foundation/runtime/../coworker-protocol.md" ] \
  || fail "installed Claude adapter points at a missing coworker protocol"
[ -d "$full/.orchestration/foundation/runtime/../profiles/claude" ] \
  || fail "installed Claude adapter points at missing Claude profiles"
[ -f "$full/.orchestration/foundation/run-contract.codex.tsv" ] || fail "both-runtime orchestration omitted Codex contract"
[ -f "$full/.orchestration/foundation/run-contract.claude.tsv" ] || fail "both-runtime orchestration omitted Claude contract"
[ ! -e "$full/.orchestration/foundation/run-contract.tsv" ] || fail "both-runtime orchestration installed an ambiguous contract"
[ ! -e "$full/.foundation/orchestration" ] || fail "full bootstrap activated orchestration runtime state"
[ ! -e "$full/templates" ] || fail "full bootstrap retained a top-level templates directory"
[ "$(setting components "$full/.foundation-integrity/adoption.tsv")" = core,fitness,hooks,orchestration ] \
  || fail "full component ledger is wrong"

mode_tamper="$full/.foundation-integrity/hooks/fitness-check.sh"
chmod 644 "$mode_tamper"
if run_install --both --full-opt --directory "$full" >/dev/null 2>&1; then
  fail "rerun accepted a managed executable-mode change"
fi
[ "$(stat -f '%Lp' "$mode_tamper" 2>/dev/null || stat -c '%a' "$mode_tamper")" = 644 ] \
  || fail "mode-conflict rejection changed the consumer mode"
[ ! -e "$full/.foundation-integrity-install.lock" ] || fail "failed rerun leaked its acquired lock"

codex_hook_conflict="$tmp/codex-hook-conflict"
mkdir -p "$codex_hook_conflict/.codex"
printf '{"hooks":{"Stop":[]}}\n' > "$codex_hook_conflict/.codex/hooks.json"
if run_install --codex --with-hooks --no-pre-commit --directory "$codex_hook_conflict" >/dev/null 2>&1; then
  fail "hooks bootstrap overwrote an existing Codex hook policy"
fi
grep -Fqx '{"hooks":{"Stop":[]}}' "$codex_hook_conflict/.codex/hooks.json" \
  || fail "Codex hook conflict damaged the existing policy"
[ ! -e "$codex_hook_conflict/.agents/skills" ] || fail "Codex hook preflight conflict partially installed skills"

claude_hook_conflict="$tmp/claude-hook-conflict"
mkdir -p "$claude_hook_conflict/.claude"
printf '{"permissions":{"allow":[]}}\n' > "$claude_hook_conflict/.claude/settings.json"
if run_install --claude --with-hooks --no-pre-commit --directory "$claude_hook_conflict" >/dev/null 2>&1; then
  fail "hooks bootstrap overwrote existing Claude project settings"
fi
grep -Fqx '{"permissions":{"allow":[]}}' "$claude_hook_conflict/.claude/settings.json" \
  || fail "Claude settings conflict damaged the existing policy"
[ ! -e "$claude_hook_conflict/.claude/skills" ] || fail "Claude hook preflight conflict partially installed skills"

external_identical="$tmp/external-identical"
mkdir -p "$external_identical/docs/foundation/fitness"
cp "$root/templates/fitness/README.md" "$external_identical/docs/foundation/fitness/README.md"
run_install --codex --full-opt --no-pre-commit --directory "$external_identical" >/dev/null \
  || fail "external-identical fixture install failed"
awk -F '\t' '$1 == "external" && $3 == "docs/foundation/fitness/README.md" { found = 1 } END { exit !found }' \
  "$external_identical/.foundation-integrity/adoption.tsv" \
  || fail "pre-existing identical file was silently claimed as managed"
run_install --codex --core --no-pre-commit --directory "$external_identical" >/dev/null \
  || fail "external-identical component downgrade failed"
cmp -s "$root/templates/fitness/README.md" "$external_identical/docs/foundation/fitness/README.md" \
  || fail "component downgrade removed or changed an external-identical file"
[ ! -e "$external_identical/.orchestration/foundation/coworker-protocol.md" ] \
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
run_install --codex --directory "$instruction_hardlink" >/dev/null \
  || fail "bootstrap rejected a consumer-owned hardlinked instruction file"
grep -Fxq '# Shared instructions' "$instruction_external" \
  || fail "bootstrap changed the consumer-owned instruction inode"
[ -e "$instruction_hardlink/.foundation-integrity/adoption.tsv" ] \
  || fail "instruction-preserving install omitted adoption state"

downgrade="$tmp/downgrade"
mkdir -p "$downgrade"
git -C "$downgrade" init -q
run_install --codex --full-opt --directory "$downgrade" >/dev/null \
  || fail "downgrade fixture full install failed"
run_install --codex --core --directory "$downgrade" >/dev/null \
  || fail "full-to-core downgrade failed"
assert_no_files "$downgrade/docs/foundation/fitness"
assert_no_files "$downgrade/.foundation-integrity/hooks"
assert_no_files "$downgrade/.orchestration/foundation"
[ ! -e "$downgrade/.codex/hooks.json" ] || fail "core downgrade retained Codex project hook config"
[ ! -e "$downgrade/.git/hooks/pre-commit" ] || fail "core downgrade retained an unchanged managed pre-commit"
[ "$(setting components "$downgrade/.foundation-integrity/adoption.tsv")" = core ] \
  || fail "core downgrade ledger retained optional components"

downgrade_conflict="$tmp/downgrade-conflict"
mkdir -p "$downgrade_conflict"
git -C "$downgrade_conflict" init -q
run_install --codex --full-opt --directory "$downgrade_conflict" >/dev/null \
  || fail "downgrade-conflict fixture full install failed"
printf 'consumer edit\n' >> "$downgrade_conflict/docs/foundation/fitness/README.md"
if run_install --codex --core --directory "$downgrade_conflict" >/dev/null 2>&1; then
  fail "core downgrade removed a consumer-edited optional file"
fi
grep -Fq 'consumer edit' "$downgrade_conflict/docs/foundation/fitness/README.md" \
  || fail "downgrade conflict damaged the edited optional file"
[ -e "$downgrade_conflict/.orchestration/foundation/coworker-protocol.md" ] \
  || fail "downgrade conflict partially removed other optional components"
[ -x "$downgrade_conflict/.git/hooks/pre-commit" ] \
  || fail "downgrade conflict partially removed the managed hook"

printf '%s\n' 'install contracts: PASS'
