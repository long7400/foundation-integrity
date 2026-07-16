#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="https://github.com/long7400/foundation-integrity"
API_REPOSITORY="https://api.github.com/repos/long7400/foundation-integrity"
ARCHIVE_REPOSITORY="https://codeload.github.com/long7400/foundation-integrity/tar.gz"

usage() {
  cat <<'EOF'
Usage:
  install.sh --codex|--claude|--both [options] [TARGET]

Runtime (choose exactly one):
  --codex                  Install the Codex projection.
  --claude                 Install the Claude projection.
  --both                   Install both projections.

Payload:
  --full-opt               Accepted for clarity. Full-opt is the only supported
                           payload and is always selected.
  --with-pre-push          Add the blocking pre-push hook.
  --no-pre-commit          Do not newly wire pre-commit.

Source and target:
  --ref REF                Git commit, tag, or branch to resolve to an immutable commit.
                           Defaults to main.
  -d, --directory PATH     Target project. Defaults to the current directory.
  --dry-run                Download/resolve the snapshot and print effects only.
  -h, --help               Show this help.

Examples:
  curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" | bash -s -- --codex
  curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" | bash -s -- --claude --full-opt
  curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" | bash -s -- --both --full-opt --dry-run

The bootstrap downloads one resolved repository snapshot into a temporary directory,
prints the source commit, and calls the project-local adopter. It does not install a
plugin, change global runtime configuration, overwrite an existing AGENTS.md/CLAUDE.md,
or activate orchestration. The adopter may create a short generic AGENTS.md when the
target has no AGENTS.md.
EOF
}

fail() {
  printf 'foundation-integrity install: %s\n' "$*" >&2
  exit 2
}

runtime=""
target="$PWD"
ref="main"
with_pre_push=0
no_pre_commit=0
dry_run=0
positional_target=""

set_runtime() {
  [ -z "$runtime" ] || fail "choose exactly one of --codex, --claude, or --both"
  runtime=$1
}

urlencode_path_segment() {
  local input=$1
  local output=""
  local char
  local byte
  local i
  local LC_ALL=C
  for ((i = 0; i < ${#input}; i++)); do
    char=${input:i:1}
    case "$char" in
      [A-Za-z0-9._~-]) output+=$char ;;
      *)
        printf -v byte '%02X' "'$char"
        output+="%$byte"
        ;;
    esac
  done
  printf '%s' "$output"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --codex) set_runtime codex; shift ;;
    --claude) set_runtime claude; shift ;;
    --both) set_runtime both; shift ;;
    --full-opt) shift ;;
    --core|--with-fitness|--fitness|--with-hooks|--hooks|--with-orchestration)
      fail "$1 is not supported; full-opt is the only payload"
      ;;
    --with-pre-push) with_pre_push=1; shift ;;
    --no-pre-commit) no_pre_commit=1; shift ;;
    --ref)
      [ "$#" -ge 2 ] || fail "--ref requires a commit, tag, or branch"
      ref=$2
      shift 2
      ;;
    -d|--directory)
      [ "$#" -ge 2 ] || fail "$1 requires a target path"
      target=$2
      shift 2
      ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) fail "unknown option: $1" ;;
    *)
      [ -z "$positional_target" ] || fail "only one positional TARGET is supported"
      positional_target=$1
      shift
      ;;
  esac
done

[ "$#" -eq 0 ] || fail "unexpected extra arguments: $*"
[ -n "$runtime" ] || fail "choose --codex, --claude, or --both"
[ -z "$positional_target" ] || target=$positional_target
[ -d "$target" ] || fail "target directory does not exist: $target"
target=$(cd "$target" && pwd -P)

tmp=""
cleanup() {
  [ -z "$tmp" ] || rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

source_root="${FI_INSTALL_SOURCE_ROOT:-}"
source_ref="$ref"
source_repository="$REPOSITORY"

if [ -n "$source_root" ]; then
  [ -f "$source_root/templates/setup/full-opt.sh" ] \
    || fail "FI_INSTALL_SOURCE_ROOT is not a Foundation Integrity source tree: $source_root"
  source_root=$(cd "$source_root" && pwd -P)
  source_revision="${FI_SOURCE_REVISION:-$(git -C "$source_root" rev-parse HEAD 2>/dev/null || printf local-unversioned)}"
  if git -C "$source_root" status --porcelain --untracked-files=all 2>/dev/null | grep -q .; then
    source_tree_state=dirty
  else
    source_tree_state=clean
  fi
else
  command -v curl >/dev/null 2>&1 || fail "curl is required"
  command -v tar >/dev/null 2>&1 || fail "tar is required"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-bootstrap.XXXXXX")
  if [[ "$ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    source_revision=$(printf '%s' "$ref" | tr '[:upper:]' '[:lower:]')
  else
    commit_response=$tmp/commit.json
    encoded_ref=$(urlencode_path_segment "$ref")
    curl -fsSL "$API_REPOSITORY/commits/$encoded_ref" -o "$commit_response" \
      || fail "could not resolve --ref $ref through the GitHub API"
    source_revision=$(sed -n '
      /^[[:space:]]*"sha":[[:space:]]*"[0-9a-fA-F]\{40\}"/ {
        s/^[[:space:]]*"sha":[[:space:]]*"\([0-9a-fA-F]\{40\}\)".*/\1/p
        q
      }
    ' "$commit_response")
    [ -n "$source_revision" ] || fail "could not resolve --ref $ref to a GitHub commit"
  fi
  archive=$tmp/source.tar.gz
  curl -fsSL "$ARCHIVE_REPOSITORY/$source_revision" -o "$archive" \
    || fail "could not download source commit $source_revision"
  archive_listing=$tmp/archive-listing
  tar -tzf "$archive" > "$archive_listing"
  awk '
    /^\// { bad = 1 }
    {
      count = split($0, part, "/")
      for (i = 1; i <= count; i++) if (part[i] == "..") bad = 1
    }
    END { exit bad }
  ' "$archive_listing" || fail "downloaded snapshot contains an unsafe archive path"
  tar -xzf "$archive" -C "$tmp"
  extracted_roots=$tmp/extracted-roots
  find "$tmp" -mindepth 1 -maxdepth 1 -type d -print > "$extracted_roots"
  [ "$(wc -l < "$extracted_roots" | tr -d ' ')" = 1 ] \
    || fail "downloaded snapshot must contain exactly one repository root"
  IFS= read -r source_root < "$extracted_roots"
  [ -n "$source_root" ] && [ -f "$source_root/templates/setup/full-opt.sh" ] \
    && [ ! -L "$source_root/templates/setup/full-opt.sh" ] \
    || fail "downloaded snapshot does not contain the adopter"
  [ -z "$(find "$source_root" -type l -print -quit)" ] \
    || fail "downloaded snapshot contains symlinks and will not be adopted"
  source_tree_state=clean
fi

args=(--runtime "$runtime" --full-opt)
[ "$with_pre_push" -eq 0 ] || args+=(--with-pre-push)
[ "$no_pre_commit" -eq 0 ] || args+=(--no-pre-commit)
[ "$dry_run" -eq 0 ] || args+=(--dry-run)
args+=("$target")

printf 'Foundation Integrity bootstrap\n'
printf '  repository: %s\n' "$source_repository"
printf '  requested ref: %s\n' "$source_ref"
printf '  resolved commit: %s\n' "$source_revision"
printf '  target: %s\n' "$target"
printf '  runtime: %s\n' "$runtime"
printf '  payload: full-opt\n'

FI_SOURCE_REPOSITORY="$source_repository" \
FI_SOURCE_REF="$source_ref" \
FI_SOURCE_REVISION="$source_revision" \
FI_SOURCE_TREE_STATE="$source_tree_state" \
  sh "$source_root/templates/setup/full-opt.sh" "${args[@]}"
