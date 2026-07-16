#!/bin/sh
# Manage the pinned Responses-to-Chat-Completions gateway used by the optional
# GLM-5.2 Codex profiles. The gateway is deliberately user-local and loopback-only.
set -eu

VERSION="7.2.80"
RELEASE_BASE="https://github.com/router-for-me/CLIProxyAPI/releases/download/v${VERSION}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROFILE_SOURCE="$SCRIPT_DIR/../profiles/codex"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/foundation-integrity/cliproxy-glm"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/foundation-integrity/cliproxy-glm"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/foundation-integrity/cliproxy-glm"
CONFIG="$ROOT/config.yaml"
CLIENT_KEY_FILE="$ROOT/client-key"
PROFILE_MANIFEST="$ROOT/installed-profiles.tsv"
BIN="$DATA/cli-proxy-api"
PID_FILE="$STATE/cliproxy.pid"
LOG_FILE="$STATE/cliproxy.log"
LOCK_DIR="$STATE/lifecycle.lock"
PORT="8317"
BASE_URL="http://127.0.0.1:${PORT}/v1"
LOCK_HELD=0
TTY_STATE=""
TMP_ARCHIVE=""
TMP_EXTRACT=""

die() { echo "cliproxy-glm: $*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

cleanup() {
  [ -z "$TTY_STATE" ] || stty "$TTY_STATE" 2>/dev/null || true
  [ -z "$TMP_ARCHIVE" ] || rm -f "$TMP_ARCHIVE"
  [ -z "$TMP_EXTRACT" ] || rm -rf "$TMP_EXTRACT"
  if [ "$LOCK_HELD" -ne 0 ]; then
    rm -f "$LOCK_DIR/owner-pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup 0 HUP INT TERM

acquire_lock() {
  reject_symlink_ancestors "$STATE"
  mkdir -p "$STATE"; chmod 700 "$STATE"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    owner_pid=$(sed -n '1p' "$LOCK_DIR/owner-pid" 2>/dev/null || true)
    owner_start=$(sed -n '2p' "$LOCK_DIR/owner-pid" 2>/dev/null || true)
    current_start=$(ps -p "$owner_pid" -o lstart= 2>/dev/null || true)
    owner_alive=0
    kill -0 "$owner_pid" 2>/dev/null && owner_alive=1
    if [ -n "$owner_pid" ] && [ -n "$owner_start" ] && { [ "$owner_alive" -eq 0 ] || { [ -n "$current_start" ] && [ "$current_start" != "$owner_start" ]; }; }; then
      rm -f "$LOCK_DIR/owner-pid"
      rmdir "$LOCK_DIR" 2>/dev/null || die "could not recover stale lifecycle lock"
      mkdir "$LOCK_DIR" 2>/dev/null || die "another lifecycle command acquired $LOCK_DIR"
    else
      die "another lifecycle command owns $LOCK_DIR; inspect it before removing a stale lock"
    fi
  fi
  LOCK_HELD=1
  printf '%s\n%s\n' "$$" "$(ps -p $$ -o lstart=)" >"$LOCK_DIR/owner-pid"
  chmod 600 "$LOCK_DIR/owner-pid"
}

platform() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$os:$arch" in
    darwin:arm64|darwin:aarch64) printf '%s\n' "darwin_aarch64" ;;
    darwin:x86_64|darwin:amd64) printf '%s\n' "darwin_amd64" ;;
    linux:arm64|linux:aarch64) printf '%s\n' "linux_aarch64_no-plugin" ;;
    linux:x86_64|linux:amd64) printf '%s\n' "linux_amd64_no-plugin" ;;
    *) die "unsupported platform: $os/$arch (supported: macOS/Linux arm64/amd64)" ;;
  esac
}

checksum_for() {
  case "$1" in
    darwin_aarch64) printf '%s\n' 7b13a17670a7d24318e3d6a3f24ff38696cf23ab44894fc93fbd53fbb68dfda6 ;;
    darwin_amd64) printf '%s\n' e442331bf90e908adac1da0b5536c360318dd95708f21423705ed0ae6d311fcc ;;
    linux_aarch64_no-plugin) printf '%s\n' 4ed25c7f512c54e037247ec385f5e50b48310ce60d6bd3f1427287752c1baafe ;;
    linux_amd64_no-plugin) printf '%s\n' 36616fdd8240719902d0c767a1f7445ea248950f29d8785996b93046472840b6 ;;
    *) die "no pinned checksum for $1" ;;
  esac
}

require_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  command -v lsof >/dev/null 2>&1 || command -v ss >/dev/null 2>&1 || die "lsof or ss is required"
  command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || die "shasum or sha256sum is required"
}

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi
}

reject_symlink() { [ ! -L "$1" ] || die "refusing symlinked managed path: $1"; }

reject_symlink_ancestors() {
  path=$1
  while [ "$path" != "/" ] && [ -n "$path" ]; do
    reject_symlink "$path"
    parent=$(dirname "$path")
    [ "$parent" = "$path" ] && break
    path=$parent
  done
}

validate_secret() {
  value=$1
  [ -n "$value" ] || die "an API key is required"
  case "$value" in
    *'
'*|*''*) die "API keys must be a single line" ;;
  esac
}

yaml_single_quote() { printf '%s' "$1" | sed "s/'/''/g"; }

write_secret() {
  path=$1
  value=$2
  umask 077
  printf '%s\n' "$value" >"$path"
  chmod 600 "$path"
}

profile_names="fi-glm-peer-scout fi-glm-implementer-mechanical"

validate_manifest() {
  [ -e "$PROFILE_MANIFEST" ] || return 0
  reject_symlink "$PROFILE_MANIFEST"
  [ -f "$PROFILE_MANIFEST" ] || die "profile manifest is not a regular file"
  awk -F '\t' '
    /^# foundation-integrity-profile-manifest:v1$/ { header++; next }
    NF != 2 || $1 !~ /^fi-glm-(peer-scout|implementer-mechanical)$/ || $2 !~ /^[0-9a-f]{64}$/ || seen[$1]++ { exit 1 }
    END { if (header != 1 || length(seen["fi-glm-peer-scout"]) == 0 || length(seen["fi-glm-implementer-mechanical"]) == 0) exit 1 }
  ' "$PROFILE_MANIFEST" || die "profile manifest is invalid: $PROFILE_MANIFEST"
}

check_profile_conflicts() {
  reject_symlink_ancestors "$CODEX_HOME_DIR"
  validate_manifest
  for name in $profile_names; do
    source_file="$PROFILE_SOURCE/$name.config.toml"
    target_file="$CODEX_HOME_DIR/$name.config.toml"
    [ -f "$source_file" ] || die "missing profile source: $source_file"
    reject_symlink "$target_file"
    if [ -e "$target_file" ] && ! cmp -s "$source_file" "$target_file"; then
      recorded=""
      [ -f "$PROFILE_MANIFEST" ] && recorded=$(awk -F '\t' -v n="$name" '$1 == n { print $2; exit }' "$PROFILE_MANIFEST")
      current=$(sha256 "$target_file")
      [ -n "$recorded" ] && [ "$current" = "$recorded" ] \
        || die "refusing to overwrite differing Codex profile: $target_file"
    fi
  done
}

install_profiles() {
  if [ ! -d "$CODEX_HOME_DIR" ]; then mkdir -p "$CODEX_HOME_DIR"; chmod 700 "$CODEX_HOME_DIR"; fi
  manifest_tmp="$PROFILE_MANIFEST.tmp"
  printf '%s\n' '# foundation-integrity-profile-manifest:v1' >"$manifest_tmp"; chmod 600 "$manifest_tmp"
  for name in $profile_names; do
    install -m 600 "$PROFILE_SOURCE/$name.config.toml" "$CODEX_HOME_DIR/$name.config.toml"
    printf '%s\t%s\n' "$name" "$(sha256 "$CODEX_HOME_DIR/$name.config.toml")" >>"$manifest_tmp"
  done
  mv "$manifest_tmp" "$PROFILE_MANIFEST"
  say "Installed GLM profiles in $CODEX_HOME_DIR"
}

setup() {
  require_tools
  for managed_path in "$ROOT" "$STATE" "$DATA" "$CONFIG" "$CLIENT_KEY_FILE" "$BIN" "$PID_FILE" "$LOG_FILE"; do reject_symlink_ancestors "$managed_path"; done
  check_profile_conflicts
  mkdir -p "$ROOT" "$STATE" "$DATA"
  chmod 700 "$ROOT" "$STATE" "$DATA"

  if [ -z "${ZAI_API_KEY:-}" ]; then
    printf 'Z.AI Coding Plan API key (input hidden): ' >&2
    [ -t 0 ] && [ -t 2 ] || die "interactive setup requires a TTY; otherwise set ZAI_API_KEY for this command"
    TTY_STATE=$(stty -g 2>/dev/null) || die "could not read terminal state"
    stty -echo || die "could not disable terminal echo"
    read -r ZAI_API_KEY
    stty "$TTY_STATE" || die "could not restore terminal state"
    TTY_STATE=""
    printf '\n' >&2
  fi
  validate_secret "$ZAI_API_KEY"

  if [ ! -f "$CLIENT_KEY_FILE" ]; then
    client_key=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
    write_secret "$CLIENT_KEY_FILE" "$client_key"
  fi

  target=$(platform)
  archive="CLIProxyAPI_${VERSION}_${target}.tar.gz"
  TMP_ARCHIVE=$(mktemp "${TMPDIR:-/tmp}/cliproxy-glm.XXXXXX")
  curl -fL --retry 3 --proto '=https' --tlsv1.2 "$RELEASE_BASE/$archive" -o "$TMP_ARCHIVE"
  expected=$(checksum_for "$target")
  actual=$(sha256 "$TMP_ARCHIVE")
  [ "$actual" = "$expected" ] || die "checksum mismatch for $archive"
  TMP_EXTRACT=$(mktemp -d "${TMPDIR:-/tmp}/cliproxy-glm.extract.XXXXXX")
  tar -xzf "$TMP_ARCHIVE" -C "$TMP_EXTRACT" cli-proxy-api
  install -m 700 "$TMP_EXTRACT/cli-proxy-api" "$BIN"
  rm -f "$TMP_ARCHIVE"; TMP_ARCHIVE=""
  rm -rf "$TMP_EXTRACT"; TMP_EXTRACT=""

  client_key=$(sed -n '1p' "$CLIENT_KEY_FILE")
  upstream_key_yaml=$(yaml_single_quote "$ZAI_API_KEY")
  client_key_yaml=$(yaml_single_quote "$client_key")
  data_yaml=$(yaml_single_quote "$DATA")
  umask 077
  cat >"$CONFIG" <<EOF
host: "127.0.0.1"
port: ${PORT}
tls:
  enable: false
remote-management:
  allow-remote: false
  secret-key: ""
  disable-control-panel: true
auth-dir: '${data_yaml}/auth'
api-keys:
  - '${client_key_yaml}'
debug: false
logging-to-file: false
usage-statistics-enabled: false
plugins:
  enabled: false
commercial-mode: true
request-retry: 2
openai-compatibility:
  - name: "zai-coding"
    base-url: "https://api.z.ai/api/coding/paas/v4"
    api-key-entries:
      - api-key: '${upstream_key_yaml}'
    models:
      - name: "glm-5.2"
        alias: "glm-5.2"
EOF
  chmod 600 "$CONFIG"
  install_profiles
  say "Installed CLIProxyAPI v${VERSION} at $BIN"
  say "Gateway config: $CONFIG (owner-only; the upstream key is stored only here)"
  say "Client base URL: $BASE_URL"
}

read_client_key() { [ -f "$CLIENT_KEY_FILE" ] || die "run setup first"; sed -n '1p' "$CLIENT_KEY_FILE"; }

running_pid() {
  [ -f "$PID_FILE" ] || return 1
  pid=$(sed -n '1p' "$PID_FILE")
  expected_start=$(sed -n '2p' "$PID_FILE")
  kill -0 "$pid" 2>/dev/null || return 1
  [ -n "$expected_start" ] || return 1
  [ "$(ps -p "$pid" -o lstart= 2>/dev/null || true)" = "$expected_start" ] || return 1
  process_command=$(ps -p "$pid" -o command= 2>/dev/null || true)
  case "$process_command" in
    *"$BIN"*"-config $CONFIG"*) ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$pid"
}

verify_listener() {
  pid=$1
  if command -v lsof >/dev/null 2>&1; then
    listeners=$(lsof -nP -a -p "$pid" -iTCP -sTCP:LISTEN 2>/dev/null || true)
  else
    listeners=$(ss -ltnp 2>/dev/null | grep "pid=$pid," || true)
  fi
  printf '%s\n' "$listeners" | grep -Fq "127.0.0.1:$PORT" \
    || return 1
  if printf '%s\n' "$listeners" | grep -Eq "(0\.0\.0\.0|\*|\[::\]):$PORT"; then
    return 1
  fi
}

start() {
  [ -x "$BIN" ] || die "gateway is not installed; run setup"
  [ -f "$CONFIG" ] || die "gateway is not configured; run setup"
  if pid=$(running_pid); then say "already running (pid $pid)"; return 0; fi
  reject_symlink_ancestors "$PID_FILE"; reject_symlink_ancestors "$LOG_FILE"
  mkdir -p "$STATE"; chmod 700 "$STATE"
  (
    cd "$DATA"
    nohup "$BIN" -home-disable-cluster-discovery -config "$CONFIG" >"$LOG_FILE" 2>&1 &
    child=$!
    printf '%s\n%s\n' "$child" "$(ps -p "$child" -o lstart=)" >"$PID_FILE"
  )
  i=0
  while ! pid=$(running_pid) && [ "$i" -lt 50 ]; do i=$((i + 1)); sleep 0.1; done
  if ! pid=$(running_pid); then tail -20 "$LOG_FILE" 2>/dev/null || true; die "gateway failed to start"; fi
  i=0
  while ! verify_listener "$pid" >/dev/null 2>&1 && [ "$i" -lt 50 ]; do i=$((i + 1)); sleep 0.1; done
  if ! verify_listener "$pid"; then
    if current_pid=$(running_pid); then kill "$current_pid" 2>/dev/null || true; fi
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do i=$((i + 1)); sleep 0.1; done
    kill -KILL "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    die "managed process is not loopback-only on 127.0.0.1:$PORT"
  fi
  say "started gateway (pid $pid) at $BASE_URL"
}

stop() {
  if ! pid=$(running_pid); then rm -f "$PID_FILE"; say "gateway is not running"; return 0; fi
  if current_pid=$(running_pid); then kill "$current_pid" 2>/dev/null || true; else rm -f "$PID_FILE"; say "gateway identity changed; did not signal it"; return 1; fi
  i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do i=$((i + 1)); sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then
    if current_pid=$(running_pid); then kill -KILL "$current_pid" 2>/dev/null || true; fi
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do i=$((i + 1)); sleep 0.1; done
  fi
  kill -0 "$pid" 2>/dev/null && die "managed gateway did not stop; credentials were preserved"
  rm -f "$PID_FILE"; say "stopped gateway (pid $pid)"
}

status() {
  if pid=$(running_pid); then say "running pid=$pid url=$BASE_URL"; else say "stopped"; return 1; fi
}

doctor() {
  pid=$(running_pid) || die "gateway is not running"
  verify_listener "$pid" || die "managed process is not loopback-only on 127.0.0.1:$PORT"
  key=$(read_client_key)
  code=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $key" "$BASE_URL/models" || true)
  [ "$code" = 200 ] || die "gateway health check failed (HTTP $code)"
  say "gateway health check OK (HTTP 200)"
}

print_env() {
  say "export FI_CLIPROXY_BASE_URL=$BASE_URL"
  say "export FI_CLIPROXY_KEY=$(read_client_key)"
}

remove() {
  validate_manifest
  stop || true
  for name in $profile_names; do
    source_file="$PROFILE_SOURCE/$name.config.toml"
    target_file="$CODEX_HOME_DIR/$name.config.toml"
    recorded=""
    [ -f "$PROFILE_MANIFEST" ] && recorded=$(awk -F '\t' -v n="$name" '$1 == n { print $2; exit }' "$PROFILE_MANIFEST")
    current=""
    [ -f "$target_file" ] && [ ! -L "$target_file" ] && current=$(sha256 "$target_file")
    if [ -n "$recorded" ] && [ "$current" = "$recorded" ]; then
      rm -f "$target_file"
    elif [ -e "$target_file" ]; then
      say "preserved modified profile: $target_file"
    fi
  done
  rm -rf "$ROOT" "$STATE" "$DATA"
  say "removed gateway files and credentials; no repository or default Codex provider files were changed"
}

command=${1:-}
case "$command" in
  setup|start|stop|restart|remove) acquire_lock ;;
esac
case "$command" in
  setup) setup ;;
  start) start ;;
  stop) stop ;;
  restart) stop || true; start ;;
  status) status ;;
  doctor) doctor ;;
  print-env) print_env ;;
  remove) remove ;;
  *) die "usage: $0 {setup|start|stop|restart|status|doctor|print-env|remove}" ;;
esac
