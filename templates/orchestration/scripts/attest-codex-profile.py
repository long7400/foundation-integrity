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
}


def fail(message: str) -> None:
    raise SystemExit(f"profile attestation: {message}")


def one_string(text: str, key: str) -> str:
    matches = re.findall(rf'(?m)^{re.escape(key)}\s*=\s*"([^"]+)"\s*$', text)
    if len(matches) != 1:
        fail(f"expected one {key}")
    return matches[0]


def main() -> int:
    if len(sys.argv) not in (2, 3):
        fail("usage: attest-codex-profile.py <fi-profile> [codex-home]")
    profile = sys.argv[1]
    if profile not in PROFILES:
        fail(f"unsupported profile {profile}")

    script_dir = pathlib.Path(__file__).resolve().parent
    source = script_dir.parent / "profiles" / "codex" / f"{profile}.config.toml"
    home = pathlib.Path(sys.argv[2] if len(sys.argv) == 3 else os.environ.get("CODEX_HOME", pathlib.Path.home() / ".codex"))
    installed = home / f"{profile}.config.toml"
    manifest = home / "foundation-integrity-profiles.json"

    try:
        source_bytes = source.read_bytes()
        installed_metadata = os.lstat(installed)
        manifest_metadata = os.lstat(manifest)
    except OSError as error:
        fail(str(error))
    if not stat.S_ISREG(installed_metadata.st_mode) or not stat.S_ISREG(manifest_metadata.st_mode):
        fail("installed profile and ownership manifest must be regular files")

    try:
        manifest_value = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as error:
        fail(f"invalid ownership manifest: {error}")
    if manifest_value.get("schema") != "foundation-integrity-codex-profiles:v2":
        fail("ownership manifest schema is not v2")
    files = manifest_value.get("files")
    record = files.get(installed.name) if isinstance(files, dict) else None
    if not isinstance(record, dict) or set(record) != {"device", "inode", "sha256"}:
        fail("ownership manifest omitted exact object provenance")

    installed_bytes = installed.read_bytes()
    after_read = os.lstat(installed)
    if (
        after_read.st_dev != installed_metadata.st_dev
        or after_read.st_ino != installed_metadata.st_ino
    ):
        fail("installed profile changed while being read")
    digest = hashlib.sha256(installed_bytes).hexdigest()
    if (
        installed_metadata.st_dev != record["device"]
        or installed_metadata.st_ino != record["inode"]
        or digest != record["sha256"]
    ):
        fail("installed profile differs from ownership provenance")
    if installed_bytes != source_bytes:
        fail("installed profile differs from the reviewed pack source")

    try:
        text = installed_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"profile is not UTF-8: {error}")
    model = one_string(text, "model")
    effort = one_string(text, "model_reasoning_effort")
    sandbox = one_string(text, "sandbox_mode")
    approval = one_string(text, "approval_policy")
    instruction_matches = re.findall(
        r'(?ms)^developer_instructions\s*=\s*"""(.*?)"""\s*$', text
    )
    if len(instruction_matches) != 1 or not instruction_matches[0]:
        fail("profile envelope omitted developer_instructions")
    instructions = instruction_matches[0]
    features = re.findall(r'(?ms)^\[features\]\s*(.*?)(?=^\[|\Z)', text)
    if len(features) != 1:
        fail("one features table is required")
    for feature in ("multi_agent", "multi_agent_v2"):
        if not re.search(rf'(?m)^{feature}\s*=\s*false\s*$', features[0]):
            fail(f"{feature}=false is required")
    if profile.startswith("fi-peer-") and (sandbox != "read-only" or approval != "never"):
        fail("peer must be read-only with approval never")
    if profile.startswith("fi-implementer-") and sandbox != "workspace-write":
        fail("implementer must use workspace-write")
    if profile == "fi-root-lead" and "Never use Codex native subagents" not in instructions:
        fail("root native-delegation prohibition is missing")
    if profile != "fi-root-lead" and not (
        "Do not delegate or" in instructions and "supervise other" in instructions
    ):
        fail("coworker non-delegation instruction is missing")

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
        "device": installed_metadata.st_dev,
        "effort": effort,
        "inode": installed_metadata.st_ino,
        "model": model,
        "multi_agent": False,
        "multi_agent_v2": False,
        "path": str(installed.resolve()),
        "profile": profile,
        "sandbox": sandbox,
        "sha256": digest,
    }, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
