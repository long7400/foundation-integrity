#!/bin/sh
# Transparent full repository adoption for Foundation Integrity.
#
# This installer copies inert project assets, merges two marked blocks, and may wire
# the warn-only git pre-commit hook. It never installs plugins, changes user/global
# runtime configuration, activates orchestration, or overwrites an unowned file.
set -eu

usage() {
  cat >&2 <<'EOF'
Usage:
  sh templates/setup/full-opt.sh --runtime codex|claude|both [options] TARGET

Options:
  --core                            Install skills, policy blocks, four project docs,
                                    compact docs/ADR, and setup helpers only.
  --full-opt                        Add fitness, hooks, and orchestration (default).
  --with-fitness                    Add the optional fitness templates.
  --with-hooks                      Add hook assets; implies fitness.
  --with-orchestration              Add inert coworker protocol/profiles.
  --dry-run                         Preview the complete effects ledger only.
  --instruction-target AGENTS.md   Resolve an otherwise ambiguous owner explicitly.
  --instruction-target CLAUDE.md
  --no-pre-commit                   Do not newly wire the warn-only hook. On an upgrade,
                                    an unchanged hook already owned by the adoption lock
                                    is retained; this option is not an uninstall command.
  --with-pre-push                   Also wire the explicit blocking pre-push hook.
  -h, --help                        Show this help.

The target directory must already exist. Existing differing project files are
reported as conflicts and are never overwritten. Existing managed markers without an
adoption lock are accepted only when their block is byte-identical to this
distribution. A pre-existing custom pre-commit hook is preserved; an explicitly
requested pre-push conflict is a hard stop. Preflight-detected conflicts abort before
installer-managed writes, but process interruption and concurrent target mutation are
not transactionally rolled back.
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

runtime=
target=
dry_run=0
preset=full-opt
preset_seen=
with_fitness=0
with_hooks=0
with_orchestration=0
install_fitness=0
install_hooks=0
install_orchestration=0
pre_commit_disabled=0
install_pre_commit=0
install_pre_push=0
instruction_target=

set_preset() {
  requested=$1
  if [ -n "$preset_seen" ] && [ "$preset_seen" != "$requested" ]; then
    die "choose only one of --core or --full-opt"
  fi
  preset=$requested
  preset_seen=$requested
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runtime)
      [ "$#" -ge 2 ] || die "--runtime requires codex, claude, or both"
      runtime=$2
      shift 2
      ;;
    --core)
      set_preset core
      shift
      ;;
    --full-opt)
      set_preset full-opt
      shift
      ;;
    --with-fitness)
      with_fitness=1
      shift
      ;;
    --with-hooks)
      with_hooks=1
      with_fitness=1
      shift
      ;;
    --with-orchestration)
      with_orchestration=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --instruction-target)
      [ "$#" -ge 2 ] || die "--instruction-target requires AGENTS.md or CLAUDE.md"
      instruction_target=$2
      shift 2
      ;;
    --no-pre-commit)
      pre_commit_disabled=1
      shift
      ;;
    --with-pre-push)
      with_hooks=1
      with_fitness=1
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

[ "$preset" != full-opt ] || {
  install_fitness=1
  install_hooks=1
  install_orchestration=1
}
[ "$with_fitness" = 0 ] || install_fitness=1
[ "$with_hooks" = 0 ] || {
  install_hooks=1
  install_fitness=1
}
[ "$with_orchestration" = 0 ] || install_orchestration=1

if [ "$install_hooks" = 1 ] && [ "$pre_commit_disabled" = 0 ]; then
  install_pre_commit=1
fi
components=core
[ "$install_fitness" = 0 ] || components=$components,fitness
[ "$install_hooks" = 0 ] || components=$components,hooks
[ "$install_orchestration" = 0 ] || components=$components,orchestration

case "$runtime" in codex|claude|both) ;; *) die "--runtime codex|claude|both is required" ;; esac
case "$instruction_target" in ""|AGENTS.md|CLAUDE.md) ;; *) die "instruction target must be AGENTS.md or CLAUDE.md" ;; esac
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
printf 'pid=%s\ntmp=%s\n' "$$" "$tmp" > "$install_lock_expected"
cleanup() {
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

# Project conventions. Enumerate exactly four consumer files so a future repository-
# only document cannot silently enter the adoption payload.
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

# Copy only the load-bearing, explicitly adopted template surfaces. The marked
# instruction and ignore source files are merged below and are not duplicated in the
# consumer repository.
stage_tree "$source_root/templates/adr" templates/adr
stage_tree "$source_root/templates/docs" templates/docs
[ "$install_fitness" = 0 ] || stage_tree "$source_root/templates/fitness" templates/fitness
[ "$install_hooks" = 0 ] || stage_tree "$source_root/templates/hooks" templates/hooks
[ "$install_orchestration" = 0 ] \
  || stage_tree "$source_root/templates/orchestration" templates/orchestration
stage_file "$source_root/templates/setup/check-credential-permissions.sh" templates/setup/check-credential-permissions.sh
stage_file "$source_root/templates/setup/resolve-instruction-target.sh" templates/setup/resolve-instruction-target.sh

resolve_rc=0
resolved=
if [ -n "$instruction_target" ]; then
  resolved=$instruction_target
else
  set +e
  resolved=$(sh "$source_root/templates/setup/resolve-instruction-target.sh" "$target")
  resolve_rc=$?
  set -e
  case "$resolve_rc" in
    0) ;;
    3)
      case "$runtime" in
        codex|both) resolved=AGENTS.md ;;
        claude) resolved=CLAUDE.md ;;
      esac
      ;;
    2) die "AGENTS.md and CLAUDE.md have ambiguous ownership; pass --instruction-target after reviewing both" ;;
    *) die "instruction owner resolver failed" ;;
  esac
fi

case "$runtime" in
  codex|both)
    [ "$resolved" = AGENTS.md ] || die "Codex requires the merged block in AGENTS.md; CLAUDE.md alone is not a Codex instruction owner"
    ;;
esac

claude_is_agents_shim() {
  [ -f "$target/CLAUDE.md" ] || return 1
  awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*# CLAUDE\.md[[:space:]]*$/ { next }
    /^[[:space:]]*@(\.\/)?AGENTS\.md[[:space:]]*$/ { imports++; next }
    { substantive = 1 }
    END { exit !(imports == 1 && !substantive) }
  ' "$target/CLAUDE.md"
}

case "$runtime" in
  claude|both)
    if [ "$resolved" = AGENTS.md ]; then
      if [ -e "$target/CLAUDE.md" ] && ! claude_is_agents_shim; then
        die "Claude would not load the chosen AGENTS.md owner because CLAUDE.md is substantive; reconcile it manually first"
      fi
      printf '# CLAUDE.md\n\n@AGENTS.md\n' > "$stage/CLAUDE.md"
    fi
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

case "$resolved" in
  AGENTS.md) other_instruction=CLAUDE.md ;;
  CLAUDE.md) other_instruction=AGENTS.md ;;
esac
other_instruction_file=$target/$other_instruction
if [ -L "$other_instruction_file" ]; then
  die "cannot prove a single instruction owner while the non-selected $other_instruction is a symlink"
elif [ -e "$other_instruction_file" ]; then
  [ -f "$other_instruction_file" ] \
    || die "non-selected instruction path is not a regular file: $other_instruction_file"
  other_begins=$(marker_count "$other_instruction_file" '<!-- BEGIN foundation-integrity -->')
  other_ends=$(marker_count "$other_instruction_file" '<!-- END foundation-integrity -->')
  if [ "$other_begins" -ne 0 ] || [ "$other_ends" -ne 0 ]; then
    die "non-selected $other_instruction already contains Foundation Integrity markers; reconcile to one instruction owner before adoption"
  fi
fi

instruction_file=$target/$resolved
reject_hardlinked_file "$instruction_file"
instruction_preflight_state=$tmp/instruction-preflight-state
record_path_state "$instruction_file" "$instruction_preflight_state"
instruction_desired=$tmp/instruction.md
merge_marked_block "$instruction_file" "$source_root/templates/claude-md-block.md" \
  '<!-- BEGIN foundation-integrity -->' '<!-- END foundation-integrity -->' \
  "$instruction_desired"

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
managed_path_allowed() {
  case "$1" in
    .agents/skills/*|.claude/skills/*|docs/agents/*|templates/adr/*|templates/docs/*|templates/fitness/*|templates/hooks/*|templates/orchestration/*|templates/setup/check-credential-permissions.sh|templates/setup/resolve-instruction-target.sh|CLAUDE.md) return 0 ;;
    *) return 1 ;;
  esac
}
[ ! -L "$adoption_file" ] || die "refusing a symlinked adoption lock: $adoption_file"
reject_hardlinked_file "$adoption_file"
record_path_state "$adoption_file" "$adoption_preflight_state"
if [ -e "$adoption_file" ]; then
  [ -f "$adoption_file" ] || die "adoption lock is not a regular file: $adoption_file"
  awk -F '\t' '
    NR == 1 { if ($0 != "# foundation-integrity-adoption:v2") exit 1; next }
    /^#/ || NF == 0 { next }
    $1 == "setting" { if (NF != 3 || $2 == "" || $3 == "" || seen[$1 FS $2]++) exit 1; next }
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
  old_adoption=$adoption_file
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
  old_instruction_target=$(old_setting instruction-target)
  old_instruction_hash=$(old_setting instruction-block-sha256)
  old_ignore_hash=$(old_setting ignore-block-sha256)
  for required_value in "$old_payload_expected" "$old_distribution_version" \
    "$old_source_repository" "$old_source_ref" "$old_source_revision" "$old_source_tree_state" \
    "$old_content_sha256" "$old_runtime" "$old_components" "$old_instruction_target" \
    "$old_instruction_hash" "$old_ignore_hash"; do
    [ -n "$required_value" ] || die "adoption lock is missing a payload-binding setting"
  done
  case "$old_payload_expected$old_content_sha256$old_instruction_hash$old_ignore_hash" in
    *[!0-9A-Fa-f]*) die "adoption lock contains a non-hex payload binding" ;;
  esac
  [ "${#old_payload_expected}" = 64 ] && [ "${#old_content_sha256}" = 64 ] \
    && [ "${#old_instruction_hash}" = 64 ] \
    && [ "${#old_ignore_hash}" = 64 ] \
    || die "adoption lock contains an invalid payload-binding length"
  {
    printf 'runtime\t%s\n' "$old_runtime"
    printf 'components\t%s\n' "$old_components"
    awk -F '\t' '$1 == "file" || $1 == "hook" || $1 == "external" || $1 == "mode" { print }' "$old_adoption"
    printf 'instruction-block\t%s\t%s\n' "$old_instruction_hash" "$old_instruction_target"
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

  [ "$old_instruction_target" = "$resolved" ] \
    || die "instruction owner changed from $old_instruction_target to $resolved; reconcile and remove the previous managed block explicitly before re-adopting"

  extract_existing_block "$instruction_file" '<!-- BEGIN foundation-integrity -->' \
    '<!-- END foundation-integrity -->' "$tmp/current-instruction-block" \
    || die "previous managed instruction block is missing or malformed"
  [ "$(sha256_file "$tmp/current-instruction-block")" = "$old_instruction_hash" ] \
    || die "previous managed instruction block was edited; reconcile it explicitly before upgrade"
  extract_existing_block "$ignore_file" '# BEGIN foundation-integrity generated state' \
    '# END foundation-integrity generated state' "$tmp/current-ignore-block" \
    || die "previous managed ignore block is missing or malformed"
  [ "$(sha256_file "$tmp/current-ignore-block")" = "$old_ignore_hash" ] \
    || die "previous managed ignore block was edited; reconcile it explicitly before upgrade"
else
  if [ -e "$instruction_file" ] \
    && { [ "$(marker_count "$instruction_file" '<!-- BEGIN foundation-integrity -->')" -ne 0 ] \
      || [ "$(marker_count "$instruction_file" '<!-- END foundation-integrity -->')" -ne 0 ]; }; then
    extract_existing_block "$instruction_file" '<!-- BEGIN foundation-integrity -->' \
      '<!-- END foundation-integrity -->' "$tmp/unowned-instruction-block" \
      || die "pre-existing Foundation Integrity instruction markers are malformed and have no adoption lock"
    cmp -s "$tmp/unowned-instruction-block" "$source_root/templates/claude-md-block.md" \
      || die "pre-existing Foundation Integrity instruction block differs and has no adoption lock; reconcile it explicitly before adoption"
  fi
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
    if identical_path_is_owned "$relative"; then
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

instruction_action=$(desired_action "$instruction_file" "$instruction_desired")
ignore_action=$(desired_action "$ignore_file" "$ignore_desired")

hook_mode=sample-only
pre_commit_action=disabled
pre_push_action=sample-only
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
      if [ -L "$git_hooks_dir/pre-commit" ]; then
        pre_commit_action=preserved-existing-hook
      elif [ ! -e "$git_hooks_dir/pre-commit" ]; then
        pre_commit_action=add-warn-only
      elif files_match "$stage/templates/hooks/git/pre-commit" "$git_hooks_dir/pre-commit"; then
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
      if [ "$install_hooks" = 0 ]; then
        pre_commit_action=remove-managed
      else
        pre_commit_action=retained-managed-warn-only
      fi
    elif [ -n "$old_pre_commit_hash" ] && [ -e "$git_hooks_dir/pre-commit" ]; then
      pre_commit_action=preserved-existing-hook
    fi
    if [ "$install_pre_push" = 1 ]; then
      if [ -L "$git_hooks_dir/pre-push" ]; then
        die "existing pre-push hook is a symlink; refusing to replace or claim ownership"
      elif [ ! -e "$git_hooks_dir/pre-push" ]; then
        pre_push_action=add-blocking
      elif files_match "$stage/templates/hooks/git/pre-push" "$git_hooks_dir/pre-push"; then
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
      if [ "$install_hooks" = 0 ]; then
        pre_push_action=remove-managed
      else
        pre_push_action=retained-managed-blocking
      fi
    elif [ -n "$old_pre_push_hash" ] && [ -e "$git_hooks_dir/pre-push" ]; then
      pre_push_action=preserved-existing-hook
    fi
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
instruction_block_hash=$(sha256_file "$source_root/templates/claude-md-block.md")
ignore_block_hash=$(sha256_file "$ignore_block")
printf 'instruction-block\t%s\t%s\n' "$instruction_block_hash" "$resolved" >> "$payload_records"
printf 'ignore-block\t%s\t.gitignore\n' "$ignore_block_hash" >> "$payload_records"
case "$pre_commit_action" in
  add-warn-only|unchanged|update-managed|retained-managed-warn-only)
    printf 'hook\t%s\t.git/hooks/pre-commit\n' \
      "$(sha256_file "$stage/templates/hooks/git/pre-commit")" >> "$payload_records"
    printf 'mode\t755\t.git/hooks/pre-commit\n' >> "$payload_records"
    ;;
esac
case "$pre_push_action" in
  add-blocking|unchanged|update-managed|retained-managed-blocking)
    printf 'hook\t%s\t.git/hooks/pre-push\n' \
      "$(sha256_file "$stage/templates/hooks/git/pre-push")" >> "$payload_records"
    printf 'mode\t755\t.git/hooks/pre-push\n' >> "$payload_records"
    ;;
esac
content_sha256=$(LC_ALL=C sort "$payload_records" | sha256_stream)
source_revision=${FI_SOURCE_REVISION:-$(git -C "$source_root" rev-parse HEAD 2>/dev/null || printf '%s' unversioned)}
distribution_version=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$source_root/.codex-plugin/plugin.json" | head -n1)
[ -n "$distribution_version" ] || distribution_version=unknown
source_repository=${FI_SOURCE_REPOSITORY:-$(sed -n 's/^[[:space:]]*"repository":[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$source_root/.codex-plugin/plugin.json" | head -n1)}
[ -n "$source_repository" ] || source_repository=unknown
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
  printf '# foundation-integrity-adoption:v2\n'
  printf 'setting\tdistribution-version\t%s\n' "$distribution_version"
  printf 'setting\tsource-repository\t%s\n' "$source_repository"
  printf 'setting\tsource-ref\t%s\n' "$source_ref"
  printf 'setting\tsource-revision\t%s\n' "$source_revision"
  printf 'setting\tsource-tree-state\t%s\n' "$source_tree_state"
  printf 'setting\tcontent-sha256\t%s\n' "$content_sha256"
  printf 'setting\tpayload-sha256\t%s\n' "$payload_sha256"
  printf 'setting\truntime\t%s\n' "$runtime"
  printf 'setting\tcomponents\t%s\n' "$components"
  printf 'setting\tinstruction-target\t%s\n' "$resolved"
  printf 'setting\tinstruction-block-sha256\t%s\n' "$instruction_block_hash"
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
printf '  instructions: %s -> %s\n' "$instruction_action" "$resolved"
printf '  ignore rules: %s -> .gitignore\n' "$ignore_action"
printf '  docs/agents: four files; tracker customized from origin when possible\n'
printf '  templates: compact docs/ADR and setup helpers always; optional components follow the selection above\n'
printf '  git pre-commit: %s (warn-only when added)\n' "$pre_commit_action"
printf '  git pre-push: %s (blocking only when explicitly requested)\n' "$pre_push_action"
if [ "$install_hooks" = 1 ]; then
  printf '  runtime hooks: samples copied only; no settings/config merge\n'
else
  printf '  runtime hooks: not selected\n'
fi
if [ "$install_orchestration" = 1 ]; then
  printf '  orchestration: manuals/profiles copied only; no integration, pane, or global config activation\n'
else
  printf '  orchestration: not selected\n'
fi
printf '  research payload: none copied; docs/research remains ignored working state\n'
printf '  source-only merge templates: claude-md-block and gitignore block are not duplicated\n'
printf '  adoption lock: %s -> %s (source ref/revision, components, payload digest, managed hashes/modes)\n' \
  "$adoption_action" "$adoption_relative"
printf '  apply serialization: transient token-owned target lock; cooperating installers only\n'
printf '  git hook mode: %s\n' "$hook_mode"

if [ "$conflicts" -ne 0 ]; then
  printf '%s\n' "full-opt: refusing to overwrite differing files:" >&2
  awk -F '\t' '$1 == "conflict" { print "  - " $2 }' "$manifest" >&2
  exit 4
fi

[ "$dry_run" = 0 ] || exit 0

tab=$(printf '\t')
while IFS="$tab" read -r action relative; do
  destination=$target/$relative
  case "$action" in
    add)
      reject_symlink_parent "$destination"
      [ ! -e "$destination" ] && [ ! -L "$destination" ] \
        || die "path changed after preflight; refusing add: $relative"
      mkdir -p "$(dirname -- "$destination")"
      cp -p "$stage/$relative" "$destination"
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

case "$instruction_action" in
  add|update-owned-block)
    path_state_matches "$instruction_file" "$instruction_preflight_state" \
      || die "instruction owner changed after preflight: $resolved"
    mkdir -p "$(dirname -- "$instruction_file")"
    cp "$instruction_desired" "$instruction_file"
    ;;
esac
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
  cp -p "$stage/templates/hooks/git/pre-commit" "$git_hooks_dir/pre-commit"
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
  cp -p "$stage/templates/hooks/git/pre-push" "$git_hooks_dir/pre-push"
  chmod +x "$git_hooks_dir/pre-push"
fi
if [ "$pre_push_action" = remove-managed ]; then
  matches_old_managed hook .git/hooks/pre-push "$git_hooks_dir/pre-push" \
    || die "pre-push changed after preflight; refusing managed removal"
  rm -f "$git_hooks_dir/pre-push"
fi

# Detect a concurrent mutation or an incomplete copy before reporting success. These
# checks make failure visible; they are not a rollback journal or an atomic commit.
while IFS= read -r staged_file; do
  relative=${staged_file#"$stage"/}
  files_match "$staged_file" "$target/$relative" \
    || die "staged file postcondition failed: $relative"
done < "$tmp/staged-files"

extract_existing_block "$instruction_file" '<!-- BEGIN foundation-integrity -->' \
  '<!-- END foundation-integrity -->' "$tmp/final-instruction-block" \
  && cmp -s "$tmp/final-instruction-block" "$source_root/templates/claude-md-block.md" \
  || die "managed instruction block postcondition failed: $resolved"
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

printf '%s\n' "full-opt: complete"
