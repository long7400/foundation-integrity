#!/usr/bin/env python3
"""Attest one installed Codex profile against the pack source and owner manifest."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import stat
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


def fail(message: str) -> None:
    raise SystemExit(f"profile attestation: {message}")


def one_string(text: str, key: str) -> str:
    matches = re.findall(rf'(?m)^{re.escape(key)}\s*=\s*"([^"]+)"\s*$', text)
    if len(matches) != 1:
        fail(f"expected one {key}")
    return matches[0]


def main() -> int:
    if len(sys.argv) not in (2, 3, 4, 5):
        fail("usage: attest-codex-profile.py <fi-profile> [codex-home] [--role task-role]")
    profile = sys.argv[1]
    if profile not in PROFILES:
        fail(f"unsupported profile {profile}")

    remaining = list(sys.argv[2:])
    role = None
    if "--role" in remaining:
        index = remaining.index("--role")
        if index + 1 >= len(remaining):
            fail("--role requires a task role")
        role = remaining[index + 1]
        del remaining[index:index + 2]
    if len(remaining) > 1:
        fail("too many arguments")
    if role is not None:
        allowed = ROLE_PROFILES.get(role)
        if allowed is None:
            fail(f"unsupported task role {role}")
        if profile not in allowed:
            fail(f"task role {role} is incompatible with profile {profile}")
    if profile == "fi-root-lead" and role is not None:
        fail("root profile cannot receive a coworker task role")

    script_dir = pathlib.Path(__file__).resolve().parent
    source = script_dir.parent / "profiles" / "codex" / f"{profile}.config.toml"
    home = pathlib.Path(remaining[0] if remaining else os.environ.get("CODEX_HOME", pathlib.Path.home() / ".codex"))
    installed = home / f"{profile}.config.toml"
    manifest = home / "foundation-integrity-profiles.json"

    try:
        source_bytes = source.read_bytes()
        installed_metadata = os.lstat(installed)
    except OSError as error:
        fail(str(error))
    if not stat.S_ISREG(installed_metadata.st_mode):
        fail("installed profile must be a regular file")

    installed_bytes = installed.read_bytes()
    after_read = os.lstat(installed)
    if (
        after_read.st_dev != installed_metadata.st_dev
        or after_read.st_ino != installed_metadata.st_ino
    ):
        fail("installed profile changed while being read")
    digest = hashlib.sha256(installed_bytes).hexdigest()
    if installed_bytes != source_bytes:
        fail("installed profile differs from the reviewed pack source")

    if profile.startswith("fi-glm-"):
        config_home = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config"))
        glm_manifest = config_home / "foundation-integrity" / "cliproxy-glm" / "installed-profiles.tsv"
        try:
            glm_metadata = os.lstat(glm_manifest)
            lines = glm_manifest.read_text(encoding="utf-8").splitlines()
        except OSError as error:
            fail(f"GLM ownership manifest: {error}")
        if not stat.S_ISREG(glm_metadata.st_mode):
            fail("GLM ownership manifest must be a regular file")
        records = {}
        for line in lines:
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 2 or fields[0] in records:
                fail("GLM ownership manifest is invalid")
            records[fields[0]] = fields[1]
        if records.get(profile) != digest:
            fail("installed GLM profile differs from ownership provenance")
        profile_tier = "glm-compatibility"
    else:
        try:
            manifest_metadata = os.lstat(manifest)
            manifest_value = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception as error:
            fail(f"invalid ownership manifest: {error}")
        if not stat.S_ISREG(manifest_metadata.st_mode):
            fail("ownership manifest must be a regular file")
        if manifest_value.get("schema") != "foundation-integrity-codex-profiles:v2":
            fail("ownership manifest schema is not v2")
        files = manifest_value.get("files")
        record = files.get(installed.name) if isinstance(files, dict) else None
        if not isinstance(record, dict) or set(record) != {"device", "inode", "sha256"}:
            fail("ownership manifest omitted exact object provenance")
        if (
            installed_metadata.st_dev != record["device"]
            or installed_metadata.st_ino != record["inode"]
            or digest != record["sha256"]
        ):
            fail("installed profile differs from ownership provenance")
        profile_tier = "primary"

    try:
        text = installed_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"profile is not UTF-8: {error}")
    model = one_string(text, "model")
    base_effort = one_string(text, "model_reasoning_effort")
    effort = "high" if role == "tech-lead" else base_effort
    sandbox = one_string(text, "sandbox_mode")
    approval = one_string(text, "approval_policy")
    instruction_matches = re.findall(
        r'(?ms)^developer_instructions\s*=\s*"""(.*?)"""\s*$', text
    )
    if len(instruction_matches) != 1 or not instruction_matches[0]:
        fail("profile envelope omitted developer_instructions")
    base_instructions = instruction_matches[0]
    instructions = base_instructions
    role_sha256 = None
    role_path = None
    if role is not None:
        common_path = script_dir.parent / "roles" / "common.md"
        selected_path = script_dir.parent / "roles" / f"{role}.md"
        try:
            common = common_path.read_text(encoding="utf-8").strip()
            role_text = selected_path.read_text(encoding="utf-8").strip()
        except OSError as error:
            fail(f"task role card: {error}")
        if not common or not role_text:
            fail("task role card is empty")
        role_bytes = common_path.read_bytes() + b"\0" + selected_path.read_bytes()
        role_sha256 = hashlib.sha256(role_bytes).hexdigest()
        role_path = str(selected_path.resolve())
        instructions = (
            base_instructions.rstrip()
            + "\n\nCommon task-role contract:\n"
            + common
            + "\n\nSelected task-role contract:\n"
            + role_text
            + "\n"
        )
    features = re.findall(r'(?ms)^\[features\]\s*(.*?)(?=^\[|\Z)', text)
    if len(features) != 1:
        fail("one features table is required")
    for feature in ("multi_agent", "multi_agent_v2"):
        if not re.search(rf'(?m)^{feature}\s*=\s*false\s*$', features[0]):
            fail(f"{feature}=false is required")
    if (profile.startswith("fi-peer-") or profile == "fi-glm-peer-scout") and (sandbox != "read-only" or approval != "never"):
        fail("peer must be read-only with approval never")
    if (profile.startswith("fi-implementer-") or profile == "fi-glm-implementer-mechanical") and sandbox != "workspace-write":
        fail("implementer must use workspace-write")
    if profile == "fi-root-lead" and "Never use Codex native subagents" not in base_instructions:
        fail("root native-delegation prohibition is missing")
    if profile != "fi-root-lead" and not (
        re.search(r"Do not\s+create[\s\S]*?transport", base_instructions)
        or ("Do not delegate or" in base_instructions and "supervise other" in base_instructions)
    ):
        fail("coworker lifecycle-control prohibition is missing")
    if role == "tech-lead" and not (model == "gpt-5.6-sol" and effort == "high"):
        fail("Tech Lead must use Sol high")
    if profile != "fi-root-lead" and model == "gpt-5.6-sol" and effort != ("high" if role == "tech-lead" else "medium"):
        fail("spawned Sol coworker has an unsupported reasoning effort")

    cli_args = [
        "--profile", profile,
        "--model", model,
        "--sandbox", sandbox,
        "--ask-for-approval", approval,
        "-c", f"model_reasoning_effort={json.dumps(effort)}",
        "-c", "features.multi_agent=false",
        "-c", "features.multi_agent_v2=false",
        "-c", f"developer_instructions={json.dumps(instructions)}",
    ]

    print(json.dumps({
        "approval": approval,
        "codex_home": str(home.resolve()),
        "cli_args": cli_args,
        "developer_instructions": instructions,
        "base_developer_instructions": base_instructions,
        "base_effort": base_effort,
        "device": installed_metadata.st_dev,
        "effort": effort,
        "inode": installed_metadata.st_ino,
        "model": model,
        "multi_agent": False,
        "multi_agent_v2": False,
        "path": str(installed.resolve()),
        "profile": profile,
        "profile_tier": profile_tier,
        "role": role,
        "role_path": role_path,
        "role_sha256": role_sha256,
        "sandbox": sandbox,
        "sha256": digest,
    }, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
