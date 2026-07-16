#!/bin/sh
# Install/remove user-level Codex envelopes with an explicit ownership manifest.
set -eu

action=${1:-}
case "$action" in install|remove|status) ;; *) echo "usage: $0 install|remove|status" >&2; exit 2 ;; esac
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
source_dir=$(CDPATH= cd -- "$script_dir/../profiles/codex" && pwd)
codex_home=${CODEX_HOME:-${HOME:?}/.codex}
manifest=$codex_home/foundation-integrity-profiles.json
profiles='fi-root-lead fi-peer-scout fi-peer-challenge fi-implementer-mechanical fi-implementer-ambiguous'

case "$action" in
  install)
    [ -d "$codex_home" ] || { echo "profile install: Codex home is missing: $codex_home" >&2; exit 2; }
    SOURCE_DIR=$source_dir CODEX_HOME_VALUE=$codex_home MANIFEST=$manifest python3 - <<'PY'
import hashlib, json, os, pathlib, stat
source = pathlib.Path(os.environ["SOURCE_DIR"])
home = pathlib.Path(os.environ["CODEX_HOME_VALUE"])
manifest = pathlib.Path(os.environ["MANIFEST"])
expected = {
    "fi-root-lead.config.toml", "fi-peer-scout.config.toml",
    "fi-peer-challenge.config.toml", "fi-implementer-mechanical.config.toml",
    "fi-implementer-ambiguous.config.toml",
}
sources = {name: source / name for name in expected}
missing = sorted(name for name, path in sources.items() if not path.is_file())
if missing:
    raise SystemExit(f"profile install: primary source profile set is incomplete: {missing}")
created: list[tuple[pathlib.Path, int, int]] = []

def exclusive_write(path: pathlib.Path, content: bytes) -> os.stat_result:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    try:
        view = memoryview(content)
        while view:
            written = os.write(descriptor, view)
            view = view[written:]
        os.fsync(descriptor)
        metadata = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    created.append((path, metadata.st_dev, metadata.st_ino))
    return metadata

def cleanup() -> list[str]:
    preserved: list[str] = []
    for path, device, inode in reversed(created):
        try:
            metadata = os.lstat(path)
        except FileNotFoundError:
            continue
        if metadata.st_dev == device and metadata.st_ino == inode:
            os.unlink(path)
        else:
            preserved.append(str(path))
    return preserved

try:
    files = {}
    for name in sorted(expected):
        content = sources[name].read_bytes()
        destination = home / name
        metadata = exclusive_write(destination, content)
        files[name] = {
            "device": metadata.st_dev,
            "inode": metadata.st_ino,
            "sha256": hashlib.sha256(content).hexdigest(),
        }
    value = {"schema": "foundation-integrity-codex-profiles:v2", "files": files}
    manifest_content = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    exclusive_write(manifest, manifest_content)
    for name, record in files.items():
        path = home / name
        metadata = os.lstat(path)
        if not stat.S_ISREG(metadata.st_mode) or (
            metadata.st_dev != record["device"]
            or metadata.st_ino != record["inode"]
            or hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]
        ):
            raise RuntimeError(f"profile install: destination changed during install: {path}")
except Exception as error:
    preserved = cleanup()
    detail = f"; preserved raced replacements: {', '.join(preserved)}" if preserved else ""
    raise SystemExit(f"profile install: refusing partial or conflicting install: {error}{detail}")
PY
    ;;
  remove)
    [ -f "$manifest" ] && [ ! -L "$manifest" ] || {
      echo "profile remove: ownership manifest is missing" >&2
      exit 1
    }
    MANIFEST=$manifest CODEX_HOME_VALUE=$codex_home python3 - <<'PY'
import hashlib, json, os, pathlib, shutil, stat, tempfile
manifest = pathlib.Path(os.environ["MANIFEST"])
home = pathlib.Path(os.environ["CODEX_HOME_VALUE"])
expected = {
    "fi-root-lead.config.toml", "fi-peer-scout.config.toml",
    "fi-peer-challenge.config.toml", "fi-implementer-mechanical.config.toml",
    "fi-implementer-ambiguous.config.toml",
}
quarantine = pathlib.Path(tempfile.mkdtemp(
    prefix=".foundation-integrity-profile-removal-", dir=home
))
moved: list[tuple[pathlib.Path, pathlib.Path]] = []

def move_into_quarantine(source: pathlib.Path) -> pathlib.Path:
    target = quarantine / source.name
    os.replace(source, target)
    moved.append((source, target))
    return target

def restore() -> list[str]:
    conflicts: list[str] = []
    for source, target in reversed(moved):
        if not target.exists() and not target.is_symlink():
            continue
        if source.exists() or source.is_symlink():
            conflicts.append(str(target))
            continue
        os.replace(target, source)
    try:
        quarantine.rmdir()
    except OSError:
        pass
    return conflicts

try:
    quarantined_manifest = move_into_quarantine(manifest)
    manifest_mode = os.lstat(quarantined_manifest).st_mode
    if not stat.S_ISREG(manifest_mode):
        raise RuntimeError("profile remove: ownership manifest is not a regular file")
    value = json.loads(quarantined_manifest.read_text(encoding="utf-8"))
    if value.get("schema") != "foundation-integrity-codex-profiles:v2":
        raise RuntimeError("profile remove: invalid ownership manifest")
    files = value.get("files")
    if not isinstance(files, dict) or set(files) != expected:
        raise RuntimeError("profile remove: ownership manifest has the wrong file set")

    for name in sorted(expected):
        quarantined = move_into_quarantine(home / name)
        metadata = os.lstat(quarantined)
        if not stat.S_ISREG(metadata.st_mode):
            raise RuntimeError(f"profile remove: owned file is not regular: {home / name}")
        record = files[name]
        if not isinstance(record, dict) or set(record) != {"device", "inode", "sha256"}:
            raise RuntimeError(f"profile remove: invalid provenance record for {home / name}")
        if metadata.st_dev != record["device"] or metadata.st_ino != record["inode"]:
            raise RuntimeError(f"profile remove: refusing to delete replaced {home / name}")
        digest = hashlib.sha256(quarantined.read_bytes()).hexdigest()
        if digest != record["sha256"]:
            raise RuntimeError(f"profile remove: refusing to delete drifted {home / name}")
except Exception as error:
    conflicts = restore()
    detail = f"; preserved quarantine entries at {quarantine}" if conflicts else ""
    raise SystemExit(f"{error}{detail}")

# Every exact owned object is now outside its public destination and was hashed
# after the atomic rename. Removing quarantine cannot delete a replacement raced
# into the original path.
shutil.rmtree(quarantine)
PY
    ;;
  status)
    if [ ! -f "$manifest" ] || [ -L "$manifest" ]; then
      echo "ownership: absent"
      for profile in $profiles; do
        destination=$codex_home/$profile.config.toml
        [ ! -e "$destination" ] && state=absent || state=unowned
        printf '%s\t%s\n' "$profile" "$state"
      done
      exit 0
    fi
    MANIFEST=$manifest CODEX_HOME_VALUE=$codex_home python3 - <<'PY'
import hashlib, json, os, pathlib
manifest = pathlib.Path(os.environ["MANIFEST"])
home = pathlib.Path(os.environ["CODEX_HOME_VALUE"])
try:
    value = json.loads(manifest.read_text())
    files = value["files"] if value.get("schema") == "foundation-integrity-codex-profiles:v2" else {}
except Exception:
    files = {}
print("ownership: recorded" if files else "ownership: invalid")
for name in ("fi-root-lead", "fi-peer-scout", "fi-peer-challenge", "fi-implementer-mechanical", "fi-implementer-ambiguous"):
    filename = name + ".config.toml"
    path = home / filename
    if filename not in files:
        state = "unowned"
    elif path.is_file() and not path.is_symlink() and isinstance(files[filename], dict):
        metadata = os.stat(path, follow_symlinks=False)
        record = files[filename]
        state = "matching" if (
            metadata.st_dev == record.get("device")
            and metadata.st_ino == record.get("inode")
            and hashlib.sha256(path.read_bytes()).hexdigest() == record.get("sha256")
        ) else "drifted"
    else:
        state = "drifted"
    print(f"{name}\t{state}")
PY
    ;;
esac
