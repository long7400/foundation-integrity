#!/usr/bin/env python3
"""Report best-effort Codex pane telemetry without taking lifecycle authority."""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time
from typing import Any


SOURCE = "foundation-integrity:codex-telemetry"
TOKEN_KEYS = (
    "ctx",
    "left",
    "compact",
    "cache_ratio",
    "cached",
    "spent",
    "last_turn",
    "idle",
    "cache_hint",
)
TAIL_BYTES = 8 * 1024 * 1024
CONTEXT_BASELINE = 12_000


def read_hook_input() -> dict[str, Any]:
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


def ancestor_pids() -> set[int]:
    result: set[int] = set()
    pid = os.getpid()
    for _ in range(16):
        if pid <= 1 or pid in result:
            break
        result.add(pid)
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
    return result


def discover_pane_id(herdr: str) -> str | None:
    explicit = os.environ.get("HERDR_PANE_ID")
    if explicit:
        return explicit
    ancestors = ancestor_pids()
    panes = run_json([herdr, "pane", "list"])
    if not panes:
        return None
    values = panes.get("result", {}).get("panes", [])
    if not isinstance(values, list):
        return None
    for pane in values[:32]:
        pane_id = pane.get("pane_id") if isinstance(pane, dict) else None
        if not isinstance(pane_id, str) or not pane_id:
            continue
        info = run_json([herdr, "pane", "process-info", "--pane", pane_id], timeout=0.3)
        process = info.get("result", {}).get("process_info", {}) if info else {}
        foreground = process.get("foreground_processes", [])
        if any(isinstance(item, dict) and item.get("pid") in ancestors for item in foreground):
            return pane_id
    return None


def latest_token_record(path: pathlib.Path) -> tuple[str | None, dict[str, Any] | None]:
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            handle.seek(max(0, size - TAIL_BYTES))
            data = handle.read()
    except OSError:
        return None, None

    for raw_line in reversed(data.splitlines()):
        if b'"type":"token_count"' not in raw_line:
            continue
        try:
            record = json.loads(raw_line)
        except Exception:
            continue
        payload = record.get("payload")
        if not isinstance(payload, dict) or payload.get("type") != "token_count":
            continue
        info = payload.get("info")
        if isinstance(info, dict):
            timestamp = record.get("timestamp")
            return timestamp if isinstance(timestamp, str) else None, info
    return None, None


def compact_count(path: pathlib.Path) -> int | None:
    count = 0
    try:
        with path.open("rb") as handle:
            for raw_line in handle:
                if b'"compacted"' not in raw_line:
                    continue
                try:
                    record = json.loads(raw_line)
                except Exception:
                    continue
                if isinstance(record, dict) and record.get("type") == "compacted":
                    count += 1
    except OSError:
        return None
    return count


def integer(value: Any) -> int | None:
    return value if isinstance(value, int) and value >= 0 else None


def percent(numerator: int, denominator: int) -> int:
    if denominator <= 0:
        return 0
    return min(100, max(0, (numerator * 100 + denominator // 2) // denominator))


def human_tokens(value: int) -> str:
    if value >= 1_000_000:
        rendered = f"{value / 1_000_000:.1f}".rstrip("0").rstrip(".")
        return f"{rendered}m"
    if value >= 1_000:
        return f"{round(value / 1_000):d}k"
    return str(value)


def parse_time(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def build_tokens(
    info: dict[str, Any] | None,
    compactions: int | None,
    last_timestamp: str | None,
    now: dt.datetime,
    hook_event: str,
) -> dict[str, str]:
    tokens: dict[str, str] = {}
    if compactions is not None:
        tokens["compact"] = f"compact {compactions}"
    if not info:
        return tokens

    total = info.get("total_token_usage")
    if isinstance(total, dict):
        spent = integer(total.get("total_tokens"))
        if spent is not None:
            tokens["spent"] = f"spent {human_tokens(spent)}"

    if hook_event == "PostCompact":
        # The newest token record commonly describes the pre-compact window. Do not
        # present it as current until a later request emits fresh usage telemetry.
        tokens["ctx"] = "ctx pending"
        tokens["cache_ratio"] = "cache pending"
        tokens["cache_hint"] = "after compact"
        tokens["last_turn"] = f"compact seen {now.strftime('%Y-%m-%dT%H:%MZ')}"
        return tokens

    last = info.get("last_token_usage")
    window = integer(info.get("model_context_window"))
    if isinstance(last, dict):
        last_total = integer(last.get("total_tokens"))
        if window and last_total is not None and window > CONTEXT_BASELINE:
            effective = window - CONTEXT_BASELINE
            used = min(effective, max(0, last_total - CONTEXT_BASELINE))
            used_pct = percent(used, effective)
            tokens["ctx"] = f"ctx {used_pct}%"
            tokens["left"] = f"left {100 - used_pct}%"

        input_tokens = integer(last.get("input_tokens"))
        cached = integer(last.get("cached_input_tokens"))
        cache_pct: int | None = None
        if input_tokens is not None and input_tokens > 0 and cached is not None:
            cache_pct = percent(cached, input_tokens)
            tokens["cache_ratio"] = f"cache {cache_pct}%"
            tokens["cached"] = f"cached {human_tokens(cached)}"

        last_time = parse_time(last_timestamp)
        if last_time is not None:
            age = max(0.0, (now - last_time).total_seconds())
            if hook_event == "Stop":
                tokens["last_turn"] = f"stop seen {now.strftime('%Y-%m-%dT%H:%MZ')}"
                tokens["idle"] = f"idle since {now.strftime('%H:%MZ')}"
            else:
                tokens["last_turn"] = f"usage seen {last_time.strftime('%Y-%m-%dT%H:%MZ')}"
            # This is deliberately marked as a question. The prior request's cache
            # hit and idle age cannot prove routing or retention for the next turn.
            if cache_pct == 0:
                tokens["cache_hint"] = "last miss"
            elif cache_pct is not None and cache_pct >= 50 and age <= 1800:
                tokens["cache_hint"] = "hot?"
            elif age > 7200:
                tokens["cache_hint"] = "cold?"
            else:
                tokens["cache_hint"] = "cache uncertain"

    return tokens


def main() -> int:
    hook_input = read_hook_input()
    herdr = shutil.which(os.environ.get("HERDR_BIN", "herdr"))
    if not herdr:
        return 0
    pane_id = discover_pane_id(herdr)
    if not pane_id:
        return 0

    transcript_value = hook_input.get("transcript_path")
    transcript = pathlib.Path(transcript_value) if isinstance(transcript_value, str) else None
    timestamp: str | None = None
    info: dict[str, Any] | None = None
    compactions: int | None = None
    if transcript and transcript.is_file():
        timestamp, info = latest_token_record(transcript)
        compactions = compact_count(transcript)

    now_epoch = os.environ.get("FI_TELEMETRY_NOW_EPOCH")
    try:
        now = dt.datetime.fromtimestamp(float(now_epoch), dt.timezone.utc) if now_epoch else dt.datetime.now(dt.timezone.utc)
    except ValueError:
        now = dt.datetime.now(dt.timezone.utc)
    hook_event = str(hook_input.get("hook_event_name") or "")
    tokens = build_tokens(info, compactions, timestamp, now, hook_event)

    seq = str(time.time_ns())
    command = [
        herdr,
        "pane",
        "report-metadata",
        pane_id,
        "--source",
        SOURCE,
        "--seq",
        seq,
        "--ttl-ms",
        "86400000",
    ]
    for key in TOKEN_KEYS:
        value = tokens.get(key)
        if value is None:
            command.extend(("--clear-token", key))
        else:
            command.extend(("--token", f"{key}={value}"))
    try:
        subprocess.run(
            command,
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
