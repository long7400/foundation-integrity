#!/usr/bin/env sh
# Regenerate the standalone Claude and Codex project-skill projections from the
# canonical plugin source. This is a maintainer build step, not a consumer setup
# workflow.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
claude_root="$root/.claude/skills"
codex_root="$root/.agents/skills"

[ -d "$root/skills" ] || {
  echo "canonical skills source is missing: $root/skills" >&2
  exit 1
}
canonical_count=$(find "$root/skills" -type f -name SKILL.md | wc -l | tr -d ' ')
[ "$canonical_count" -gt 0 ] || {
  echo "canonical skills source contains no SKILL.md files: $root/skills" >&2
  exit 1
}

projection_parent_replaceable() {
  projection=$1
  parent=$(dirname -- "$projection")
  [ -d "$parent" ] || return 1
  probe=$parent/.runtime-skills-probe.$$
  mkdir "$probe" 2>/dev/null || return 1
  rmdir "$probe"
}

# Check both destinations before touching either one. A partial `rm -rf A B` can
# delete A and then fail on read-only B, contradicting the projection-preservation
# contract and leaving the next parity run with a false failure.
projection_parent_replaceable "$claude_root" || {
  echo "Claude projection destination is not replaceable: $claude_root" >&2
  exit 1
}
projection_parent_replaceable "$codex_root" || {
  echo "Codex projection destination is not replaceable: $codex_root" >&2
  exit 1
}

# Build both projections completely before replacing either checked tree. A missing
# or failed source copy must never erase the last known-good runtime projections.
stage=$(mktemp -d "$root/.runtime-skills.XXXXXX")
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT HUP INT TERM
claude_stage="$stage/claude"
codex_stage="$stage/codex"
mkdir -p "$claude_stage" "$codex_stage"
cp -R "$root/skills/." "$claude_stage/"
cp -R "$root/skills/." "$codex_stage/"

# Claude uses SKILL.md frontmatter and supporting files. Codex-only presentation
# metadata stays in the Codex projection.
find "$claude_stage" -type f -path '*/agents/openai.yaml' -delete
find "$claude_stage" -type d -empty -delete

old_claude=$stage/old-claude
old_codex=$stage/old-codex
claude_backed_up=0
codex_backed_up=0

if [ -e "$claude_root" ]; then
  mv "$claude_root" "$old_claude"
  claude_backed_up=1
fi
if [ -e "$codex_root" ]; then
  if ! mv "$codex_root" "$old_codex"; then
    [ "$claude_backed_up" = 0 ] || mv "$old_claude" "$claude_root"
    echo "could not back up Codex projection; restored Claude projection" >&2
    exit 1
  fi
  codex_backed_up=1
fi

if ! mv "$claude_stage" "$claude_root"; then
  [ "$claude_backed_up" = 0 ] || mv "$old_claude" "$claude_root"
  [ "$codex_backed_up" = 0 ] || mv "$old_codex" "$codex_root"
  echo "could not install Claude projection; restored previous projections" >&2
  exit 1
fi
if ! mv "$codex_stage" "$codex_root"; then
  mv "$claude_root" "$claude_stage"
  [ "$claude_backed_up" = 0 ] || mv "$old_claude" "$claude_root"
  [ "$codex_backed_up" = 0 ] || mv "$old_codex" "$codex_root"
  echo "could not install Codex projection; restored previous projections" >&2
  exit 1
fi

# Old projections may contain read-only content. They are no longer live; make only
# the staged backups owner-writable so cleanup cannot turn a successful swap into a
# misleading failure.
[ "$claude_backed_up" = 0 ] || chmod -R u+w "$old_claude"
[ "$codex_backed_up" = 0 ] || chmod -R u+w "$old_codex"
rm -rf "$old_claude" "$old_codex"

printf 'runtime skill projections refreshed: claude=%s codex=%s\n' \
  "$(find "$claude_root" -type f -name SKILL.md | wc -l | tr -d ' ')" \
  "$(find "$codex_root" -type f -name SKILL.md | wc -l | tr -d ' ')"
