#!/bin/sh
# Transparent full repository adoption for Foundation Integrity.
#
# This installer adopts project-owned assets at their final paths, merges the generated
# ignore block, installs selected project-scoped runtime hooks, and may wire git hooks.
# It never installs plugins, changes user/global runtime configuration, activates
# orchestration, or overwrites an unowned file.
set -eu

usage() {
  cat >&2 <<'EOF'
Usage:
  sh templates/setup/full-opt.sh --runtime codex|claude|both [options] TARGET

Options:
  --full-opt                        Accepted for clarity. Full-opt is the only
                                    supported payload and is always selected.
  --dry-run                         Preview the complete effects ledger only.
  --no-pre-commit                   Do not newly wire the warn-only hook. On an upgrade,
                                    an unchanged hook already owned by the adoption lock
                                    is retained; this option is not an uninstall command.
  --with-pre-push                   Also wire the explicit blocking pre-push hook.
  -h, --help                        Show this help.

The target directory must already exist. A short, consumer-neutral AGENTS.md is created
only when the target has no AGENTS.md; existing AGENTS.md and CLAUDE.md files remain
project-owned and are never modified. Existing differing project files are reported as
conflicts and are never overwritten. Existing
.codex/hooks.json or .claude/settings.json files must be reconciled explicitly rather
than black-box merged. A pre-existing custom pre-commit hook is preserved; an
explicitly requested pre-push conflict is a hard stop. Preflight-detected conflicts
abort before installer-managed writes, but process interruption and concurrent target
mutation are not transactionally rolled back.
EOF
}

die() {
  printf '%s\n' "full-opt: $*" >&2
  exit 2
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    die "no SHA-256 implementation is available"
  fi
}

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    die "no SHA-256 implementation is available"
  fi
}

file_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  elif stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    die "cannot read POSIX file mode: $1"
  fi
}

file_link_count() {
  if stat -f '%l' "$1" >/dev/null 2>&1; then
    stat -f '%l' "$1"
  elif stat -c '%h' "$1" >/dev/null 2>&1; then
    stat -c '%h' "$1"
  else
    die "cannot read file link count: $1"
  fi
}

reject_hardlinked_file() {
  candidate=$1
  [ ! -e "$candidate" ] || [ ! -f "$candidate" ] \
    || [ "$(file_link_count "$candidate")" = 1 ] \
    || die "refusing to manage a multiply linked file: $candidate"
}

record_path_state() {
  path=$1
  output=$2
  if [ -L "$path" ]; then
    printf 'symlink\n' > "$output"
  elif [ ! -e "$path" ]; then
    printf 'absent\n' > "$output"
  elif [ -f "$path" ]; then
    printf 'file\t%s\t%s\t%s\n' \
      "$(sha256_file "$path")" "$(file_mode "$path")" "$(file_link_count "$path")" \
      > "$output"
  else
    printf 'other\n' > "$output"
  fi
}

path_state_matches() {
  path=$1
  expected=$2
  current=$tmp/current-path-state
  record_path_state "$path" "$current"
  cmp -s "$expected" "$current"
}

files_match() {
  [ -f "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] \
    && [ "$(file_link_count "$2")" = 1 ] \
    && cmp -s "$1" "$2" \
    && [ "$(file_mode "$1")" = "$(file_mode "$2")" ]
}

test_interrupt() {
  point=$1
  [ "${FI_TEST_INTERRUPT_AFTER:-}" = "$point" ] || return 0
  printf '%s\n' "full-opt: test interruption at $point" >&2
  exit 86
}

runtime=
target=
dry_run=0
pre_commit_disabled=0
install_pre_commit=0
install_pre_push=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime)
      [ "$#" -ge 2 ] || die "--runtime requires codex, claude, or both"
      runtime=$2
      shift 2
      ;;
    --full-opt)
      shift
      ;;
    --core|--with-fitness|--with-hooks|--with-orchestration)
      die "$1 is not supported; full-opt is the only payload"
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --no-pre-commit)
      pre_commit_disabled=1
      shift
      ;;
    --with-pre-push)
      install_pre_push=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *)
      [ -z "$target" ] || die "only one TARGET may be supplied"
      target=$1
      shift
      ;;
  esac
done

[ "$pre_commit_disabled" = 1 ] || {
  install_pre_commit=1
}
components=full-opt

case "$runtime" in codex|claude|both) ;; *) die "--runtime codex|claude|both is required" ;; esac
[ -n "$target" ] || die "TARGET is required"
[ -d "$target" ] || die "target directory does not exist: $target"

target=$(CDPATH= cd -- "$target" && pwd)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-full-opt.XXXXXX")
install_lock=
install_lock_acquired=0
install_lock_owner=
install_lock_expected=$tmp/install-lock-owner
migration_journal_tmp=
adoption_pending_tmp=
printf 'pid=%s\ntmp=%s\n' "$$" "$tmp" > "$install_lock_expected"
cleanup() {
  if [ -n "$migration_journal_tmp" ] && [ -f "$migration_journal_tmp" ] \
    && [ ! -L "$migration_journal_tmp" ]; then
    rm -f "$migration_journal_tmp"
  fi
  if [ -n "$adoption_pending_tmp" ] && [ -f "$adoption_pending_tmp" ] \
    && [ ! -L "$adoption_pending_tmp" ]; then
    rm -f "$adoption_pending_tmp"
  fi
  if [ "$install_lock_acquired" = 1 ] && [ -n "$install_lock" ] && [ -d "$install_lock" ]; then
    if [ -n "$install_lock_owner" ] && [ -f "$install_lock_owner" ] \
      && [ ! -L "$install_lock_owner" ] \
      && cmp -s "$install_lock_expected" "$install_lock_owner"; then
      rm -f "$install_lock_owner"
      rmdir "$install_lock" 2>/dev/null || true
    fi
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM
if [ "$dry_run" = 0 ]; then
  install_lock=$target/.foundation-integrity-install.lock
  [ ! -L "$install_lock" ] || die "refusing a symlinked installation lock: $install_lock"
  mkdir "$install_lock" 2>/dev/null \
    || die "another adoption may be running, or a stale lock exists: $install_lock"
  install_lock_acquired=1
  install_lock_owner=$install_lock/owner
  cp "$install_lock_expected" "$install_lock_owner" \
    || die "could not record installation lock ownership: $install_lock_owner"
fi
stage=$tmp/stage
manifest=$tmp/manifest.tsv
managed_skill_roots=$tmp/managed-skill-roots
tab=$(printf '\t')
codex_hook_root=.codex/hooks/scripts
claude_hook_root=.claude/hooks/scripts
git_hook_stage_root=
mkdir -p "$stage"
: > "$manifest"
: > "$managed_skill_roots"

stage_file() {
  source_file=$1
  relative=$2
  [ -f "$source_file" ] || die "missing distribution file: $source_file"
  mkdir -p "$stage/$(dirname -- "$relative")"
  cp -p "$source_file" "$stage/$relative"
}

stage_tree() {
  source_dir=$1
  relative_root=$2
  [ -d "$source_dir" ] || die "missing distribution directory: $source_dir"
  if find "$source_dir" -type l -print | grep -q .; then
    die "distribution tree contains a symlink and cannot be copied safely: $source_dir"
  fi
  find "$source_dir" -type f -print | sort > "$tmp/tree-files"
  while IFS= read -r source_file; do
    relative=${source_file#"$source_dir"/}
    stage_file "$source_file" "$relative_root/$relative"
  done < "$tmp/tree-files"
}

count_skills() {
  find "$1" -name SKILL.md -type f | wc -l | tr -d ' '
}

register_skill_roots() {
  source_skills=$1
  relative_root=$2
  find "$source_skills" -name SKILL.md -type f -print | sort > "$tmp/skill-files"
  while IFS= read -r skill_file; do
    skill_dir=$(dirname -- "${skill_file#"$source_skills"/}")
    printf '%s\n' "$relative_root/$skill_dir" >> "$managed_skill_roots"
  done < "$tmp/skill-files"
}

case "$runtime" in
  codex)
    [ "$(count_skills "$source_root/.agents/skills")" = 24 ] || die "Codex projection does not contain 24 skills"
    stage_tree "$source_root/.agents/skills" .agents/skills
    register_skill_roots "$source_root/.agents/skills" .agents/skills
    ;;
  claude)
    [ "$(count_skills "$source_root/.claude/skills")" = 24 ] || die "Claude projection does not contain 24 skills"
    stage_tree "$source_root/.claude/skills" .claude/skills
    register_skill_roots "$source_root/.claude/skills" .claude/skills
    ;;
  both)
    [ "$(count_skills "$source_root/.agents/skills")" = 24 ] || die "Codex projection does not contain 24 skills"
    [ "$(count_skills "$source_root/.claude/skills")" = 24 ] || die "Claude projection does not contain 24 skills"
    stage_tree "$source_root/.agents/skills" .agents/skills
    stage_tree "$source_root/.claude/skills" .claude/skills
    register_skill_roots "$source_root/.agents/skills" .agents/skills
    register_skill_roots "$source_root/.claude/skills" .claude/skills
    ;;
esac

# Project conventions. Enumerate exactly four consumer docs so a future repository-
# only document cannot silently enter the adoption payload. AGENTS.md is a separate,
# conditional bootstrap instruction file.
if [ ! -e "$target/AGENTS.md" ] && [ ! -L "$target/AGENTS.md" ]; then
  stage_file "$source_root/templates/setup/AGENTS.md" AGENTS.md
fi
stage_file "$source_root/docs/agents/domain.md" docs/agents/domain.md
stage_file "$source_root/docs/agents/triage-labels.md" docs/agents/triage-labels.md
stage_file "$source_root/templates/setup/docs-agents-foundation.md" docs/agents/foundation.md
remote=$(git -C "$target" remote get-url origin 2>/dev/null || true)
slug=
case "$remote" in
  git@github.com:*) slug=${remote#git@github.com:} ;;
  https://github.com/*) slug=${remote#https://github.com/} ;;
  http://github.com/*) slug=${remote#http://github.com/} ;;
  ssh://git@github.com/*) slug=${remote#ssh://git@github.com/} ;;
esac
slug=${slug%.git}
case "$slug" in
  */*/*|/*|*/|*[!A-Za-z0-9._/-]*) slug= ;;
esac
case "$slug" in */*)
  tracker_description="This repository uses GitHub Issues for \`$slug\`, derived from the \`origin\` remote."
  tracker_command="Use \`gh issue\` commands for issue reads and writes when an external issue is the canonical source."
  ;;
*)
  tracker_description="The canonical issue tracker is not configured yet. Replace this paragraph before using issue-backed workflows."
  tracker_command="Record the provider, project identity, and read/write command or connector here; do not guess from an issue number alone."
  ;;
esac
awk -v description="$tracker_description" -v command="$tracker_command" '
  $0 == "{{TRACKER_DESCRIPTION}}" { print description; next }
  $0 == "{{TRACKER_COMMAND}}" { print command; next }
  { print }
' "$source_root/templates/setup/docs-agents-issue-tracker.md" \
  > "$stage/docs/agents/issue-tracker.md"

# Adopt project material at its final owner; no top-level templates/ tree is copied.
stage_file "$source_root/docs/adr/0000-template.md" docs/adr/0000-template.md
stage_file "$source_root/docs/foundation/foundation-audit.md" docs/foundation/foundation-audit.md
stage_file "$source_root/docs/foundation/foundation-pattern-language.md" docs/foundation/foundation-pattern-language.md
stage_file "$source_root/docs/foundation/why-foundation-integrity.md" docs/foundation/why-foundation-integrity.md

stage_tree "$source_root/templates/fitness" docs/foundation/fitness

stage_runtime_hook_scripts() {
  hook_root=$1
  stage_file "$source_root/templates/hooks/foundation-surface.txt" "$hook_root/foundation-surface.txt"
  stage_tree "$source_root/templates/hooks/scripts" "$hook_root"
}

stage_git_hook_scripts() {
  hook_root=$1
  stage_tree "$source_root/templates/hooks/git" "$hook_root/git"
}

stage_file "$source_root/templates/hooks/README.md" docs/foundation/hooks.md
stage_file "$source_root/templates/hooks/review-receipt.md" docs/foundation/review-receipt.md
case "$runtime" in
  codex)
    stage_runtime_hook_scripts "$codex_hook_root"
    stage_git_hook_scripts "$codex_hook_root"
    git_hook_stage_root=$codex_hook_root
    stage_file "$source_root/templates/hooks/codex-hooks.json" .codex/hooks.json
    ;;
  claude)
    stage_runtime_hook_scripts "$claude_hook_root"
    stage_git_hook_scripts "$claude_hook_root"
    git_hook_stage_root=$claude_hook_root
    stage_file "$source_root/templates/hooks/claude-settings.json" .claude/settings.json
    ;;
  both)
    stage_runtime_hook_scripts "$codex_hook_root"
    stage_runtime_hook_scripts "$claude_hook_root"
    stage_git_hook_scripts "$codex_hook_root"
    git_hook_stage_root=$codex_hook_root
    stage_file "$source_root/templates/hooks/codex-hooks.json" .codex/hooks.json
    stage_file "$source_root/templates/hooks/claude-settings.json" .claude/settings.json
    ;;
esac

for shared in README.md coworker-protocol.md model-role-policy.md pilot-run-receipt.md \
  task-packet.md weak-foundation-benchmark.md; do
  stage_file "$source_root/templates/orchestration/$shared" ".orchestration/foundation/$shared"
done
stage_tree "$source_root/templates/orchestration/scripts" .orchestration/foundation/scripts
stage_tree "$source_root/templates/orchestration/roles" .orchestration/foundation/roles
case "$runtime" in
    codex)
      stage_file "$source_root/templates/orchestration/runtime/codex.md" \
        .orchestration/foundation/runtime/codex.md
      stage_tree "$source_root/templates/orchestration/profiles/codex" \
        .orchestration/foundation/profiles/codex
      ;;
    claude)
      stage_file "$source_root/templates/orchestration/runtime/claude.md" \
        .orchestration/foundation/runtime/claude.md
      stage_tree "$source_root/templates/orchestration/profiles/claude" \
        .orchestration/foundation/profiles/claude
      ;;
    both)
      stage_file "$source_root/templates/orchestration/runtime/codex.md" \
        .orchestration/foundation/runtime/codex.md
      stage_file "$source_root/templates/orchestration/runtime/claude.md" \
        .orchestration/foundation/runtime/claude.md
      stage_tree "$source_root/templates/orchestration/profiles/codex" \
        .orchestration/foundation/profiles/codex
      stage_tree "$source_root/templates/orchestration/profiles/claude" \
        .orchestration/foundation/profiles/claude
      ;;
esac

marker_count() {
  awk -v marker="$2" '$0 == marker { count++ } END { print count + 0 }' "$1"
}

extract_existing_block() {
  current=$1
  begin=$2
  end=$3
  output=$4
  [ -f "$current" ] && [ ! -L "$current" ] || return 1
  [ "$(marker_count "$current" "$begin")" = 1 ] \
    && [ "$(marker_count "$current" "$end")" = 1 ] || return 1
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { inside = 1 }
    inside { print }
    $0 == end { closed = 1; exit }
    END { if (!closed) exit 1 }
  ' "$current" > "$output"
}

merge_marked_block() {
  current=$1
  block=$2
  begin=$3
  end=$4
  output=$5

  [ ! -L "$current" ] || die "refusing to merge a symlinked file: $current"
  if [ ! -e "$current" ]; then
    cp "$block" "$output"
    return
  fi
  [ -f "$current" ] && [ ! -L "$current" ] || die "refusing to merge a non-regular or symlinked file: $current"
  begins=$(marker_count "$current" "$begin")
  ends=$(marker_count "$current" "$end")
  if [ "$begins" = 0 ] && [ "$ends" = 0 ]; then
    awk '1; END { if (NR > 0) print "" }' "$current" > "$output"
    sed -n '1,$p' "$block" >> "$output"
    return
  fi
  [ "$begins" = 1 ] && [ "$ends" = 1 ] || die "partial or duplicate managed markers in $current"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { if (inside || seen) exit 1; inside = 1; seen = 1; next }
    $0 == end { if (!inside) exit 1; inside = 0; next }
    END { if (!seen || inside) exit 1 }
  ' "$current" || die "managed markers are out of order in $current"
  awk -v begin="$begin" -v end="$end" -v block="$block" '
    function emit(line) {
      while ((getline line < block) > 0) print line
      close(block)
    }
    $0 == begin { emit(); inside = 1; next }
    $0 == end { inside = 0; next }
    !inside { print }
  ' "$current" > "$output"
}

ignore_block=$tmp/ignore-block
awk '
  $0 == "# BEGIN foundation-integrity generated state" { inside = 1 }
  inside { print }
  $0 == "# END foundation-integrity generated state" { exit }
' "$source_root/templates/gitignore/foundation-integrity.gitignore" > "$ignore_block"
[ "$(marker_count "$ignore_block" '# BEGIN foundation-integrity generated state')" = 1 ] || die "ignore source block is invalid"
[ "$(marker_count "$ignore_block" '# END foundation-integrity generated state')" = 1 ] || die "ignore source block is invalid"
ignore_file=$target/.gitignore
reject_hardlinked_file "$ignore_file"
ignore_preflight_state=$tmp/ignore-preflight-state
record_path_state "$ignore_file" "$ignore_preflight_state"
ignore_desired=$tmp/gitignore
merge_marked_block "$ignore_file" "$ignore_block" \
  '# BEGIN foundation-integrity generated state' \
  '# END foundation-integrity generated state' "$ignore_desired"

reject_symlink_parent() {
  destination=$1
  parent=$(dirname -- "$destination")
  while [ "$parent" != "$target" ] && [ "$parent" != / ]; do
    [ ! -L "$parent" ] || die "refusing to traverse symlinked target directory: $parent"
    parent=$(dirname -- "$parent")
  done
}

adoption_relative=.foundation-integrity/adoption.tsv
adoption_file=$target/$adoption_relative
adoption_preflight_state=$tmp/adoption-preflight-state
old_adoption=
adoption_schema=
v2_pending_journal_hash=
v2_pending_plan_hash=
pending_migration_plan=$tmp/pending-migration-plan.tsv
: > "$pending_migration_plan"
migration_journal_relative=.foundation/migrations/foundation-integrity-v2-v3.tsv
migration_journal=$target/$migration_journal_relative
managed_path_allowed() {
  case "$1" in
    AGENTS.md|.agents/skills/*|.claude/skills/*|docs/agents/*|docs/adr/0000-template.md|docs/foundation/*|.foundation-integrity/hooks/*|.codex/hooks.json|.codex/hooks/scripts/*|.claude/settings.json|.claude/hooks/scripts/*|.orchestration/foundation/*) return 0 ;;
    templates/adr/*|templates/docs/*|templates/fitness/*|templates/hooks/*|templates/orchestration/*|templates/setup/AGENTS.md|templates/setup/check-credential-permissions.sh|templates/setup/resolve-instruction-target.sh|CLAUDE.md) return 0 ;;
    .git/hooks/pre-commit|.git/hooks/pre-push) return 0 ;;
    *) return 1 ;;
  esac
}
[ ! -L "$adoption_file" ] || die "refusing a symlinked adoption lock: $adoption_file"
reject_hardlinked_file "$adoption_file"
record_path_state "$adoption_file" "$adoption_preflight_state"
if [ -e "$adoption_file" ]; then
  [ -f "$adoption_file" ] || die "adoption lock is not a regular file: $adoption_file"
  adoption_schema=$(sed -n '1s/^# foundation-integrity-adoption://p' "$adoption_file")
  case "$adoption_schema" in
    v2|v3) ;;
    *) die "adoption lock has an unsupported schema: $adoption_file" ;;
  esac
  awk -F '\t' -v schema="$adoption_schema" '
    NR == 1 { next }
    /^#/ || NF == 0 { next }
    $1 == "setting" {
      if (NF != 3 || $2 == "" || $3 == "" || seen[$1 FS $2]++) exit 1
      if ($2 == "distribution-version" || $2 == "source-repository" \
        || $2 == "source-ref" || $2 == "source-revision" \
        || $2 == "source-tree-state" || $2 == "content-sha256" \
        || $2 == "payload-sha256" || $2 == "runtime" \
        || $2 == "components" || $2 == "ignore-block-sha256") next
      if (schema == "v2" && ($2 == "instruction-target" \
        || $2 == "instruction-block-sha256" \
        || $2 == "pending-v3-journal-sha256" \
        || $2 == "pending-v3-plan-sha256")) next
      exit 1
    }
    $1 == "pending-add" || $1 == "pending-remove" {
      if (schema != "v2" || NF != 4 || length($2) != 64 || $2 !~ /^[0-9A-Fa-f]+$/) exit 1
      if ($3 !~ /^[0-7][0-7][0-7]$/ || $4 == "") exit 1
      if ($4 ~ /^\// || $4 ~ /(^|\/)\.\.(\/|$)/ || $4 ~ /\/\//) exit 1
      if (pending_path[$4]++) exit 1
      next
    }
    $1 == "file" || $1 == "hook" || $1 == "external" {
      if (NF != 3 || length($2) != 64 || $2 !~ /^[0-9A-Fa-f]+$/ || $3 == "") exit 1
      if ($3 ~ /^\// || $3 ~ /(^|\/)\.\.(\/|$)/ || $3 ~ /\/\//) exit 1
      if (seen[$1 FS $3]++) exit 1
      managed[$3]++
      next
    }
    $1 == "mode" {
      if (NF != 3 || $2 !~ /^[0-7][0-7][0-7]$/ || $3 == "") exit 1
      if ($3 ~ /^\// || $3 ~ /(^|\/)\.\.(\/|$)/ || $3 ~ /\/\//) exit 1
      if (seen[$1 FS $3]++) exit 1
      modes[$3]++
      next
    }
    { exit 1 }
    END {
      for (path in managed) if (managed[path] != 1 || modes[path] != 1) exit 1
      for (path in modes) if (modes[path] != 1 || managed[path] != 1) exit 1
    }
  ' "$adoption_file" || die "adoption lock is malformed or has duplicate records: $adoption_file"
  if [ "$adoption_schema" = v2 ]; then
    v2_pending_journal_hash=$(awk -F '\t' \
      '$1 == "setting" && $2 == "pending-v3-journal-sha256" { print $3; exit }' \
      "$adoption_file")
    v2_pending_plan_hash=$(awk -F '\t' \
      '$1 == "setting" && $2 == "pending-v3-plan-sha256" { print $3; exit }' \
      "$adoption_file")
    if [ -n "$v2_pending_journal_hash" ]; then
      case "$v2_pending_journal_hash" in
        *[!0-9A-Fa-f]*) die "adoption lock contains a non-hex pending migration binding" ;;
      esac
      [ "${#v2_pending_journal_hash}" = 64 ] \
        || die "adoption lock contains an invalid pending migration binding length"
      case "$v2_pending_plan_hash" in
        *[!0-9A-Fa-f]*) die "adoption lock contains a non-hex pending plan binding" ;;
      esac
      [ "${#v2_pending_plan_hash}" = 64 ] \
        || die "adoption lock contains an invalid pending plan binding length"
      awk -F '\t' \
        '$1 == "setting" && ($2 == "pending-v3-journal-sha256" || $2 == "pending-v3-plan-sha256") { next } \
         $1 == "pending-add" || $1 == "pending-remove" { next } { print }' \
        "$adoption_file" > "$tmp/old-adoption.tsv"
      awk -F '\t' -v OFS='\t' \
        '$1 == "pending-add" { $1 = "add"; print } \
         $1 == "pending-remove" { $1 = "remove"; print }' \
        "$adoption_file" | LC_ALL=C sort > "$pending_migration_plan"
      while IFS="$tab" read -r pending_operation pending_hash pending_mode pending_path; do
        [ -n "$pending_path" ] || continue
        managed_path_allowed "$pending_path" \
          || die "adoption lock pending plan contains an out-of-scope path: $pending_path"
      done < "$pending_migration_plan"
      [ "$(sha256_file "$pending_migration_plan")" = "$v2_pending_plan_hash" ] \
        || die "adoption lock pending operation plan does not match its binding"
    else
      [ -z "$v2_pending_plan_hash" ] \
        || die "adoption lock contains a pending plan without a pending journal binding"
      if awk -F '\t' '$1 == "pending-add" || $1 == "pending-remove" { found = 1 } END { exit !found }' \
        "$adoption_file"; then
        die "adoption lock contains pending operations without a pending journal binding"
      fi
      cp "$adoption_file" "$tmp/old-adoption.tsv"
    fi
  else
    if awk -F '\t' '$1 == "setting" && ($2 == "pending-v3-journal-sha256" || $2 == "pending-v3-plan-sha256") \
      || $1 == "pending-add" || $1 == "pending-remove" { found = 1 } END { exit !found }' \
      "$adoption_file"; then
      die "v3 adoption lock contains a pending migration binding"
    fi
    cp "$adoption_file" "$tmp/old-adoption.tsv"
  fi
  old_adoption=$tmp/old-adoption.tsv
  awk -F '\t' '$1 == "file" { print $3 }' "$old_adoption" > "$tmp/old-managed-paths"
  while IFS= read -r old_path; do
    managed_path_allowed "$old_path" || die "adoption lock contains an out-of-scope managed path: $old_path"
  done < "$tmp/old-managed-paths"
  awk -F '\t' '$1 == "external" { print $3 }' "$old_adoption" > "$tmp/old-external-paths"
  while IFS= read -r old_path; do
    managed_path_allowed "$old_path" || die "adoption lock contains an out-of-scope external path: $old_path"
    case "$old_path" in
      .agents/skills/*|.claude/skills/*) die "adoption lock cannot mark a managed skill file as external: $old_path" ;;
    esac
  done < "$tmp/old-external-paths"
  awk -F '\t' '$1 == "hook" { print $3 }' "$old_adoption" > "$tmp/old-managed-hooks"
  while IFS= read -r old_hook; do
    case "$old_hook" in
      .git/hooks/pre-commit|.git/hooks/pre-push) ;;
      *) die "adoption lock contains an out-of-scope hook path: $old_hook" ;;
    esac
  done < "$tmp/old-managed-hooks"

  old_setting() {
    awk -F '\t' -v key="$1" '$1 == "setting" && $2 == key { print $3; exit }' "$old_adoption"
  }
  old_payload_expected=$(old_setting payload-sha256)
  old_distribution_version=$(old_setting distribution-version)
  old_source_repository=$(old_setting source-repository)
  old_source_ref=$(old_setting source-ref)
  old_source_revision=$(old_setting source-revision)
  old_source_tree_state=$(old_setting source-tree-state)
  old_content_sha256=$(old_setting content-sha256)
  old_runtime=$(old_setting runtime)
  old_components=$(old_setting components)
  old_ignore_hash=$(old_setting ignore-block-sha256)
  old_instruction_target=
  old_instruction_hash=
  if [ "$adoption_schema" = v2 ]; then
    old_instruction_target=$(old_setting instruction-target)
    old_instruction_hash=$(old_setting instruction-block-sha256)
  fi
  for required_value in "$old_payload_expected" "$old_distribution_version" \
    "$old_source_repository" "$old_source_ref" "$old_source_revision" "$old_source_tree_state" \
    "$old_content_sha256" "$old_runtime" "$old_components" "$old_ignore_hash"; do
    [ -n "$required_value" ] || die "adoption lock is missing a payload-binding setting"
  done
  if [ "$adoption_schema" = v2 ]; then
    [ -n "$old_instruction_target" ] && [ -n "$old_instruction_hash" ] \
      || die "adoption lock is missing its legacy instruction binding"
  fi
  case "$old_payload_expected$old_content_sha256$old_instruction_hash$old_ignore_hash" in
    *[!0-9A-Fa-f]*) die "adoption lock contains a non-hex payload binding" ;;
  esac
  [ "${#old_payload_expected}" = 64 ] && [ "${#old_content_sha256}" = 64 ] \
    && [ "${#old_ignore_hash}" = 64 ] \
    || die "adoption lock contains an invalid payload-binding length"
  if [ "$adoption_schema" = v2 ]; then
    [ "${#old_instruction_hash}" = 64 ] \
      || die "adoption lock contains an invalid legacy instruction binding length"
  fi
  {
    printf 'runtime\t%s\n' "$old_runtime"
    printf 'components\t%s\n' "$old_components"
    awk -F '\t' '$1 == "file" || $1 == "hook" || $1 == "external" || $1 == "mode" { print }' "$old_adoption"
    if [ "$adoption_schema" = v2 ]; then
      printf 'instruction-block\t%s\t%s\n' "$old_instruction_hash" "$old_instruction_target"
    fi
    printf 'ignore-block\t%s\t.gitignore\n' "$old_ignore_hash"
  } > "$tmp/old-content-records.tsv"
  old_content_actual=$(LC_ALL=C sort "$tmp/old-content-records.tsv" | sha256_stream)
  [ "$old_content_actual" = "$old_content_sha256" ] \
    || die "adoption lock content digest does not match its managed records"
  {
    sed -n '1,$p' "$tmp/old-content-records.tsv"
    printf 'distribution-version\t%s\n' "$old_distribution_version"
    printf 'source-repository\t%s\n' "$old_source_repository"
    printf 'source-ref\t%s\n' "$old_source_ref"
    printf 'source-revision\t%s\n' "$old_source_revision"
    printf 'source-tree-state\t%s\n' "$old_source_tree_state"
    printf 'content-sha256\t%s\n' "$old_content_sha256"
  } > "$tmp/old-payload-records.tsv"
  old_payload_actual=$(LC_ALL=C sort "$tmp/old-payload-records.tsv" | sha256_stream)
  [ "$old_payload_actual" = "$old_payload_expected" ] \
    || die "adoption lock payload digest does not match its managed records"

  extract_existing_block "$ignore_file" '# BEGIN foundation-integrity generated state' \
    '# END foundation-integrity generated state' "$tmp/current-ignore-block" \
    || die "previous managed ignore block is missing or malformed"
  current_ignore_hash=$(sha256_file "$tmp/current-ignore-block")
  if [ "$current_ignore_hash" != "$old_ignore_hash" ]; then
    [ "$adoption_schema" = v2 ] && [ -n "$v2_pending_journal_hash" ] \
      && [ "$current_ignore_hash" = "$(sha256_file "$ignore_block")" ] \
      || die "previous managed ignore block was edited; reconcile it explicitly before upgrade"
  fi
else
  if [ -e "$ignore_file" ] \
    && { [ "$(marker_count "$ignore_file" '# BEGIN foundation-integrity generated state')" -ne 0 ] \
      || [ "$(marker_count "$ignore_file" '# END foundation-integrity generated state')" -ne 0 ]; }; then
    extract_existing_block "$ignore_file" '# BEGIN foundation-integrity generated state' \
      '# END foundation-integrity generated state' "$tmp/unowned-ignore-block" \
      || die "pre-existing Foundation Integrity ignore markers are malformed and have no adoption lock"
    cmp -s "$tmp/unowned-ignore-block" "$ignore_block" \
      || die "pre-existing Foundation Integrity ignore block differs and has no adoption lock; reconcile it explicitly before adoption"
  fi
fi

migration_journal_preflight_state=$tmp/migration-journal-preflight-state
migration_recovery=0
migration_journal_cleanup=0
migration_journal_expected_hash=
reject_symlink_parent "$migration_journal"
[ ! -L "$migration_journal" ] \
  || die "refusing a symlinked migration journal: $migration_journal"
reject_hardlinked_file "$migration_journal"
record_path_state "$migration_journal" "$migration_journal_preflight_state"
if [ -e "$migration_journal" ]; then
  [ -f "$migration_journal" ] \
    || die "migration journal is not a regular file: $migration_journal"
  awk -F '\t' '
    NR == 1 {
      if ($0 != "# foundation-integrity-v2-v3-migration:v1") exit 1
      next
    }
    $1 == "setting" {
      if (NF != 3 || $2 == "" || $3 == "" || seen_setting[$2]++) exit 1
      if ($2 != "old-adoption-sha256" && $2 != "desired-adoption-sha256" \
        && $2 != "payload-sha256" && $2 != "plan-sha256" \
        && $2 != "instruction-disposition" && $2 != "instruction-target" \
        && $2 != "instruction-block-sha256") exit 1
      settings[$2] = $3
      next
    }
    $1 == "add" || $1 == "remove" {
      if (NF != 4 || length($2) != 64 || $2 !~ /^[0-9A-Fa-f]+$/) exit 1
      if ($3 !~ /^[0-7][0-7][0-7]$/ || $4 == "") exit 1
      if ($4 ~ /^\// || $4 ~ /(^|\/)\.\.(\/|$)/ || $4 ~ /\/\//) exit 1
      if (seen_path[$4]++) exit 1
      next
    }
    /^#/ || NF == 0 { next }
    { exit 1 }
    END {
      required["old-adoption-sha256"] = 1
      required["desired-adoption-sha256"] = 1
      required["payload-sha256"] = 1
      required["plan-sha256"] = 1
      required["instruction-disposition"] = 1
      required["instruction-target"] = 1
      required["instruction-block-sha256"] = 1
      for (key in required) if (!(key in settings)) exit 1
    }
  ' "$migration_journal" \
    || die "migration journal is malformed: $migration_journal"
  journal_setting() {
    awk -F '\t' -v key="$1" \
      '$1 == "setting" && $2 == key { print $3; exit }' "$migration_journal"
  }
  journal_old_adoption_hash=$(journal_setting old-adoption-sha256)
  journal_desired_adoption_hash=$(journal_setting desired-adoption-sha256)
  journal_payload_hash=$(journal_setting payload-sha256)
  journal_plan_hash=$(journal_setting plan-sha256)
  journal_instruction_disposition=$(journal_setting instruction-disposition)
  journal_instruction_target=$(journal_setting instruction-target)
  journal_instruction_hash=$(journal_setting instruction-block-sha256)
  case "$journal_old_adoption_hash$journal_desired_adoption_hash$journal_payload_hash$journal_plan_hash$journal_instruction_hash" in
    *[!0-9A-Fa-f]*) die "migration journal contains a non-hex binding" ;;
  esac
  [ "${#journal_old_adoption_hash}" = 64 ] \
    && [ "${#journal_desired_adoption_hash}" = 64 ] \
    && [ "${#journal_payload_hash}" = 64 ] \
    && [ "${#journal_plan_hash}" = 64 ] \
    && [ "${#journal_instruction_hash}" = 64 ] \
    || die "migration journal contains an invalid binding length"
  journal_operations=$tmp/migration-journal-operations.tsv
  awk -F '\t' '$1 == "add" || $1 == "remove" { print }' "$migration_journal" \
    | LC_ALL=C sort > "$journal_operations"
  while IFS="$tab" read -r operation operation_hash operation_mode operation_path; do
    [ -n "$operation_path" ] || continue
    managed_path_allowed "$operation_path" \
      || die "migration journal contains an out-of-scope path: $operation_path"
  done < "$journal_operations"
  [ "$(sha256_file "$journal_operations")" = "$journal_plan_hash" ] \
    || die "migration journal operation digest does not match its records"
  if [ "$adoption_schema" = v2 ] && [ -n "$v2_pending_journal_hash" ]; then
    [ "$journal_plan_hash" = "$v2_pending_plan_hash" ] \
      || die "migration journal plan is not bound by the v2 adoption lock"
    cmp -s "$journal_operations" "$pending_migration_plan" \
      || die "migration journal operations do not match the v2 adoption plan"
  fi
  [ "$journal_instruction_disposition" = preserve-and-transfer-to-project ] \
    || die "migration journal has an unsupported instruction disposition"
  case "$journal_instruction_target" in AGENTS.md|CLAUDE.md) ;; *)
    die "migration journal has an invalid instruction target"
  esac
  migration_journal_expected_hash=$(sha256_file "$migration_journal")
  case "$adoption_schema" in
    v2)
      [ -n "$v2_pending_journal_hash" ] \
        || die "migration journal is not bound by the current v2 adoption lock"
      [ "$migration_journal_expected_hash" = "$v2_pending_journal_hash" ] \
        || die "migration journal does not match the v2 adoption binding"
      [ "$journal_old_adoption_hash" = "$(sha256_file "$old_adoption")" ] \
        || die "migration journal does not bind the pre-migration v2 adoption lock"
      [ "$journal_instruction_target" = "$old_instruction_target" ] \
        && [ "$journal_instruction_hash" = "$old_instruction_hash" ] \
        || die "migration journal does not bind the v2 instruction disposition"
      migration_recovery=1
      ;;
    v3)
      [ "$journal_desired_adoption_hash" = "$(sha256_file "$adoption_file")" ] \
        || die "completed migration journal does not bind the current v3 adoption lock"
      migration_journal_cleanup=1
      ;;
    *) die "migration journal exists without a supported adoption lock" ;;
  esac
fi
if [ "$adoption_schema" = v2 ] && [ -n "$v2_pending_journal_hash" ] \
  && [ ! -e "$migration_journal" ]; then
  die "v2 adoption lock has a pending migration binding but its journal is missing"
fi

old_managed_hash() {
  kind=$1
  relative=$2
  [ -n "$old_adoption" ] || return 0
  awk -F '\t' -v kind="$kind" -v relative="$relative" \
    '$1 == kind && $3 == relative { print $2; exit }' "$old_adoption"
}

old_managed_mode() {
  relative=$1
  [ -n "$old_adoption" ] || return 0
  awk -F '\t' -v relative="$relative" \
    '$1 == "mode" && $3 == relative { print $2; exit }' "$old_adoption"
}

matches_old_managed() {
  kind=$1
  relative=$2
  destination=$3
  old_hash=$(old_managed_hash "$kind" "$relative")
  old_mode=$(old_managed_mode "$relative")
  [ -n "$old_hash" ] && [ -n "$old_mode" ] \
    && [ -f "$destination" ] && [ ! -L "$destination" ] \
    && [ "$(file_link_count "$destination")" = 1 ] \
    && [ "$(sha256_file "$destination")" = "$old_hash" ] \
    && [ "$(file_mode "$destination")" = "$old_mode" ]
}

if [ -n "$old_adoption" ]; then
  awk -F '\t' '
    $1 == "file" && ($3 ~ /^\.agents\/skills\// || $3 ~ /^\.claude\/skills\//) \
      && $3 ~ /\/SKILL\.md$/ {
        path = $3
        sub(/\/SKILL\.md$/, "", path)
        print path
      }
  ' "$old_adoption" >> "$managed_skill_roots"
fi

old_directory_implied() {
  relative_dir=$1
  [ -n "$old_adoption" ] || return 1
  awk -F '\t' -v prefix="$relative_dir/" '
    $1 == "file" && index($3, prefix) == 1 { found = 1; exit }
    END { exit !found }
  ' "$old_adoption"
}

identical_path_is_owned() {
  relative=$1
  case "$relative" in
    .agents/skills/*|.claude/skills/*) return 0 ;;
  esac
  [ -n "$(old_managed_hash file "$relative")" ]
}

pending_plan_add_is_owned() {
  relative=$1
  staged=$2
  [ "$migration_recovery" = 1 ] || return 1
  journal_hash=$(awk -F '\t' -v relative="$relative" \
    '$1 == "add" && $4 == relative { print $2; exit }' "$pending_migration_plan")
  journal_mode=$(awk -F '\t' -v relative="$relative" \
    '$1 == "add" && $4 == relative { print $3; exit }' "$pending_migration_plan")
  [ -n "$journal_hash" ] && [ -n "$journal_mode" ] \
    && [ "$(sha256_file "$staged")" = "$journal_hash" ] \
    && [ "$(file_mode "$staged")" = "$journal_mode" ]
}

pending_plan_has_add() {
  relative=$1
  [ "$migration_recovery" = 1 ] || return 1
  awk -F '\t' -v relative="$relative" '
    $1 == "add" && $4 == relative { found = 1; exit }
    END { exit !found }
  ' "$pending_migration_plan"
}

conflicts=0
find "$stage" -type f -print | sort > "$tmp/staged-files"
while IFS= read -r staged; do
  relative=${staged#"$stage"/}
  destination=$target/$relative
  reject_symlink_parent "$destination"
  if [ -L "$destination" ]; then
    printf 'conflict\t%s\n' "$relative" >> "$manifest"
    conflicts=$((conflicts + 1))
  elif [ ! -e "$destination" ]; then
    printf 'add\t%s\n' "$relative" >> "$manifest"
  elif files_match "$staged" "$destination"; then
    if pending_plan_add_is_owned "$relative" "$staged"; then
      printf 'unchanged\t%s\n' "$relative" >> "$manifest"
    elif [ "$adoption_schema" = v2 ] && [ -z "$(old_managed_hash file "$relative")" ] \
      && [ "$relative" != .gitignore ] \
      && [ "$relative" != .foundation-integrity/adoption.tsv ]; then
      # A v2-to-v3 retry cannot distinguish a file left by an interrupted v3
      # migration from an identical consumer-owned file. Refuse to guess; keep
      # the v2 ledger authoritative until the owner reconciles the path.
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    elif identical_path_is_owned "$relative"; then
      printf 'unchanged\t%s\n' "$relative" >> "$manifest"
    else
      printf 'external-identical\t%s\n' "$relative" >> "$manifest"
    fi
  elif [ -f "$destination" ]; then
    if matches_old_managed file "$relative" "$destination"; then
      printf 'update-managed\t%s\n' "$relative" >> "$manifest"
    else
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    fi
  else
    printf 'conflict\t%s\n' "$relative" >> "$manifest"
    conflicts=$((conflicts + 1))
  fi
done < "$tmp/staged-files"

if [ -n "$old_adoption" ]; then
  awk -F '\t' '$1 == "file" { print $3 }' "$old_adoption" > "$tmp/old-managed-paths"
  while IFS= read -r relative; do
    [ -f "$stage/$relative" ] && continue
    # Instruction files are project-owned in v3. Preserve any v2-managed CLAUDE.md
    # byte-for-byte and transfer its ownership to the project; never remove or
    # rewrite a live instruction path during migration.
    case "$relative" in
      AGENTS.md|CLAUDE.md)
      continue
      ;;
    esac
    destination=$target/$relative
    reject_symlink_parent "$destination"
    if [ -L "$destination" ]; then
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    elif [ ! -e "$destination" ]; then
      : # already absent; the new lock will forget it
    elif matches_old_managed file "$relative" "$destination"; then
      printf 'remove-managed\t%s\n' "$relative" >> "$manifest"
    else
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    fi
  done < "$tmp/old-managed-paths"
fi

# A consumer may own unrelated skills beside this pack. Inside each of the 24 managed
# skill directories, however, the selected runtime projection must be exact: no stale
# files, empty directories, symlinks, or metadata from the other runtime may survive
# an adoption. Old directories implied by the previous file ledger may be removed only
# after every contained path passes the same ownership preflight.
remove_managed_dirs=$tmp/remove-managed-dirs
: > "$remove_managed_dirs"
sort -u "$managed_skill_roots" -o "$managed_skill_roots"
while IFS= read -r relative_root; do
  managed_target=$target/$relative_root
  reject_symlink_parent "$managed_target"
  if [ -L "$managed_target" ] || { [ -e "$managed_target" ] && [ ! -d "$managed_target" ]; }; then
    printf 'conflict\t%s\n' "$relative_root" >> "$manifest"
    conflicts=$((conflicts + 1))
    continue
  fi
  [ -d "$managed_target" ] || continue
  find "$managed_target" \( -type f -o -type l \) -print | sort > "$tmp/managed-target-files"
  while IFS= read -r target_file; do
    relative=${target_file#"$target"/}
    if [ -L "$target_file" ]; then
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    elif [ ! -f "$stage/$relative" ]; then
      if ! matches_old_managed file "$relative" "$target_file"; then
        printf 'conflict\t%s\n' "$relative" >> "$manifest"
        conflicts=$((conflicts + 1))
      fi
    fi
  done < "$tmp/managed-target-files"
  find "$managed_target" ! -type f ! -type d ! -type l -print > "$tmp/managed-special-files"
  while IFS= read -r special; do
    [ -n "$special" ] || continue
    printf 'conflict\t%s\n' "${special#"$target"/}" >> "$manifest"
    conflicts=$((conflicts + 1))
  done < "$tmp/managed-special-files"
  find "$managed_target" -type d -print | sort > "$tmp/managed-target-dirs"
  while IFS= read -r target_dir; do
    relative=${target_dir#"$target"/}
    [ -d "$stage/$relative" ] && continue
    if old_directory_implied "$relative"; then
      printf '%s\n' "$relative" >> "$remove_managed_dirs"
    else
      printf 'conflict\t%s\n' "$relative" >> "$manifest"
      conflicts=$((conflicts + 1))
    fi
  done < "$tmp/managed-target-dirs"
done < "$managed_skill_roots"
sort -u "$remove_managed_dirs" -o "$remove_managed_dirs"

desired_action() {
  destination=$1
  desired=$2
  [ ! -L "$destination" ] || die "refusing to manage a symlinked destination: $destination"
  if [ ! -e "$destination" ]; then
    printf '%s' add
  elif cmp -s "$desired" "$destination"; then
    printf '%s' unchanged
  else
    printf '%s' update-owned-block
  fi
}

ignore_action=$(desired_action "$ignore_file" "$ignore_desired")

hook_mode=project-runtime
pre_commit_action=disabled
pre_push_action=not-installed
git_hooks_dir=
old_pre_commit_hash=$(old_managed_hash hook .git/hooks/pre-commit)
old_pre_push_hash=$(old_managed_hash hook .git/hooks/pre-push)
if [ "$install_pre_commit" = 1 ] || [ "$install_pre_push" = 1 ] \
  || [ -n "$old_pre_commit_hash" ] || [ -n "$old_pre_push_hash" ]; then
  if [ -L "$target/.git" ]; then
    die "refusing automatic hook wiring through a symlinked target/.git; rerun with --no-pre-commit to copy assets only"
  elif [ ! -d "$target/.git" ]; then
    pre_commit_action=skipped-nonstandard-git-dir
    [ "$install_pre_push" = 0 ] || die "--with-pre-push requires a normal target/.git directory; wire the copied sample manually"
  elif [ -n "$(git -C "$target" config --get core.hooksPath 2>/dev/null || true)" ]; then
    pre_commit_action=skipped-custom-hooks-path
    [ "$install_pre_push" = 0 ] || die "--with-pre-push will not mutate a configured core.hooksPath; wire the copied sample manually"
  elif [ -L "$target/.git/hooks" ]; then
    die "refusing automatic hook wiring through a symlinked .git/hooks; rerun with --no-pre-commit to copy assets only"
  else
    git_hooks_dir=$target/.git/hooks
    hook_mode=normal-git-dir
    if [ "$install_pre_commit" = 1 ]; then
      if [ ! -e "$git_hooks_dir/pre-commit" ] && [ ! -L "$git_hooks_dir/pre-commit" ]; then
        pre_commit_action=add-warn-only
      elif pending_plan_has_add .git/hooks/pre-commit; then
        if files_match "$stage/$git_hook_stage_root/git/pre-commit" "$git_hooks_dir/pre-commit"; then
          pre_commit_action=unchanged
        elif matches_old_managed hook .git/hooks/pre-commit "$git_hooks_dir/pre-commit"; then
          pre_commit_action=update-managed
        else
          die "v2-ledger-proven pre-commit hook changed before recovery"
        fi
      elif [ -L "$git_hooks_dir/pre-commit" ]; then
        pre_commit_action=preserved-existing-hook
      elif files_match "$stage/$git_hook_stage_root/git/pre-commit" "$git_hooks_dir/pre-commit"; then
        if [ -n "$old_pre_commit_hash" ]; then
          pre_commit_action=unchanged
        else
          pre_commit_action=preserved-identical-hook
        fi
      else
        if matches_old_managed hook .git/hooks/pre-commit "$git_hooks_dir/pre-commit"; then
          pre_commit_action=update-managed
        else
          pre_commit_action=preserved-existing-hook
        fi
      fi
    elif [ -n "$old_pre_commit_hash" ] \
      && matches_old_managed hook .git/hooks/pre-commit "$git_hooks_dir/pre-commit"; then
      pre_commit_action=retained-managed-warn-only
    elif [ -n "$old_pre_commit_hash" ] && [ -e "$git_hooks_dir/pre-commit" ]; then
      pre_commit_action=preserved-existing-hook
    fi
    if [ "$install_pre_push" = 1 ]; then
      if [ ! -e "$git_hooks_dir/pre-push" ] && [ ! -L "$git_hooks_dir/pre-push" ]; then
        pre_push_action=add-blocking
      elif pending_plan_has_add .git/hooks/pre-push; then
        if files_match "$stage/$git_hook_stage_root/git/pre-push" "$git_hooks_dir/pre-push"; then
          pre_push_action=unchanged
        elif matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push"; then
          pre_push_action=update-managed
        else
          die "v2-ledger-proven pre-push hook changed before recovery"
        fi
      elif [ -L "$git_hooks_dir/pre-push" ]; then
        die "existing pre-push hook is a symlink; refusing to replace or claim ownership"
      elif files_match "$stage/$git_hook_stage_root/git/pre-push" "$git_hooks_dir/pre-push"; then
        if [ -n "$old_pre_push_hash" ]; then
          pre_push_action=unchanged
        else
          pre_push_action=preserved-identical-hook
        fi
      else
        if matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push"; then
          pre_push_action=update-managed
        else
          die "existing pre-push hook differs; refusing to replace it after --with-pre-push"
        fi
      fi
    elif [ -n "$old_pre_push_hash" ] \
      && matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push"; then
      pre_push_action=retained-managed-blocking
    elif [ -n "$old_pre_push_hash" ] && [ -e "$git_hooks_dir/pre-push" ]; then
      pre_push_action=preserved-existing-hook
    fi
  fi
fi

migration_plan_hash=
if [ "$adoption_schema" = v2 ]; then
  migration_plan=$tmp/migration-plan.tsv
  : > "$migration_plan"
  while IFS= read -r staged; do
    relative=${staged#"$stage"/}
    action=$(awk -F '\t' -v relative="$relative" '$2 == relative { print $1; exit }' "$manifest")
    if [ "$action" = add ] || pending_plan_add_is_owned "$relative" "$staged"; then
      printf 'add\t%s\t%s\t%s\n' \
        "$(sha256_file "$staged")" "$(file_mode "$staged")" "$relative" >> "$migration_plan"
    fi
  done < "$tmp/staged-files"
  while IFS= read -r relative; do
    case "$relative" in
      AGENTS.md|CLAUDE.md) continue ;;
    esac
    [ -f "$stage/$relative" ] && continue
    printf 'remove\t%s\t%s\t%s\n' \
      "$(old_managed_hash file "$relative")" "$(old_managed_mode "$relative")" "$relative" >> "$migration_plan"
  done < "$tmp/old-managed-paths"
  case "$pre_commit_action" in
    add-warn-only|update-managed|unchanged)
      if [ "$pre_commit_action" != unchanged ] || pending_plan_has_add .git/hooks/pre-commit; then
        printf 'add\t%s\t755\t.git/hooks/pre-commit\n' \
          "$(sha256_file "$stage/$git_hook_stage_root/git/pre-commit")" >> "$migration_plan"
      fi
      ;;
  esac
  case "$pre_push_action" in
    add-blocking|update-managed|unchanged)
      if [ "$pre_push_action" != unchanged ] || pending_plan_has_add .git/hooks/pre-push; then
        printf 'add\t%s\t755\t.git/hooks/pre-push\n' \
          "$(sha256_file "$stage/$git_hook_stage_root/git/pre-push")" >> "$migration_plan"
      fi
      ;;
  esac
  LC_ALL=C sort -u "$migration_plan" -o "$migration_plan"
  migration_plan_hash=$(sha256_file "$migration_plan")
  if [ "$migration_recovery" = 1 ]; then
    cmp -s "$pending_migration_plan" "$migration_plan" \
      || die "v2 adoption operation plan does not match the current migration plan"
  fi
fi

reject_symlink_parent "$adoption_file"
payload_records=$tmp/payload-records.tsv
: > "$payload_records"
printf 'runtime\t%s\n' "$runtime" >> "$payload_records"
printf 'components\t%s\n' "$components" >> "$payload_records"
while IFS= read -r staged; do
  relative=${staged#"$stage"/}
  record_kind=file
  action=$(awk -F '\t' -v relative="$relative" '$2 == relative { print $1; exit }' "$manifest")
  [ "$action" != external-identical ] || record_kind=external
  printf '%s\t%s\t%s\n' "$record_kind" "$(sha256_file "$staged")" "$relative" >> "$payload_records"
  printf 'mode\t%s\t%s\n' "$(file_mode "$staged")" "$relative" >> "$payload_records"
done < "$tmp/staged-files"
ignore_block_hash=$(sha256_file "$ignore_block")
printf 'ignore-block\t%s\t.gitignore\n' "$ignore_block_hash" >> "$payload_records"
case "$pre_commit_action" in
  add-warn-only|unchanged|update-managed|retained-managed-warn-only)
    printf 'hook\t%s\t.git/hooks/pre-commit\n' \
      "$(sha256_file "$stage/$git_hook_stage_root/git/pre-commit")" >> "$payload_records"
    printf 'mode\t755\t.git/hooks/pre-commit\n' >> "$payload_records"
    ;;
esac
case "$pre_push_action" in
  add-blocking|unchanged|update-managed|retained-managed-blocking)
    printf 'hook\t%s\t.git/hooks/pre-push\n' \
      "$(sha256_file "$stage/$git_hook_stage_root/git/pre-push")" >> "$payload_records"
    printf 'mode\t755\t.git/hooks/pre-push\n' >> "$payload_records"
    ;;
esac
content_sha256=$(LC_ALL=C sort "$payload_records" | sha256_stream)
source_revision=${FI_SOURCE_REVISION:-$(git -C "$source_root" rev-parse HEAD 2>/dev/null || printf '%s' unversioned)}
version_file=$source_root/VERSION
[ -f "$version_file" ] && [ ! -L "$version_file" ] \
  || die "source tree is missing the regular VERSION file"
distribution_version=$(tr -d '\r\n' < "$version_file")
[ -n "$distribution_version" ] \
  || die "source VERSION is empty"
printf '%s\n' "$distribution_version" | awk -F '.' '
  NF == 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ { valid = 1 }
  END { exit !valid }
' || die "source VERSION must contain one semantic version"
source_repository=${FI_SOURCE_REPOSITORY:-}
if [ -z "$source_repository" ]; then
  source_repository=$(git -C "$source_root" remote get-url origin 2>/dev/null || printf '')
fi
[ -n "$source_repository" ] \
  || die "source repository is unknown; set FI_SOURCE_REPOSITORY or configure origin"
source_ref=${FI_SOURCE_REF:-local}
if [ -n "${FI_SOURCE_TREE_STATE:-}" ]; then
  source_tree_state=$FI_SOURCE_TREE_STATE
elif git -C "$source_root" status --porcelain --untracked-files=all 2>/dev/null | grep -q .; then
  source_tree_state=dirty
else
  source_tree_state=clean
fi
printf 'distribution-version\t%s\n' "$distribution_version" >> "$payload_records"
printf 'source-repository\t%s\n' "$source_repository" >> "$payload_records"
printf 'source-ref\t%s\n' "$source_ref" >> "$payload_records"
printf 'source-revision\t%s\n' "$source_revision" >> "$payload_records"
printf 'source-tree-state\t%s\n' "$source_tree_state" >> "$payload_records"
printf 'content-sha256\t%s\n' "$content_sha256" >> "$payload_records"
payload_sha256=$(LC_ALL=C sort "$payload_records" | sha256_stream)
adoption_desired=$tmp/adoption.tsv
{
  printf '# foundation-integrity-adoption:v3\n'
  printf 'setting\tdistribution-version\t%s\n' "$distribution_version"
  printf 'setting\tsource-repository\t%s\n' "$source_repository"
  printf 'setting\tsource-ref\t%s\n' "$source_ref"
  printf 'setting\tsource-revision\t%s\n' "$source_revision"
  printf 'setting\tsource-tree-state\t%s\n' "$source_tree_state"
  printf 'setting\tcontent-sha256\t%s\n' "$content_sha256"
  printf 'setting\tpayload-sha256\t%s\n' "$payload_sha256"
  printf 'setting\truntime\t%s\n' "$runtime"
  printf 'setting\tcomponents\t%s\n' "$components"
  printf 'setting\tignore-block-sha256\t%s\n' "$ignore_block_hash"
  awk -F '\t' '$1 == "file" || $1 == "hook" || $1 == "external" || $1 == "mode" { print }' "$payload_records"
} > "$adoption_desired"

if [ ! -e "$adoption_file" ]; then
  adoption_action=add
elif cmp -s "$adoption_desired" "$adoption_file"; then
  adoption_action=unchanged
else
  adoption_action=update-owned-lock
fi

adds=$(awk -F '\t' '$1 == "add" { n++ } END { print n + 0 }' "$manifest")
updates=$(awk -F '\t' '$1 == "update-managed" { n++ } END { print n + 0 }' "$manifest")
removals=$(awk -F '\t' '$1 == "remove-managed" { n++ } END { print n + 0 }' "$manifest")
unchanged=$(awk -F '\t' '$1 == "unchanged" { n++ } END { print n + 0 }' "$manifest")
external_identical=$(awk -F '\t' '$1 == "external-identical" { n++ } END { print n + 0 }' "$manifest")
directory_removals=$(awk 'NF { n++ } END { print n + 0 }' "$remove_managed_dirs")

printf '%s\n' "Foundation Integrity full-opt effects ledger"
printf '  target: %s\n' "$target"
printf '  runtime projection: %s (all 24 managed pack skills per selected runtime)\n' "$runtime"
printf '  components: %s\n' "$components"
printf '  project files: %s add, %s managed update, %s managed removal, %s managed unchanged, %s external-identical, %s conflict\n' \
  "$adds" "$updates" "$removals" "$unchanged" "$external_identical" "$conflicts"
printf '  external-identical files: verified but not claimed for future update/removal\n'
printf '  managed skill directories: %s ledger-implied empty removal\n' "$directory_removals"
printf '  instructions: generic AGENTS.md created only when absent; existing AGENTS.md and CLAUDE.md preserved\n'
if [ "$adoption_schema" = v2 ]; then
  printf '  legacy instruction ownership: preserve bytes and transfer to project (%s)\n' \
    "$old_instruction_target"
  if [ "$migration_recovery" = 1 ]; then
    printf '  migration recovery: resume only v2-ledger-proven v3 additions\n'
  else
    printf '  migration recovery: write a digest-bound v2-to-v3 journal before mutation\n'
  fi
elif [ "$migration_journal_cleanup" = 1 ]; then
  printf '  migration recovery: remove the committed journal after postconditions\n'
fi
printf '  ignore rules: %s -> .gitignore\n' "$ignore_action"
printf '  docs/agents: four files; tracker customized from origin when possible\n'
printf '  project layout: no templates copied; legacy v2 files retire only when owned (empty directories are preserved)\n'
printf '  git pre-commit: %s (warn-only when added)\n' "$pre_commit_action"
printf '  git pre-push: %s (blocking only when explicitly requested)\n' "$pre_push_action"
printf '  runtime hooks: project-scoped config installed for %s; existing config is never merged or overwritten\n' "$runtime"
if [ "$runtime" = both ]; then
  printf '  git hook authority: adoption ledger selects the byte-identical Codex copy; pre-push blocks on divergence\n'
fi
printf '  Codex trust: project hooks remain skipped until reviewed/trusted with /hooks\n'
printf '  orchestration: static policy at .orchestration/foundation; only %s runtime profiles selected\n' "$runtime"
printf '  orchestration state: live output stays in sessions or an explicit temporary directory\n'
printf '  research payload: none copied; docs/research remains ignored working state\n'
printf '  source-only merge template: the gitignore block is not duplicated\n'
printf '  adoption lock: %s -> %s (source ref/revision, components, payload digest, managed hashes/modes)\n' \
  "$adoption_action" "$adoption_relative"
printf '  apply serialization: transient token-owned target lock; cooperating installers only\n'
printf '  git hook mode: %s\n' "$hook_mode"

if [ "$conflicts" -ne 0 ]; then
  printf '%s\n' "full-opt: refusing to overwrite differing files:" >&2
  awk -F '\t' '$1 == "conflict" { print "  - " $2 }' "$manifest" >&2
  exit 4
fi

if [ "$adoption_schema" = v2 ]; then
  if [ "$migration_recovery" = 1 ]; then
    [ "$journal_desired_adoption_hash" = "$(sha256_file "$adoption_desired")" ] \
      || die "migration journal payload no longer matches the current v3 adoption"
    [ "$journal_payload_hash" = "$payload_sha256" ] \
      || die "migration journal payload digest no longer matches the current source"
  elif [ "$dry_run" = 0 ]; then
    while IFS="$tab" read -r action relative; do
      [ "$action" = add ] || continue
      destination=$target/$relative
      [ ! -e "$destination" ] && [ ! -L "$destination" ] \
        || die "migration journal preflight found a changed add path: $relative"
    done < "$manifest"
    migration_journal_desired=$tmp/migration-journal.tsv
    {
      printf '# foundation-integrity-v2-v3-migration:v1\n'
      printf 'setting\told-adoption-sha256\t%s\n' "$(sha256_file "$old_adoption")"
      printf 'setting\tdesired-adoption-sha256\t%s\n' "$(sha256_file "$adoption_desired")"
      printf 'setting\tpayload-sha256\t%s\n' "$payload_sha256"
      printf 'setting\tplan-sha256\t%s\n' "$migration_plan_hash"
      printf 'setting\tinstruction-disposition\tpreserve-and-transfer-to-project\n'
      printf 'setting\tinstruction-target\t%s\n' "$old_instruction_target"
      printf 'setting\tinstruction-block-sha256\t%s\n' "$old_instruction_hash"
      cat "$migration_plan"
    } > "$migration_journal_desired"
    path_state_matches "$migration_journal" "$migration_journal_preflight_state" \
      || die "migration journal changed after preflight"
    migration_journal_dir=$(dirname -- "$migration_journal")
    mkdir -p "$migration_journal_dir"
    migration_journal_tmp=$migration_journal.tmp.$$
    [ ! -e "$migration_journal_tmp" ] || die "migration journal temporary path already exists"
    cp "$migration_journal_desired" "$migration_journal_tmp"
    mv "$migration_journal_tmp" "$migration_journal"
    migration_journal_tmp=
    migration_journal_expected_hash=$(sha256_file "$migration_journal")

    # The journal is only a transaction log. Bind it to the still-authoritative
    # v2 adoption lock before any payload or hook mutation can occur. Recovery
    # refuses an unbound/planted journal, so a journal cannot grant ownership to
    # an identical consumer-owned path by itself.
    path_state_matches "$adoption_file" "$adoption_preflight_state" \
      || die "adoption lock changed before pending migration binding"
    adoption_pending_desired=$tmp/adoption-pending.tsv
    {
      cat "$old_adoption"
      printf 'setting\tpending-v3-journal-sha256\t%s\n' "$migration_journal_expected_hash"
      printf 'setting\tpending-v3-plan-sha256\t%s\n' "$migration_plan_hash"
      awk -F '\t' -v OFS='\t' '$1 == "add" { $1 = "pending-add"; print } \
        $1 == "remove" { $1 = "pending-remove"; print }' "$migration_plan"
    } > "$adoption_pending_desired"
    adoption_pending_tmp=$adoption_file.tmp.$$
    [ ! -e "$adoption_pending_tmp" ] || die "adoption pending temporary path already exists"
    cp "$adoption_pending_desired" "$adoption_pending_tmp"
    mv "$adoption_pending_tmp" "$adoption_file"
    adoption_pending_tmp=
    record_path_state "$adoption_file" "$adoption_preflight_state"
  fi
fi

if [ "$dry_run" = 1 ]; then
  exit 0
fi

applied_add=0
while IFS="$tab" read -r action relative; do
  destination=$target/$relative
  case "$action" in
    add)
      reject_symlink_parent "$destination"
      [ ! -e "$destination" ] && [ ! -L "$destination" ] \
        || die "path changed after preflight; refusing add: $relative"
      mkdir -p "$(dirname -- "$destination")"
      cp -p "$stage/$relative" "$destination"
      if [ "$applied_add" = 0 ]; then
        applied_add=1
        test_interrupt after-first-add
      fi
      ;;
    update-managed)
      reject_symlink_parent "$destination"
      matches_old_managed file "$relative" "$destination" \
        || die "path changed after preflight; refusing managed update: $relative"
      cp -p "$stage/$relative" "$destination"
      ;;
    remove-managed)
      reject_symlink_parent "$destination"
      matches_old_managed file "$relative" "$destination" \
        || die "path changed after preflight; refusing managed removal: $relative"
      rm -f "$destination"
      ;;
  esac
done < "$manifest"
test_interrupt after-managed-actions

awk '{ path = $0; depth = gsub(/\//, "/", path); print depth "\t" $0 }' \
  "$remove_managed_dirs" | sort -rn -k1,1 | cut -f2- > "$tmp/remove-managed-dirs-deepest-first"
while IFS= read -r relative; do
  [ -n "$relative" ] || continue
  [ -e "$target/$relative" ] || continue
  [ -d "$target/$relative" ] && [ ! -L "$target/$relative" ] \
    || die "managed directory changed after preflight: $relative"
  rmdir "$target/$relative" \
    || die "managed directory was not empty after owned file removal: $relative"
done < "$tmp/remove-managed-dirs-deepest-first"

case "$ignore_action" in
  add|update-owned-block)
    path_state_matches "$ignore_file" "$ignore_preflight_state" \
      || die "ignore file changed after preflight: .gitignore"
    cp "$ignore_desired" "$ignore_file"
    ;;
esac

if [ "$pre_commit_action" = add-warn-only ] || [ "$pre_commit_action" = update-managed ]; then
  if [ "$pre_commit_action" = add-warn-only ]; then
    [ ! -e "$git_hooks_dir/pre-commit" ] && [ ! -L "$git_hooks_dir/pre-commit" ] \
      || die "pre-commit changed after preflight; refusing add"
  else
    matches_old_managed hook .git/hooks/pre-commit "$git_hooks_dir/pre-commit" \
      || die "pre-commit changed after preflight; refusing managed update"
  fi
  mkdir -p "$git_hooks_dir"
  cp -p "$stage/$git_hook_stage_root/git/pre-commit" "$git_hooks_dir/pre-commit"
  chmod +x "$git_hooks_dir/pre-commit"
fi
if [ "$pre_commit_action" = remove-managed ]; then
  matches_old_managed hook .git/hooks/pre-commit "$git_hooks_dir/pre-commit" \
    || die "pre-commit changed after preflight; refusing managed removal"
  rm -f "$git_hooks_dir/pre-commit"
fi
if [ "$pre_push_action" = add-blocking ] || [ "$pre_push_action" = update-managed ]; then
  if [ "$pre_push_action" = add-blocking ]; then
    [ ! -e "$git_hooks_dir/pre-push" ] && [ ! -L "$git_hooks_dir/pre-push" ] \
      || die "pre-push changed after preflight; refusing add"
  else
    matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push" \
      || die "pre-push changed after preflight; refusing managed update"
  fi
  mkdir -p "$git_hooks_dir"
  cp -p "$stage/$git_hook_stage_root/git/pre-push" "$git_hooks_dir/pre-push"
  chmod +x "$git_hooks_dir/pre-push"
fi
if [ "$pre_push_action" = remove-managed ]; then
  matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push" \
    || die "pre-push changed after preflight; refusing managed removal"
  rm -f "$git_hooks_dir/pre-push"
fi

# Detect a concurrent mutation or an incomplete copy before reporting success. The
# v2-to-v3 journal supports bounded retry provenance; it is not rollback or an atomic
# commit for arbitrary filesystem failures.
while IFS= read -r staged_file; do
  relative=${staged_file#"$stage"/}
  files_match "$staged_file" "$target/$relative" \
    || die "staged file postcondition failed: $relative"
done < "$tmp/staged-files"

extract_existing_block "$ignore_file" '# BEGIN foundation-integrity generated state' \
  '# END foundation-integrity generated state' "$tmp/final-ignore-block" \
  && cmp -s "$tmp/final-ignore-block" "$ignore_block" \
  || die "managed ignore block postcondition failed: .gitignore"

awk -F '\t' '$1 == "hook" { print $2 "\t" $3 }' "$adoption_desired" \
  > "$tmp/final-hook-records"
while IFS="$tab" read -r expected_hash relative; do
  [ -n "$relative" ] || continue
  expected_mode=$(awk -F '\t' -v relative="$relative" \
    '$1 == "mode" && $3 == relative { print $2; exit }' "$adoption_desired")
  [ -f "$target/$relative" ] && [ ! -L "$target/$relative" ] \
    && [ "$(sha256_file "$target/$relative")" = "$expected_hash" ] \
    && [ "$(file_mode "$target/$relative")" = "$expected_mode" ] \
    || die "managed hook postcondition failed: $relative"
done < "$tmp/final-hook-records"

while IFS= read -r relative_root; do
  if [ ! -d "$stage/$relative_root" ]; then
    [ ! -e "$target/$relative_root" ] \
      || die "removed managed skill directory still exists: $relative_root"
    continue
  fi
  find "$stage/$relative_root" -type f -print | sort > "$tmp/managed-stage-files"
  while IFS= read -r staged_file; do
    relative=${staged_file#"$stage"/}
    files_match "$staged_file" "$target/$relative" \
      || die "managed skill postcondition failed: $relative"
  done < "$tmp/managed-stage-files"
  find "$target/$relative_root" \( -type f -o -type l \) -print | sort > "$tmp/managed-final-files"
  while IFS= read -r target_file; do
    relative=${target_file#"$target"/}
    [ -f "$stage/$relative" ] && [ ! -L "$target_file" ] \
      || die "unexpected file in managed skill directory after install: $relative"
  done < "$tmp/managed-final-files"
  find "$stage/$relative_root" -type d -print | sort > "$tmp/managed-stage-dirs"
  while IFS= read -r staged_dir; do
    relative=${staged_dir#"$stage"/}
    [ -d "$target/$relative" ] && [ ! -L "$target/$relative" ] \
      || die "managed skill directory postcondition failed: $relative"
  done < "$tmp/managed-stage-dirs"
  find "$target/$relative_root" -type d -print | sort > "$tmp/managed-final-dirs"
  while IFS= read -r target_dir; do
    relative=${target_dir#"$target"/}
    [ -d "$stage/$relative" ] \
      || die "unexpected directory in managed skill projection: $relative"
  done < "$tmp/managed-final-dirs"
done < "$managed_skill_roots"

test_interrupt before-adoption-commit
path_state_matches "$adoption_file" "$adoption_preflight_state" \
  || die "adoption lock changed after preflight: $adoption_relative"
case "$adoption_action" in
  add|update-owned-lock)
    mkdir -p "$(dirname -- "$adoption_file")"
    cp "$adoption_desired" "$adoption_file"
    ;;
esac
[ -f "$adoption_file" ] && [ ! -L "$adoption_file" ] \
  && cmp -s "$adoption_desired" "$adoption_file" \
  || die "adoption lock postcondition failed: $adoption_relative"

if [ -e "$migration_journal" ]; then
  [ -n "$migration_journal_expected_hash" ] \
    && [ -f "$migration_journal" ] && [ ! -L "$migration_journal" ] \
    && [ "$(file_link_count "$migration_journal")" = 1 ] \
    && [ "$(sha256_file "$migration_journal")" = "$migration_journal_expected_hash" ] \
    || die "migration journal changed before completion"
  rm -f "$migration_journal"
fi

printf '%s\n' "full-opt: complete"
