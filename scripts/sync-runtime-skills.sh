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

mkdir -p "$(dirname "$claude_root")" "$(dirname "$codex_root")"
rm -rf "$claude_root" "$codex_root"
mv "$claude_stage" "$claude_root"
mv "$codex_stage" "$codex_root"

printf 'runtime skill projections refreshed: claude=%s codex=%s\n' \
  "$(find "$claude_root" -type f -name SKILL.md | wc -l | tr -d ' ')" \
  "$(find "$codex_root" -type f -name SKILL.md | wc -l | tr -d ' ')"
