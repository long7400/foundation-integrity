#!/usr/bin/env python3
"""Attest one project-owned Codex envelope and derive immutable CLI overrides."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys


PROFILES = {
    "fi-root-lead",
    "fi-peer-scout",
    "fi-peer-challenge",
    "fi-implementer-mechanical",
    "fi-implementer-ambiguous",
    "fi-glm-peer-scout",
    "fi-glm-implementer-mechanical",
}

ROLE_PROFILES = {
    "tech-lead": {"fi-peer-challenge"},
    "ba": {"fi-peer-scout", "fi-peer-challenge", "fi-glm-peer-scout"},
    "frontend": {
        "fi-implementer-mechanical", "fi-implementer-ambiguous",
        "fi-glm-implementer-mechanical",
    },
    "backend": {
        "fi-implementer-mechanical", "fi-implementer-ambiguous",
        "fi-glm-implementer-mechanical",
    },
    "devops": {
        "fi-implementer-mechanical", "fi-implementer-ambiguous",
        "fi-glm-implementer-mechanical",
    },
    "tester": {"fi-peer-scout", "fi-peer-challenge", "fi-glm-peer-scout"},
    "researcher": {"fi-peer-scout", "fi-peer-challenge", "fi-glm-peer-scout"},
    "scout": {"fi-peer-scout", "fi-glm-peer-scout"},
}

# Git provenance is evaluated for the project that owns the envelope, never for
# a caller-selected alternate repository.  Ignore repository-redirection
# variables so a validation or launch subprocess cannot make the attester read
# another worktree (or fail spuriously while an attacker races authorization).
GIT_ENV_KEYS = {
    "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_CEILING_DIRECTORIES", "GIT_DISCOVERY_ACROSS_FILESYSTEM",
}


def git_environment() -> dict[str, str]:
    environment = dict(os.environ)
    for key in GIT_ENV_KEYS:
        environment.pop(key, None)
    return environment


def fail(message: str) -> None:
    raise SystemExit(f"profile attestation: {message}")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_string(value: object, key: str) -> str:
    if not isinstance(value, str) or not value:
        fail(f"expected one {key}")
    return value


def toml_scalar(value: str) -> object:
    value = value.strip()
    if value in ("true", "false"):
        return value == "true"
    if value.isdigit():
        return int(value)
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        try:
            return json.loads(value)
        except json.JSONDecodeError as error:
            fail(f"invalid TOML string: {error}")
    fail(f"unsupported TOML scalar: {value}")


def parse_envelope(text: str) -> dict[str, object]:
    values: dict[str, object] = {}
    for key in ("model", "model_reasoning_effort", "sandbox_mode", "approval_policy", "model_context_window", "model_provider"):
        match = __import__("re").search(rf'(?m)^{key}\s*=\s*(.+?)\s*$', text)
        if match:
            values[key] = toml_scalar(match.group(1))
    instruction = __import__("re").search(r'(?ms)^developer_instructions\s*=\s*"""(.*?)"""\s*$', text)
    if instruction:
        values["developer_instructions"] = instruction.group(1)
    feature = __import__("re").search(r'(?ms)^\[features\]\s*(.*?)(?=^\[|\Z)', text)
    features: dict[str, object] = {}
    if feature:
        for line in feature.group(1).splitlines():
            if "=" in line:
                key, raw = line.split("=", 1)
                features[key.strip()] = toml_scalar(raw)
    values["features"] = features
    provider_name = values.get("model_provider")
    providers: dict[str, dict[str, object]] = {}
    if isinstance(provider_name, str):
        marker = f"[model_providers.{provider_name}]"
        start = text.find(marker)
        if start < 0:
            fail("selected model provider table is missing")
        end = text.find("\n[", start + len(marker))
        section = text[start + len(marker):] if end < 0 else text[start + len(marker):end]
        provider: dict[str, object] = {}
        for line in section.splitlines():
            if "=" in line:
                key, raw = line.split("=", 1)
                provider[key.strip()] = toml_scalar(raw)
        providers[provider_name] = provider
    values["model_providers"] = providers
    return values


def stable_regular_file(path: pathlib.Path) -> tuple[bytes, os.stat_result]:
    try:
        before = os.lstat(path)
        content = path.read_bytes()
        after = os.lstat(path)
    except OSError as error:
        fail(str(error))
    if not stat.S_ISREG(before.st_mode):
        fail(f"not a regular file: {path}")
    if before.st_dev != after.st_dev or before.st_ino != after.st_ino:
        fail(f"file changed while being read: {path}")
    return content, before


def project_provenance(
    project_root: pathlib.Path, policy_root: pathlib.Path, profile_path: pathlib.Path,
    profile_bytes: bytes, metadata: os.stat_result,
) -> dict[str, object]:
    relative = profile_path.relative_to(project_root).as_posix()
    ledger = project_root / ".foundation-integrity" / "adoption.tsv"
    if policy_root.parent.name == ".orchestration":
        ledger_bytes, ledger_metadata = stable_regular_file(ledger)
        try:
            lines = ledger_bytes.decode("utf-8").splitlines()
        except UnicodeDecodeError as error:
            fail(f"adoption ledger is not UTF-8: {error}")
        if not lines or lines[0] != "# foundation-integrity-adoption:v3":
            fail("project adoption ledger is not v3")
        settings: dict[str, str] = {}
        files: dict[str, str] = {}
        modes: dict[str, str] = {}
        for line in lines[1:]:
            fields = line.split("\t")
            if len(fields) != 3:
                continue
            kind, value, path = fields
            if kind == "setting":
                if value in settings:
                    fail(f"duplicate adoption setting: {value}")
                settings[value] = path
            elif kind in ("file", "mode"):
                target = files if kind == "file" else modes
                if path in target:
                    fail(f"duplicate adoption record: {kind} {path}")
                target[path] = value
        digest = sha256_bytes(profile_bytes)
        if files.get(relative) != digest:
            fail("project profile differs from adoption provenance")
        if modes.get(relative) != format(stat.S_IMODE(metadata.st_mode), "o"):
            fail("project profile mode differs from adoption provenance")
        revision = settings.get("source-revision")
        if not revision:
            fail("adoption ledger omitted source revision")
        return {
            "provenance": "project-adoption-v3",
            "provenance_path": str(ledger.resolve()),
            "provenance_sha256": sha256_bytes(ledger_bytes),
            "provenance_device": ledger_metadata.st_dev,
            "provenance_inode": ledger_metadata.st_ino,
            "source_revision": revision,
            "source_tree_state": settings.get("source-tree-state", "unknown"),
        }

    tracked = subprocess.run(
        ["git", "-C", str(project_root), "ls-files", "--error-unmatch", relative],
        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env=git_environment(),
    ).returncode == 0
    if not tracked:
        fail("authoring profile is not tracked by Git")
    revision = subprocess.run(
        ["git", "-C", str(project_root), "rev-parse", "HEAD"],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        env=git_environment(),
    ).stdout.strip()
    dirty = subprocess.run(
        ["git", "-C", str(project_root), "status", "--porcelain", "--", relative],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        env=git_environment(),
    ).stdout.strip()
    return {
        "provenance": "project-source-tree",
        "provenance_path": str((project_root / ".git").resolve()),
        "provenance_sha256": None,
        "provenance_device": None,
        "provenance_inode": None,
        "source_revision": revision,
        "source_tree_state": "dirty" if dirty else "clean",
    }


def main() -> int:
    if len(sys.argv) not in (2, 4):
        fail("usage: attest-codex-profile.py <fi-profile> [--role task-role]")
    profile = sys.argv[1]
    if profile not in PROFILES:
        fail(f"unsupported profile {profile}")
    role = None
    if len(sys.argv) == 4:
        if sys.argv[2] != "--role" or not sys.argv[3]:
            fail("--role requires a task role")
        role = sys.argv[3]
    if role is not None:
        allowed = ROLE_PROFILES.get(role)
        if allowed is None:
            fail(f"unsupported task role {role}")
        if profile not in allowed:
            fail(f"task role {role} is incompatible with profile {profile}")
    if profile == "fi-root-lead" and role is not None:
        fail("root profile cannot receive a coworker task role")

    script_dir = pathlib.Path(__file__).resolve().parent
    policy_root = script_dir.parent
    project_root = policy_root.parent.parent.resolve()
    profile_path = policy_root / "profiles" / "codex" / f"{profile}.config.toml"
    profile_bytes, metadata = stable_regular_file(profile_path)
    digest = sha256_bytes(profile_bytes)
    provenance = project_provenance(
        project_root, policy_root, profile_path, profile_bytes, metadata,
    )
    if profile.startswith("fi-glm-"):
        manifest = project_root / ".foundation" / "cliproxy-glm" / "installed-profiles.tsv"
        manifest_bytes, manifest_metadata = stable_regular_file(manifest)
        try:
            lines = manifest_bytes.decode("utf-8").splitlines()
        except UnicodeDecodeError as error:
            fail(f"project GLM manifest is not UTF-8: {error}")
        records: dict[str, str] = {}
        for line in lines:
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 2 or fields[0] in records:
                fail("project GLM manifest is invalid")
            records[fields[0]] = fields[1]
        if records.get(profile) != digest:
            fail("project GLM profile differs from project gateway provenance")
        provenance.update({
            "gateway_manifest_path": str(manifest.resolve()),
            "gateway_manifest_sha256": sha256_bytes(manifest_bytes),
            "gateway_manifest_device": manifest_metadata.st_dev,
            "gateway_manifest_inode": manifest_metadata.st_ino,
        })
    try:
        data = parse_envelope(profile_bytes.decode("utf-8"))
    except UnicodeDecodeError as error:
        fail(f"profile is not valid UTF-8: {error}")

    model = require_string(data.get("model"), "model")
    base_effort = require_string(data.get("model_reasoning_effort"), "model_reasoning_effort")
    effort = "high" if role == "tech-lead" else base_effort
    sandbox = require_string(data.get("sandbox_mode"), "sandbox_mode")
    approval = require_string(data.get("approval_policy"), "approval_policy")
    base_instructions = require_string(data.get("developer_instructions"), "developer_instructions")
    features = data.get("features")
    if not isinstance(features, dict) or features.get("multi_agent") is not False or features.get("multi_agent_v2") is not False:
        fail("multi_agent=false and multi_agent_v2=false are required")

    instructions = base_instructions
    role_sha256 = None
    role_path = None
    if role is not None:
        common_path = policy_root / "roles" / "common.md"
        selected_path = policy_root / "roles" / f"{role}.md"
        common_bytes, _ = stable_regular_file(common_path)
        role_bytes, _ = stable_regular_file(selected_path)
        common = common_bytes.decode("utf-8").strip()
        role_text = role_bytes.decode("utf-8").strip()
        if not common or not role_text:
            fail("task role card is empty")
        role_sha256 = sha256_bytes(common_bytes + b"\0" + role_bytes)
        role_path = str(selected_path.resolve())
        instructions = (
            base_instructions.rstrip()
            + "\n\nCommon task-role contract:\n" + common
            + "\n\nSelected task-role contract:\n" + role_text + "\n"
        )

    if (profile.startswith("fi-peer-") or profile == "fi-glm-peer-scout") and (sandbox != "read-only" or approval != "never"):
        fail("peer must be read-only with approval never")
    if (profile.startswith("fi-implementer-") or profile == "fi-glm-implementer-mechanical") and sandbox != "workspace-write":
        fail("implementer must use workspace-write")
    if profile == "fi-root-lead" and "Never use Codex native subagents" not in base_instructions:
        fail("root native-delegation prohibition is missing")
    if profile != "fi-root-lead" and not re.search(
        r"Do not\s+create[\s\S]*?transport", base_instructions
    ):
        fail("coworker lifecycle-control prohibition is missing")
    if role == "tech-lead" and not (model == "gpt-5.6-sol" and effort == "high"):
        fail("Tech Lead must use Sol high")
    if profile != "fi-root-lead" and model == "gpt-5.6-sol" and effort != ("high" if role == "tech-lead" else "medium"):
        fail("spawned Sol coworker has an unsupported reasoning effort")

    cli_args = [
        "--model", model,
        "--sandbox", sandbox,
        "--ask-for-approval", approval,
        "-c", f"model_reasoning_effort={json.dumps(effort)}",
        "-c", "features.multi_agent=false",
        "-c", "features.multi_agent_v2=false",
        "-c", f"developer_instructions={json.dumps(instructions)}",
    ]
    context_window = data.get("model_context_window")
    if context_window is not None:
        if not isinstance(context_window, int) or context_window <= 0:
            fail("model_context_window must be a positive integer")
        cli_args.extend(["-c", f"model_context_window={context_window}"])
    model_provider = data.get("model_provider")
    if model_provider is not None:
        provider_name = require_string(model_provider, "model_provider")
        providers = data.get("model_providers")
        provider = providers.get(provider_name) if isinstance(providers, dict) else None
        if not isinstance(provider, dict):
            fail("selected model provider table is missing")
        cli_args.extend(["-c", f"model_provider={json.dumps(provider_name)}"])
        for key in ("name", "base_url", "env_key", "env_key_instructions", "wire_api", "requires_openai_auth"):
            if key not in provider:
                fail(f"model provider omitted {key}")
            cli_args.extend([
                "-c",
                f"model_providers.{provider_name}.{key}={json.dumps(provider[key])}",
            ])

    value = {
        "approval": approval,
        "base_developer_instructions": base_instructions,
        "base_effort": base_effort,
        "cli_args": cli_args,
        "developer_instructions": instructions,
        "device": metadata.st_dev,
        "effort": effort,
        "inode": metadata.st_ino,
        "model": model,
        "multi_agent": False,
        "multi_agent_v2": False,
        "path": str(profile_path.resolve()),
        "profile": profile,
        "profile_tier": "glm-compatibility" if profile.startswith("fi-glm-") else "primary",
        "project_root": str(project_root),
        "role": role,
        "role_path": role_path,
        "role_sha256": role_sha256,
        "sandbox": sandbox,
        "sha256": digest,
        **provenance,
    }
    print(json.dumps(value, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
