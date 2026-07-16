#!/bin/sh
# Root-held capability plus mutex for heavy/flaky validation across Git worktrees.
set -eu

action=${1:-}
case "$action" in authorize|verify|acquire|release|status|revoke) ;;
  *) echo "usage: $0 authorize|verify|acquire|release|status|revoke" >&2; exit 2 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
start_dir=$(pwd -P)
git_neutral() {
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_INDEX_FILE \
    -u GIT_OBJECT_DIRECTORY -u GIT_ALTERNATE_OBJECT_DIRECTORIES \
    -u GIT_CEILING_DIRECTORIES -u GIT_DISCOVERY_ACROSS_FILESYSTEM \
    git -C "$start_dir" "$@"
}
git_common=$(git_neutral rev-parse --git-common-dir 2>/dev/null) || {
  echo "validation lease: run inside a Git worktree" >&2
  exit 2
}
case "$git_common" in /*) ;; *) git_common=$(CDPATH= cd -- "$git_common" && pwd) ;; esac
worktree_root=$(git_neutral rev-parse --show-toplevel 2>/dev/null) || exit 2
authority_file=$git_common/foundation-integrity-validation.authority
lock_dir=$git_common/foundation-integrity-validation.lock
owner=${FI_VALIDATION_OWNER:-${USER:-unknown}:${HERDR_PANE_ID:-$PPID}}
revision=$(git_neutral rev-parse HEAD 2>/dev/null || printf 'unborn')
command_text=${FI_VALIDATION_COMMAND:-unspecified}
controller_name=fi-root-lead

hash_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    echo "validation lease: no SHA-256 command available" >&2
    exit 2
  fi
}

require_controller_pane() {
  expected_pane=${1:-${HERDR_PANE_ID:-}}
  [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ] \
    && [ "$HERDR_PANE_ID" = "$expected_pane" ] || {
      echo "validation lease: command must run from the authorized root pane" >&2
      exit 1
  }
  command -v herdr >/dev/null 2>&1 || { echo "validation lease: herdr not found" >&2; exit 2; }
  agent_info=$(herdr agent get "$HERDR_PANE_ID") || exit 1
  process_info=$(herdr pane process-info --pane "$HERDR_PANE_ID") || exit 1
  FI_AGENT_INFO=$agent_info FI_PROCESS_INFO=$process_info FI_WORKTREE_ROOT=$worktree_root \
    FI_EXPECTED_PANE=$expected_pane FI_CONTROLLER_NAME=$controller_name \
    FI_PROFILE_ATTESTER=$script_dir/attest-codex-profile.py \
    FI_CODEX_HOME=${CODEX_HOME:-${HOME:?}/.codex} \
    FI_ROOT_LAUNCH_RECEIPT=${FI_ROOT_LAUNCH_RECEIPT:-} python3 - <<'PY'
import hashlib, json, os, pathlib, stat, subprocess
agent = json.loads(os.environ["FI_AGENT_INFO"])["result"]["agent"]
expected_pane = os.environ["FI_EXPECTED_PANE"]
expected_name = os.environ["FI_CONTROLLER_NAME"]
for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name", "agent"):
    if not isinstance(agent.get(key), str) or not agent[key]:
        raise SystemExit(f"validation lease: root agent omitted {key}")
if agent["pane_id"] != expected_pane or agent["name"] != expected_name:
    raise SystemExit(
        f"validation lease: pane must be operationally designated {expected_name}"
    )
session = agent.get("agent_session")
session_id = session.get("value") if isinstance(session, dict) else ""
if not isinstance(session_id, str):
    session_id = ""
process = json.loads(os.environ["FI_PROCESS_INFO"])["result"]["process_info"]
ancestors = set()
pid = os.getppid()
for _ in range(16):
    if pid <= 1 or pid in ancestors:
        break
    ancestors.add(pid)
    try:
        pid = int(subprocess.run(
            ["ps", "-o", "ppid=", "-p", str(pid)], check=False,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        ).stdout.strip())
    except Exception:
        break
foreground = process.get("foreground_processes", [])
if not any(isinstance(item, dict) and item.get("pid") in ancestors for item in foreground):
    raise SystemExit("validation lease: caller is not descended from the authorized pane process")
runtime = agent["agent"]
profile = None
if runtime == "codex":
    result = subprocess.run(
        [
            "python3", os.environ["FI_PROFILE_ATTESTER"], "fi-root-lead",
            os.environ["FI_CODEX_HOME"],
        ],
        check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or result.stdout.strip())
    profile = json.loads(result.stdout)
matches = []
for item in foreground:
    if not isinstance(item, dict) or item.get("cwd") != os.environ["FI_WORKTREE_ROOT"]:
        continue
    argv = item.get("argv")
    if not isinstance(argv, list) or not argv:
        continue
    executable = pathlib.Path(str(argv[0])).name
    if runtime == "codex":
        if executable == "codex" and argv[1:] == profile["cli_args"]:
            matches.append(item)
    elif runtime == "claude":
        joined = " ".join(str(value) for value in argv[1:])
        if (
            executable == "claude"
            and "--name fi-root-lead" in joined
            and "--append-system-prompt-file" in argv
            and "--session-id" in argv
            and "Agent,Task" in joined
        ):
            matches.append(item)
if len(matches) != 1:
    raise SystemExit("validation lease: root process does not match the reviewed root envelope")
root_process = matches[0]
process_pid = root_process.get("pid")
if not isinstance(process_pid, int) or process_pid <= 1:
    raise SystemExit("validation lease: root process omitted pid")
process_started_at = subprocess.run(
    ["ps", "-o", "lstart=", "-p", str(process_pid)], check=False,
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
).stdout.strip()
if not process_started_at:
    raise SystemExit("validation lease: root process start identity is unavailable")
profile_sha = profile_device = profile_inode = "-"
root_receipt_path = root_receipt_sha = "-"
if runtime == "codex":
    profile_sha = profile["sha256"]
    profile_device = str(profile["device"])
    profile_inode = str(profile["inode"])
    receipt_value = os.environ.get("FI_ROOT_LAUNCH_RECEIPT", "")
    if not receipt_value:
        raise SystemExit("validation lease: FI_ROOT_LAUNCH_RECEIPT is required")
    receipt_path = pathlib.Path(receipt_value)
    if not receipt_path.is_absolute():
        raise SystemExit("validation lease: root launch receipt path must be absolute")
    try:
        receipt_metadata = os.lstat(receipt_path)
        receipt_bytes = receipt_path.read_bytes()
        after_receipt_read = os.lstat(receipt_path)
    except OSError as error:
        raise SystemExit(f"validation lease: root launch receipt unavailable: {error}")
    if not stat.S_ISREG(receipt_metadata.st_mode) or (
        receipt_metadata.st_dev != after_receipt_read.st_dev
        or receipt_metadata.st_ino != after_receipt_read.st_ino
    ):
        raise SystemExit("validation lease: root launch receipt changed while being read")
    try:
        receipt = json.loads(receipt_bytes)
    except Exception as error:
        raise SystemExit(f"validation lease: invalid root launch receipt: {error}")
    if receipt.get("schema") != "foundation-integrity-codex-root-launch:v1":
        raise SystemExit("validation lease: invalid root launch receipt schema")
    for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name"):
        if receipt.get(key) != agent.get(key):
            raise SystemExit(f"validation lease: root receipt {key} differs from live pane")
    for label, recorded, live in (
        ("cwd", receipt.get("cwd"), root_process.get("cwd")),
        ("pid", receipt.get("process_pid"), process_pid),
        ("start identity", receipt.get("process_started_at"), process_started_at),
        ("argv", receipt.get("process_argv"), root_process.get("argv")),
        ("profile provenance", receipt.get("profile"), profile),
    ):
        if recorded != live:
            raise SystemExit(f"validation lease: root {label} differs from pre-launch receipt")
    root_receipt_path = str(receipt_path.resolve())
    root_receipt_sha = hashlib.sha256(receipt_bytes).hexdigest()
print("\t".join((
    agent["workspace_id"], agent["tab_id"], agent["pane_id"],
    agent["terminal_id"], agent["name"], runtime, session_id,
    str(process_pid), process_started_at, root_process["cwd"],
    profile_sha, profile_device, profile_inode, root_receipt_path, root_receipt_sha,
)))
PY
}

require_capability() {
  [ -f "$authority_file" ] && [ ! -L "$authority_file" ] || {
    echo "validation lease: root authority is not initialized" >&2
    exit 1
  }
  [ -n "${FI_VALIDATION_TOKEN:-}" ] || {
    echo "validation lease: FI_VALIDATION_TOKEN is required" >&2
    exit 1
  }
  authority=$(cat "$authority_file")
  tab=$(printf '\t')
  expected=${authority%%"$tab"*}
  controller_identity=${authority#*"$tab"}
  [ -n "$controller_identity" ] && [ "$controller_identity" != "$authority" ] || {
    echo "validation lease: invalid authority record" >&2
    exit 2
  }
  IFS="$tab" read -r controller_workspace controller_tab controller_pane \
    controller_terminal controller_agent_name controller_runtime controller_session \
    controller_pid controller_started_at controller_cwd controller_profile_sha \
    controller_profile_device controller_profile_inode controller_receipt_path \
    controller_receipt_sha <<EOF
$controller_identity
EOF
  [ -n "$controller_workspace" ] && [ -n "$controller_tab" ] \
    && [ -n "$controller_pane" ] && [ -n "$controller_terminal" ] \
    && [ "$controller_agent_name" = "$controller_name" ] \
    && [ -n "$controller_runtime" ] && [ -n "$controller_pid" ] \
    && [ -n "$controller_started_at" ] && [ -n "$controller_cwd" ] \
    && [ -n "$controller_receipt_path" ] && [ -n "$controller_receipt_sha" ] || {
      echo "validation lease: incomplete root identity" >&2
      exit 2
    }
  actual=$(printf '%s' "$FI_VALIDATION_TOKEN" | hash_stdin)
  [ "$actual" = "$expected" ] || { echo "validation lease: invalid root capability" >&2; exit 1; }
  live_identity=$(require_controller_pane "$controller_pane")
  [ "$live_identity" = "$controller_identity" ] || {
    echo "validation lease: live root identity differs from authority record" >&2
    exit 1
  }
}

case "$action" in
  authorize)
    controller_identity=$(require_controller_pane "${HERDR_PANE_ID:-}")
    [ ! -e "$lock_dir" ] && [ ! -L "$lock_dir" ] \
      || { echo "validation lease: cannot authorize while held or invalid" >&2; exit 1; }
    token=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
    umask 077
    token_hash=$(printf '%s' "$token" | hash_stdin)
    FI_AUTHORITY_FILE=$authority_file FI_AUTHORITY_CONTENT="$token_hash	$controller_identity
" python3 - <<'PY'
import os
path = os.environ["FI_AUTHORITY_FILE"]
content = os.environ["FI_AUTHORITY_CONTENT"].encode()
flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
try:
    descriptor = os.open(path, flags, 0o600)
except FileExistsError:
    raise SystemExit("validation lease: authority already exists")
try:
    os.write(descriptor, content)
    os.fsync(descriptor)
finally:
    os.close(descriptor)
PY
    printf '%s\n' "$token"
    ;;
  verify)
    require_capability
    ;;
  acquire)
    require_capability
    [ ! -L "$lock_dir" ] || { echo "validation lease: lock path is symlinked" >&2; exit 1; }
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "validation lease: already held at $lock_dir" >&2
      [ -f "$lock_dir/owner" ] && sed 's/^/owner: /' "$lock_dir/owner" >&2 || true
      exit 1
    fi
    trap 'rm -rf "$lock_dir"' HUP INT TERM
    umask 077
    printf '%s\n' "$owner" > "$lock_dir/owner"
    printf '%s\n' "$revision" > "$lock_dir/revision"
    printf '%s\n' "$PWD" > "$lock_dir/cwd"
    printf '%s\n' "$command_text" > "$lock_dir/command"
    printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)" > "$lock_dir/acquired-at"
    trap - HUP INT TERM
    printf '%s\n' "$lock_dir"
    ;;
  release)
    require_capability
    [ -d "$lock_dir" ] && [ ! -L "$lock_dir" ] \
      || { echo "validation lease: not held or invalid" >&2; exit 1; }
    [ -f "$lock_dir/owner" ] || { echo "validation lease: missing owner" >&2; exit 2; }
    [ "$(cat "$lock_dir/owner")" = "$owner" ] || {
      echo "validation lease: owner mismatch" >&2
      exit 1
    }
    rm -f "$lock_dir/owner" "$lock_dir/revision" "$lock_dir/cwd" \
      "$lock_dir/command" "$lock_dir/acquired-at"
    rmdir "$lock_dir"
    ;;
  status)
    [ -f "$authority_file" ] && echo "authority: initialized" || echo "authority: absent"
    if [ -L "$lock_dir" ]; then
      echo "lease: invalid symlink"
      exit 1
    fi
    if [ ! -d "$lock_dir" ]; then
      echo "lease: free"
      exit 0
    fi
    echo "lease: held"
    for field in owner revision cwd command acquired-at; do
      [ -f "$lock_dir/$field" ] && sed "s/^/$field: /" "$lock_dir/$field"
    done
    ;;
  revoke)
    require_capability
    [ ! -d "$lock_dir" ] || { echo "validation lease: release before revoke" >&2; exit 1; }
    rm -f "$authority_file"
    ;;
esac
