#!/bin/sh
# Acceptance tier that fails closed on missing/mismatched declared Codex identity.
# It assumes a trusted local shell/Python/hash toolchain and honest operator inputs.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

case "${FI_CODEX_BIN:-}" in
  /*) ;;
  *)
    echo "Codex orchestration acceptance: FI_CODEX_BIN must be an absolute audited path" >&2
    exit 2
    ;;
esac
case "${FI_CODEX_SHA256:-}" in
  *[!0-9a-fA-F]*|'')
    echo "Codex orchestration acceptance: FI_CODEX_SHA256 must be hexadecimal" >&2
    exit 2
    ;;
  *) ;;
esac
[ "${#FI_CODEX_SHA256}" -eq 64 ] || {
  echo "Codex orchestration acceptance: FI_CODEX_SHA256 must contain 64 hex characters" >&2
  exit 2
}
case "$FI_CODEX_BIN" in
  */codex) ;;
  *)
    echo "Codex orchestration acceptance: audited executable basename must be codex" >&2
    exit 2
    ;;
esac

codex_bin=$(python3 - "$FI_CODEX_BIN" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).resolve(strict=True))
PY
) || { echo "Codex orchestration acceptance: audited binary path is unavailable" >&2; exit 2; }
[ -f "$codex_bin" ] && [ ! -L "$codex_bin" ] && [ -x "$codex_bin" ] || {
  echo "Codex orchestration acceptance: resolved binary must be a regular executable" >&2
  exit 2
}
if command -v shasum >/dev/null 2>&1; then
  actual_sha=$(shasum -a 256 "$codex_bin" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  actual_sha=$(sha256sum "$codex_bin" | awk '{print $1}')
else
  echo "Codex orchestration acceptance: no SHA-256 command available" >&2
  exit 2
fi
[ "$(printf '%s' "$actual_sha" | tr 'A-F' 'a-f')" = \
  "$(printf '%s' "$FI_CODEX_SHA256" | tr 'A-F' 'a-f')" ] || {
  echo "Codex orchestration acceptance: audited binary SHA-256 mismatch" >&2
  exit 1
}

sh "$root/tests/repo-contracts.sh"
CODEX_BIN="$codex_bin" sh "$root/tests/codex-effective-config-smoke.sh"

echo "Codex orchestration acceptance: PASS binary=$codex_bin sha256=$actual_sha"
