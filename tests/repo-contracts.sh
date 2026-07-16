#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for script in \
  "$root"/scripts/*.sh \
  "$root"/templates/hooks/scripts/*.sh \
  "$root"/templates/hooks/git/pre-commit \
  "$root"/templates/hooks/git/pre-push \
  "$root"/templates/setup/*.sh \
  "$root"/templates/orchestration/scripts/*.sh \
  "$root"/tests/*.sh
do
  [ -x "$script" ] || fail "shell entrypoint is not executable: $script"
  sh -n "$script" || fail "shell syntax failed: $script"
done

python3 - "$root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
canonical = root / "skills"
claude = root / ".claude/skills"
codex = root / ".agents/skills"

canonical_skills = sorted(p.parent.relative_to(canonical).as_posix() for p in canonical.rglob("SKILL.md"))
if len(canonical_skills) != 24:
    raise SystemExit(f"expected 24 canonical skills, found {len(canonical_skills)}")

for runtime_root, include_openai in ((claude, False), (codex, True)):
    runtime_skills = sorted(p.parent.relative_to(runtime_root).as_posix() for p in runtime_root.rglob("SKILL.md"))
    if runtime_skills != canonical_skills:
        raise SystemExit(f"runtime skill-name drift: {runtime_root}")
    canonical_files = {
        p.relative_to(canonical).as_posix(): p.read_bytes()
        for p in canonical.rglob("*") if p.is_file()
    }
    if not include_openai:
        canonical_files = {
            path: body for path, body in canonical_files.items()
            if not path.endswith("/agents/openai.yaml")
        }
    runtime_files = {
        p.relative_to(runtime_root).as_posix(): p.read_bytes()
        for p in runtime_root.rglob("*") if p.is_file()
    }
    if canonical_files != runtime_files:
        raise SystemExit(f"runtime projection content drift: {runtime_root}")

for skill_root in (canonical, claude, codex):
    for path in skill_root.rglob("*"):
        if not path.is_file() or path.suffix not in {".md", ".yaml", ".yml", ".txt", ".toml"}:
            continue
        body = path.read_text()
        for stale in (
            "templates/claude-md-block.md",
            "templates/adr/",
            "templates/docs/",
            "templates/fitness/",
            "templates/hooks/",
            ".foundation-integrity/hooks/",
        ):
            if stale in body:
                raise SystemExit(f"stale skill reference {stale!r}: {path}")
        if "/_third_party/" not in path.as_posix() and "arxiv.org" in body:
            raise SystemExit(f"first-party skill retains paper URL: {path}")

claude_manifest = json.loads((root / ".claude-plugin/plugin.json").read_text())
codex_manifest = json.loads((root / ".codex-plugin/plugin.json").read_text())
if claude_manifest.get("name") != codex_manifest.get("name"):
    raise SystemExit("plugin names drifted")
if claude_manifest.get("version") != codex_manifest.get("version"):
    raise SystemExit("plugin versions drifted")
if codex_manifest.get("skills") != "./skills/":
    raise SystemExit("Codex manifest does not expose canonical skills/")

ignore = (root / "templates/gitignore/foundation-integrity.gitignore").read_text().splitlines()
required_ignores = {
    ".foundation/", ".orchestration/", ".codex/", ".agents/",
    "docs/research/", "tmp/", "docs/adr/*.md", "!docs/adr/0000-template.md",
}
if not required_ignores.issubset(set(ignore)):
    raise SystemExit("consumer ignore block is incomplete")

agents_template = root / "templates/setup/AGENTS.md"
if not agents_template.is_file() or len(agents_template.read_bytes()) > 4000:
    raise SystemExit("generic AGENTS.md is missing or exceeds its compact budget")

foundation_convention = (root / "docs/agents/foundation.md").read_text()
if "When `AGENTS.md` is absent, installation creates a short consumer-neutral" not in foundation_convention:
    raise SystemExit("repository foundation convention misstates the AGENTS.md bootstrap lifecycle")

codex_hooks = (root / "templates/hooks/codex-hooks.json").read_text()
claude_hooks = (root / "templates/hooks/claude-settings.json").read_text()
if ".codex/hooks/scripts/" not in codex_hooks or ".foundation-integrity/hooks/" in codex_hooks:
    raise SystemExit("Codex hook config has the wrong script owner")
if ".claude/hooks/scripts/" not in claude_hooks or ".foundation-integrity/hooks/" in claude_hooks:
    raise SystemExit("Claude hook config has the wrong script owner")
codex_hook_data = json.loads(codex_hooks)
for event in ("SessionStart", "PostCompact", "Stop"):
    commands = [
        hook.get("command", "")
        for group in codex_hook_data.get("hooks", {}).get(event, [])
        for hook in group.get("hooks", [])
    ]
    if not any("herdr-pane-telemetry.py" in command for command in commands):
        raise SystemExit(f"Codex telemetry is not wired to {event}")
session_commands = [
    hook.get("command", "")
    for group in codex_hook_data.get("hooks", {}).get("SessionStart", [])
    for hook in group.get("hooks", [])
]
if not any("herdr-codex-session.py" in command for command in session_commands):
    raise SystemExit("Codex session continuity reporter is not wired to SessionStart")

for path in (root / "templates/hooks/git/pre-commit", root / "templates/hooks/git/pre-push"):
    body = path.read_text()
    for required in (".codex/hooks/scripts", ".claude/hooks/scripts"):
        if required not in body:
            raise SystemExit(f"runtime-neutral git loader misses {required}: {path}")
    if ".foundation-integrity/adoption.tsv" not in body:
        raise SystemExit(f"git loader does not use the recorded runtime owner: {path}")
    if "for candidate in" in body:
        raise SystemExit(f"git loader retains an authority-guessing fallback: {path}")
    if ".foundation-integrity/hooks" in body:
        raise SystemExit(f"git loader retains the retired hook-script directory: {path}")

for path in (
    root / "AGENTS.md",
    root / "README.md",
    root / "docs/install/codex.md",
    root / "docs/install/claude.md",
    root / "templates/hooks/README.md",
    root / "templates/fitness/adapters/js-ts.md",
):
    if ".foundation-integrity/hooks/" in path.read_text():
        raise SystemExit(f"distribution documentation retains legacy hook path: {path}")
PY

(cd "$root" && shasum -a 256 -c third_party/mattpocock-skills/promoted-files.sha256 \
  >/dev/null) || fail "vendored companion snapshot hash drift"

sh "$root/tests/orchestration-contracts.sh" \
  || fail "orchestration contracts failed"

sh "$root/tests/install-contracts.sh" || fail "install contracts failed"

echo "repo contracts: PASS"
