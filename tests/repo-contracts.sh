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
import hashlib
import json
import pathlib
import re
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

for retired in (root / ".claude-plugin", root / ".codex-plugin"):
    if retired.exists():
        raise SystemExit(f"retired plugin distribution surface remains: {retired}")

version_file = root / "VERSION"
version = version_file.read_text().strip() if version_file.is_file() else ""
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
    raise SystemExit("VERSION must contain one semantic version")

profile_root = root / "templates/orchestration/profiles/codex"
primary_profiles = {
    "fi-root-lead.config.toml": "27b0baf4172835b548ea3b489939e47f306d5e2c3bf21894d0cdcae9ef2cb6ba",
    "fi-peer-scout.config.toml": "269dc23611dc6c9d01d797009714259c4d6119dc129b7c3fe904ae5a63d6835f",
    "fi-peer-challenge.config.toml": "9f5d955ceffb04f9fba7fe60f8be4fb44289961851336fe5720294c89787ad57",
    "fi-implementer-mechanical.config.toml": "8d158f2758aef86d5df8589d0ca309d6fa034edf22c21c4af28be9ab1dbacd36",
    "fi-implementer-ambiguous.config.toml": "e42a15c2b877026504fc59fff29bec98e92d2c7bf60de19d81672c5547b2ef5c",
}
glm_profiles = {
    "fi-glm-peer-scout.config.toml": ("read-only", "never"),
    "fi-glm-implementer-mechanical.config.toml": ("workspace-write", "on-request"),
}
actual_profiles = {p.name for p in profile_root.iterdir() if p.is_file()}
if actual_profiles != set(primary_profiles) | set(glm_profiles):
    raise SystemExit("Codex profile inventory must contain five primary and two GLM envelopes")
for filename, expected_sha256 in primary_profiles.items():
    actual_sha256 = hashlib.sha256((profile_root / filename).read_bytes()).hexdigest()
    if actual_sha256 != expected_sha256:
        raise SystemExit(f"primary Codex profile changed without policy review: {filename}")
for filename, (sandbox, approval) in glm_profiles.items():
    path = profile_root / filename
    raw = path.read_text()
    expected_lines = {
        'model = "glm-5.2"',
        'model_provider = "fi-cliproxy-glm"',
        'model_reasoning_effort = "max"',
        'model_context_window = 272000',
        f'sandbox_mode = "{sandbox}"',
        f'approval_policy = "{approval}"',
        'developer_instructions = """',
        '[model_providers.fi-cliproxy-glm]',
        'name = "GLM-5.2 via local CLIProxyAPI"',
        'base_url = "http://127.0.0.1:8317/v1"',
        'env_key = "FI_CLIPROXY_KEY"',
        'env_key_instructions = "Run cliproxy-glm.sh print-env; never commit this key."',
        'wire_api = "responses"',
        'requires_openai_auth = false',
        '[features]',
        'multi_agent = false',
        'multi_agent_v2 = false',
    }
    raw_lines = raw.splitlines()
    warning_lines = [
        "# Optional auxiliary profile. Run templates/orchestration/scripts/cliproxy-glm.sh setup first.",
    ]
    if raw_lines[:1] != warning_lines:
        raise SystemExit(f"GLM profile must begin with the setup pointer: {path}")
    lines = set(raw_lines)
    missing = expected_lines - lines
    if missing:
        raise SystemExit(f"GLM profile misses required envelope {sorted(missing)!r}: {path}")
    for required in expected_lines:
        if raw_lines.count(required) != 1:
            raise SystemExit(f"GLM profile duplicates required configuration {required!r}: {path}")
    in_instructions = False
    for line in raw_lines:
        if in_instructions:
            if line == '"""':
                in_instructions = False
            continue
        if line == 'developer_instructions = """':
            in_instructions = True
            continue
        if line and line not in expected_lines and line not in warning_lines:
            raise SystemExit(f"GLM profile contains an unexpected configuration line {line!r}: {path}")
    if in_instructions:
        raise SystemExit(f"GLM profile has an unterminated developer_instructions block: {path}")
    if re.search(r"(?mi)^(api[_-]?key|token|bearer_token|authorization|experimental_bearer_token|http_headers)\s*=", raw):
        raise SystemExit(f"GLM profile contains a forbidden inline credential surface: {path}")

gateway = root / "templates/orchestration/scripts/cliproxy-glm.sh"
if not gateway.is_file() or not (gateway.stat().st_mode & 0o111):
    raise SystemExit("GLM gateway lifecycle script is missing or not executable")
gateway_body = gateway.read_text()
for required in (
    'VERSION="7.2.80"',
    'host: "127.0.0.1"',
    'disable-control-panel: true',
    'plugins:',
    'base-url: "https://api.z.ai/api/coding/paas/v4"',
    'alias: "glm-5.2"',
    'setup|start|stop|restart|status|doctor|print-env|remove',
):
    if required not in gateway_body:
        raise SystemExit(f"GLM gateway lifecycle misses {required!r}")

ignore = (root / "templates/gitignore/foundation-integrity.gitignore").read_text().splitlines()
required_ignores = {
    ".foundation/", ".orchestration/", ".codex/", ".agents/",
    "docs/research/", "docs/foundation/receipts/*",
    "!docs/foundation/receipts/.gitkeep", "tmp/", "docs/adr/*.md",
    "!docs/adr/0000-template.md",
}
if not required_ignores.issubset(set(ignore)):
    raise SystemExit("consumer ignore block is incomplete")

agents_template = root / "templates/setup/AGENTS.md"
if not agents_template.is_file() or len(agents_template.read_bytes()) > 5800:
    raise SystemExit("generic AGENTS.md is missing or exceeds its compact budget")
for agents_path in (root / "AGENTS.md", agents_template):
    agents_body = agents_path.read_text()
    for required in ("Herdr-only coworker spawning", "Use Herdr", "native subagent"):
        if required not in agents_body:
            raise SystemExit(f"Herdr-only spawning rule misses {required!r}: {agents_path}")

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

for path in (root / "README.md", root / "docs/install/codex.md", root / "docs/install/claude.md"):
    body = path.read_text().lower()
    if re.search(r"\bplugins?\b|\.claude-plugin|\.codex-plugin", body):
        raise SystemExit(f"shell-only documentation retains a retired distribution claim: {path}")

retired_install_command = re.compile(
    r"(?i)(?:/plugin\s|codex\s+plugin\s|plugin\s+(?:marketplace|install|add)|"
    r"cp\s+-R\s+\.(?:agents|claude)/skills)"
)
for path in root.rglob("*.md"):
    relative = path.relative_to(root).as_posix()
    if relative.startswith(("docs/research/", "docs/adr/", "docs/foundation/receipts/", "third_party/", ".foundation/")):
        continue
    if retired_install_command.search(path.read_text()):
        raise SystemExit(f"active documentation restores a retired distribution command: {path}")
PY

if command -v codex >/dev/null 2>&1; then
  profile_home=$(mktemp -d "${TMPDIR:-/tmp}/foundation-integrity-profiles.XXXXXX")
  cp "$root"/templates/orchestration/profiles/codex/*.config.toml "$profile_home/"
  for profile_marker in \
    "fi-glm-peer-scout|Your launch authority is read-only peer with work class scout" \
    "fi-glm-implementer-mechanical|Your launch authority is implementer with work class mechanical"
  do
    profile=${profile_marker%%|*}
    marker=${profile_marker#*|}
    if ! ZAI_API_KEY=profile-parse-only CODEX_HOME="$profile_home" \
      codex --profile "$profile" debug prompt-input profile-discovery-probe \
      2>/dev/null | grep -Fq "$marker"; then
      rm -rf "$profile_home"
      fail "Codex could not parse the active GLM profile $profile"
    fi
  done
  rm -rf "$profile_home"
fi

(cd "$root" && shasum -a 256 -c third_party/mattpocock-skills/promoted-files.sha256 \
  >/dev/null) || fail "vendored companion snapshot hash drift"

sh "$root/tests/orchestration-contracts.sh" \
  || fail "orchestration contracts failed"

sh "$root/tests/cliproxy-glm-contracts.sh" \
  >/dev/null || fail "GLM gateway lifecycle contracts failed"

sh "$root/tests/install-contracts.sh" || fail "install contracts failed"

echo "repo contracts: PASS"
