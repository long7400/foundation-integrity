#!/usr/bin/env python3
"""Report Codex session continuity to Herdr without owning lifecycle state."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from typing import Any


SOURCE = "foundation-integrity:codex-session"


def hook_input() -> dict[str, Any]:
    try:
        value = json.load(sys.stdin)
    except Exception:
        return {}
    return value if isinstance(value, dict) else {}


def run_json(command: list[str], timeout: float = 0.5) -> dict[str, Any] | None:
    try:
        result = subprocess.run(
            command,
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
            text=True,
        )
        value = json.loads(result.stdout)
    except Exception:
        return None
    return value if isinstance(value, dict) else None


def ancestors() -> set[int]:
    values: set[int] = set()
    pid = os.getpid()
    for _ in range(16):
        if pid <= 1 or pid in values:
            break
        values.add(pid)
        try:
            parent = subprocess.run(
                ["ps", "-o", "ppid=", "-p", str(pid)],
                check=False,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=0.2,
                text=True,
            ).stdout.strip()
            pid = int(parent)
        except Exception:
            break
    return values


def pane_id(herdr: str) -> str | None:
    explicit = os.environ.get("HERDR_PANE_ID")
    if explicit:
        return explicit
    ancestor_pids = ancestors()
    panes = run_json([herdr, "pane", "list"])
    for pane in panes.get("result", {}).get("panes", []) if panes else []:
        candidate = pane.get("pane_id") if isinstance(pane, dict) else None
        if not isinstance(candidate, str) or not candidate:
            continue
        info = run_json([herdr, "pane", "process-info", "--pane", candidate], 0.3)
        process = info.get("result", {}).get("process_info", {}) if info else {}
        if any(
            isinstance(item, dict) and item.get("pid") in ancestor_pids
            for item in process.get("foreground_processes", [])
        ):
            return candidate
    return None


def main() -> int:
    value = hook_input()
    if value.get("hook_event_name") != "SessionStart":
        return 0
    session_id = value.get("session_id")
    if not isinstance(session_id, str) or not session_id:
        return 0
    herdr = shutil.which(os.environ.get("HERDR_BIN", "herdr"))
    if not herdr:
        return 0
    target = pane_id(herdr)
    if not target:
        return 0
    try:
        subprocess.run(
            [
                herdr,
                "pane",
                "report-agent-session",
                target,
                "--source",
                SOURCE,
                "--agent",
                "codex",
                "--seq",
                str(time.time_ns()),
                "--agent-session-id",
                session_id,
            ],
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
