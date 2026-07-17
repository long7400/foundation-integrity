#!/usr/bin/env python3
"""Bounded Herdr team fan-in with one Tech Lead semantic channel to root."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import stat
import subprocess
import sys
import time
from datetime import datetime, timezone
from typing import Any


TEAM_SCHEMA = "foundation-integrity-coworker-team:v1"
STATE_SCHEMA = "foundation-integrity-coworker-team-state:v1"
CAPTURE_SCHEMA = "foundation-integrity-coworker-capture:v1"
TERMINAL = {"idle", "done", "blocked"}


class RelayError(RuntimeError):
    pass


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fail(message: str) -> None:
    raise RelayError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_private_regular(path: pathlib.Path) -> bytes:
    try:
        before = os.lstat(path)
        value = path.read_bytes()
        after = os.lstat(path)
    except OSError as error:
        fail(str(error))
    if not stat.S_ISREG(before.st_mode) or (
        before.st_dev != after.st_dev or before.st_ino != after.st_ino
    ):
        fail(f"file changed while being read: {path}")
    if before.st_mode & 0o077:
        fail(f"file is not private: {path}")
    return value


def load_json(path: pathlib.Path) -> tuple[dict[str, Any], bytes]:
    raw = require_private_regular(path)
    try:
        value = json.loads(raw)
    except Exception as error:
        fail(f"invalid JSON {path}: {error}")
    if not isinstance(value, dict):
        fail(f"JSON object required: {path}")
    return value, raw


def atomic_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    encoded = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    descriptor = os.open(
        temporary,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
        0o600,
    )
    try:
        view = memoryview(encoded)
        while view:
            view = view[os.write(descriptor, view) :]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.replace(temporary, path)


def exclusive_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    encoded = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0),
        0o600,
    )
    try:
        view = memoryview(encoded)
        while view:
            view = view[os.write(descriptor, view) :]
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def run(args: list[str], *, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        fail(f"command failed ({' '.join(args)}): {detail}")
    return result


def herdr_json(args: list[str]) -> dict[str, Any]:
    try:
        value = json.loads(run(["herdr", *args]).stdout)
    except json.JSONDecodeError as error:
        fail(f"invalid Herdr JSON for {' '.join(args)}: {error}")
    if not isinstance(value, dict):
        fail(f"invalid Herdr response for {' '.join(args)}")
    return value


def resolve_member(team_path: pathlib.Path, binding: dict[str, Any]) -> tuple[pathlib.Path, dict[str, Any], bytes]:
    relative = binding.get("receipt")
    if not isinstance(relative, str) or not relative or pathlib.PurePath(relative).is_absolute():
        fail("team member receipt path is invalid")
    path = (team_path.parent / relative).resolve()
    if path.parent != team_path.parent.resolve():
        fail("team member receipt escaped the private team directory")
    value, raw = load_json(path)
    if sha256_bytes(raw) != binding.get("sha256"):
        fail(f"team member receipt hash differs: {path.name}")
    return path, value, raw


def load_team(team_path: pathlib.Path) -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    try:
        directory = os.lstat(team_path.parent)
    except OSError as error:
        fail(str(error))
    if not stat.S_ISDIR(directory.st_mode) or directory.st_mode & 0o077:
        fail("team directory must be private and non-symlinked")
    team, _ = load_json(team_path)
    if team.get("schema") != TEAM_SCHEMA:
        fail("invalid team receipt schema")
    lead_binding = team.get("lead")
    specialists = team.get("specialists")
    if not isinstance(lead_binding, dict) or not isinstance(specialists, list):
        fail("team receipt omitted members")
    if not 1 <= len(specialists) <= 3 or not all(isinstance(item, dict) for item in specialists):
        fail("team must contain one to three specialists")
    _, lead, _ = resolve_member(team_path, lead_binding)
    members = [resolve_member(team_path, item)[1] for item in specialists]
    if lead.get("task_role") != "tech-lead":
        fail("team lead receipt is not bound to tech-lead")
    if any(member.get("task_role") in (None, "tech-lead") for member in members):
        fail("specialist receipt has an invalid task role")
    all_members = [lead, *members]
    identity = [(item.get("workspace_id"), item.get("tab_id"), item.get("pane_id")) for item in all_members]
    if len(set(identity)) != len(identity):
        fail("team receipts reuse a coworker target")
    root_binding = team.get("root")
    if not isinstance(root_binding, dict):
        fail("team receipt omitted root binding")
    root_path, root, _ = resolve_member(team_path, root_binding)
    if root.get("schema") != "foundation-integrity-codex-root-launch:v1":
        fail("invalid root launch receipt schema")
    workspace = root.get("workspace_id")
    if any(item.get("workspace_id") != workspace for item in all_members):
        fail("team members are outside the root workspace")
    if root_path.name != "root.launch.json":
        fail("unexpected root receipt snapshot name")
    return team, lead, members


def attest_member(receipt: dict[str, Any], receipt_bytes: bytes, script_dir: pathlib.Path) -> dict[str, Any]:
    if receipt.get("schema") != "foundation-integrity-codex-launch:v2":
        fail("invalid coworker launch receipt schema")
    role = receipt.get("task_role")
    if not isinstance(role, str) or not role:
        fail("team coworker launch receipt omitted task_role")
    attestation = json.loads(
        run(
            [
                "python3",
                str(script_dir / "attest-codex-profile.py"),
                str(receipt.get("profile", "")),
                "--role",
                role,
            ]
        ).stdout
    )
    if receipt.get("profile_attestation") != attestation:
        fail("coworker profile provenance differs from launch receipt")
    instructions = attestation.get("developer_instructions")
    if not isinstance(instructions, str) or receipt.get("developer_instructions_sha256") != sha256_bytes(instructions.encode()):
        fail("coworker effective developer instructions differ from launch receipt")
    return attestation


def live_member(
    receipt: dict[str, Any], receipt_bytes: bytes, script_dir: pathlib.Path
) -> tuple[str, dict[str, Any]]:
    attest_member(receipt, receipt_bytes, script_dir)
    pane = str(receipt.get("pane_id", ""))
    agent_response = herdr_json(["agent", "get", pane])
    agent = agent_response.get("result", {}).get("agent", {})
    if not isinstance(agent, dict):
        fail("Herdr agent response omitted agent")
    for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name"):
        if agent.get(key) != receipt.get(key):
            fail(f"live coworker {key} differs from launch receipt")
    session = agent.get("agent_session")
    live_session = session.get("value") if isinstance(session, dict) else None
    expected_session = receipt.get("agent_session_id")
    if expected_session and live_session != expected_session:
        fail("live coworker session differs from launch receipt")
    process = herdr_json(["pane", "process-info", "--pane", pane]).get("result", {}).get("process_info", {})
    foreground = process.get("foreground_processes", []) if isinstance(process, dict) else []
    matches = [
        item
        for item in foreground
        if isinstance(item, dict)
        and item.get("argv") == receipt.get("process_argv")
        and item.get("cwd") == receipt.get("cwd")
        and item.get("pid") == receipt.get("process_pid")
    ]
    if len(matches) != 1:
        fail("effective coworker process differs from launch receipt")
    started = subprocess.run(
        ["ps", "-o", "lstart=", "-p", str(receipt.get("process_pid"))],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    ).stdout.strip()
    if not started or started != receipt.get("process_started_at"):
        fail("coworker process start identity differs from launch receipt")
    status = agent.get("agent_status")
    if status not in {"working", "idle", "done", "blocked", "unknown"}:
        fail(f"unexpected coworker status: {status}")
    return str(status), agent


def capture(
    team_path: pathlib.Path,
    label: str,
    receipt: dict[str, Any],
    receipt_bytes: bytes,
    status: str,
    lines: int,
) -> pathlib.Path:
    output = run(
        [
            "herdr",
            "pane",
            "read",
            str(receipt["pane_id"]),
            "--source",
            "recent-unwrapped",
            "--lines",
            str(lines),
            "--format",
            "text",
        ]
    ).stdout
    if not output.strip():
        fail(f"{label} output is empty")
    artifact = team_path.parent / "artifacts" / f"{label}.json"
    exclusive_json(
        artifact,
        {
            "schema": CAPTURE_SCHEMA,
            "captured_at": now(),
            "name": receipt.get("name"),
            "task_role": receipt.get("task_role"),
            "pane_id": receipt.get("pane_id"),
            "agent_session_id": receipt.get("agent_session_id"),
            "receipt_sha256": sha256_bytes(receipt_bytes),
            "status": status,
            "output": output,
            "output_sha256": sha256_bytes(output.encode()),
        },
    )
    return artifact


def write_state(team_path: pathlib.Path, phase: str, **extra: Any) -> None:
    atomic_json(
        team_path.parent / "state.json",
        {"schema": STATE_SCHEMA, "phase": phase, "updated_at": now(), **extra},
    )


def wait_for_terminal(
    pending: dict[str, tuple[dict[str, Any], bytes]],
    team_path: pathlib.Path,
    script_dir: pathlib.Path,
    deadline: float,
    initial_delay: float,
    max_delay: float,
    lines: int,
) -> dict[str, tuple[str, pathlib.Path]]:
    completed: dict[str, tuple[str, pathlib.Path]] = {}
    delay = initial_delay
    previous: dict[str, str] = {}
    while pending:
        if time.monotonic() >= deadline:
            fail("team fan-in timed out before all specialists became terminal")
        changed = False
        for label in list(pending):
            receipt, receipt_bytes = pending[label]
            status, _ = live_member(receipt, receipt_bytes, script_dir)
            if previous.get(label) != status:
                previous[label] = status
                changed = True
            if status in TERMINAL:
                artifact = capture(team_path, label, receipt, receipt_bytes, status, lines)
                completed[label] = (status, artifact)
                del pending[label]
                changed = True
        if pending:
            time.sleep(delay)
            delay = initial_delay if changed else min(max_delay, delay * 2)
    return completed


def root_live_status(team_path: pathlib.Path, team: dict[str, Any]) -> str:
    _, root, _ = resolve_member(team_path, team["root"])
    pane = str(root.get("pane_id", ""))
    agent = herdr_json(["agent", "get", pane]).get("result", {}).get("agent", {})
    if not isinstance(agent, dict):
        fail("root agent response omitted agent")
    for key in ("workspace_id", "tab_id", "pane_id", "terminal_id", "name"):
        if agent.get(key) != root.get(key):
            fail(f"live root {key} differs from launch receipt")
    process = herdr_json(["pane", "process-info", "--pane", pane]).get("result", {}).get("process_info", {})
    foreground = process.get("foreground_processes", []) if isinstance(process, dict) else []
    matches = [
        item
        for item in foreground
        if isinstance(item, dict)
        and item.get("argv") == root.get("process_argv")
        and item.get("cwd") == root.get("cwd")
        and item.get("pid") == root.get("process_pid")
    ]
    if len(matches) != 1:
        fail("live root process differs from launch receipt")
    started = subprocess.run(
        ["ps", "-o", "lstart=", "-p", str(root.get("process_pid"))],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    ).stdout.strip()
    if not started or started != root.get("process_started_at"):
        fail("root process start identity differs from launch receipt")
    return str(agent.get("agent_status", "unknown"))


def wake_root(team_path: pathlib.Path, team: dict[str, Any], kind: str, deadline: float) -> None:
    delay = max(0.05, int(team.get("poll_initial_ms", 250)) / 1000)
    max_delay = max(delay, int(team.get("poll_max_ms", 5000)) / 1000)
    while time.monotonic() < deadline:
        if root_live_status(team_path, team) == "idle":
            break
        time.sleep(delay)
        delay = min(max_delay, delay * 2)
    else:
        fail("root did not become idle before the team relay timeout")
    collect_script = pathlib.Path(__file__).with_name("collect-coworker-team.sh")
    if kind == "synthesis-ready":
        message = (
            f"Coworker team {team['team_name']} has a new Tech Lead synthesis ready. "
            f"Collect the Tech Lead artifact only with: sh {collect_script} {team_path}"
        )
    else:
        message = (
            f"Coworker team {team['team_name']} relay changed to failed. "
            f"Inspect its private state with: sh {collect_script} {team_path}"
        )
    intent = team_path.parent / "wake-intent.json"
    exclusive_json(
        intent,
        {
            "schema": "foundation-integrity-coworker-team-wake:v1",
            "created_at": now(),
            "kind": kind,
            "message_sha256": sha256_bytes(message.encode()),
            "root_pane_id": resolve_member(team_path, team["root"])[1].get("pane_id"),
        },
    )
    root_pane = str(resolve_member(team_path, team["root"])[1]["pane_id"])
    run(["herdr", "agent", "send", root_pane, message])
    exclusive_json(
        team_path.parent / "wake-typed.json",
        {"schema": "foundation-integrity-coworker-team-wake-typed:v1", "typed_at": now()},
    )
    timeout_ms = str(int(team.get("submit_timeout_ms", 3000)))
    for _ in range(2):
        run(["herdr", "pane", "send-keys", root_pane, "enter"])
        observed = subprocess.run(
            ["herdr", "wait", "agent-status", root_pane, "--status", "working", "--timeout", timeout_ms],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if observed.returncode == 0:
            exclusive_json(
                team_path.parent / "wake.json",
                {"schema": "foundation-integrity-coworker-team-wake-complete:v1", "submitted_at": now()},
            )
            return
    fail("root wake text was typed once but no working transition was observed")


def relay(team_path: pathlib.Path) -> int:
    script_dir = pathlib.Path(__file__).resolve().parent
    team, lead, specialists = load_team(team_path)
    timeout_ms = int(team.get("timeout_ms", 900000))
    initial_ms = int(team.get("poll_initial_ms", 250))
    max_ms = int(team.get("poll_max_ms", 5000))
    lines = int(team.get("output_lines", 600))
    if timeout_ms < 1000 or initial_ms < 25 or max_ms < initial_ms or lines < 20:
        fail("team relay timing configuration is invalid")
    deadline = time.monotonic() + timeout_ms / 1000
    write_state(team_path, "collecting-specialists")
    pending: dict[str, tuple[dict[str, Any], bytes]] = {}
    for index, binding in enumerate(team["specialists"], start=1):
        _, receipt, raw = resolve_member(team_path, binding)
        initial_status, _ = live_member(receipt, raw, script_dir)
        if initial_status == "idle":
            fail(
                f"specialist-{index} is idle; submit its open task before starting the team relay"
            )
        pending[f"specialist-{index}"] = (receipt, raw)
    completed = wait_for_terminal(
        pending,
        team_path,
        script_dir,
        deadline,
        initial_ms / 1000,
        max_ms / 1000,
        lines,
    )
    lead_path, lead, lead_raw = resolve_member(team_path, team["lead"])
    lead_status, _ = live_member(lead, lead_raw, script_dir)
    if lead_status == "idle":
        fail("Tech Lead is idle; complete its planning turn before starting the team relay")
    delay = initial_ms / 1000
    while lead_status not in TERMINAL:
        if time.monotonic() >= deadline:
            fail("Tech Lead planning turn did not become terminal")
        time.sleep(delay)
        delay = min(max_ms / 1000, delay * 2)
        lead_status, _ = live_member(lead, lead_raw, script_dir)
    if lead_status == "blocked":
        fail("Tech Lead planning turn is blocked")
    planning = capture(team_path, "tech-lead-planning", lead, lead_raw, lead_status, lines)
    index_entries = []
    for index, binding in enumerate(team["specialists"], start=1):
        receipt = resolve_member(team_path, binding)[1]
        status, artifact = completed[f"specialist-{index}"]
        artifact_raw = require_private_regular(artifact)
        index_entries.append(
            {
                "name": receipt.get("name"),
                "task_role": receipt.get("task_role"),
                "status": status,
                "artifact": str(artifact),
                "artifact_sha256": sha256_bytes(artifact_raw),
            }
        )
    index_path = team_path.parent / "artifacts" / "specialist-index.json"
    exclusive_json(
        index_path,
        {
            "schema": "foundation-integrity-coworker-artifact-index:v1",
            "created_at": now(),
            "team_name": team["team_name"],
            "specialists": index_entries,
        },
    )
    packet = (
        "Specialist fan-in is complete. Read the immutable artifact index at "
        f"{index_path}. Reconcile evidence and disagreements, then return one concise, "
        "decision-lossless Tech Lead synthesis for root. Include blockers, cross-slice "
        "implications, recommended order, and acceptance evidence. Do not forward raw "
        "specialist chatter when the synthesis preserves the decision."
    )
    write_state(team_path, "awaiting-tech-lead-synthesis", specialist_index=str(index_path))
    submit_environment = os.environ.copy()
    submit_environment["FI_SUBMIT_TIMEOUT_MS"] = str(team.get("submit_timeout_ms", 3000))
    result = subprocess.run(
        [
            "sh",
            str(script_dir / "submit-coworker-turn.sh"),
            "--collected-output",
            str(planning),
            str(lead_path),
        ],
        input=packet,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=submit_environment,
        check=False,
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or "could not submit specialist index to Tech Lead")
    delay = initial_ms / 1000
    while True:
        if time.monotonic() >= deadline:
            fail("Tech Lead synthesis timed out")
        status, _ = live_member(lead, lead_raw, script_dir)
        if status in TERMINAL:
            if status == "blocked":
                fail("Tech Lead synthesis is blocked")
            synthesis_capture = capture(team_path, "tech-lead-synthesis", lead, lead_raw, status, lines)
            synthesis, synthesis_raw = load_json(synthesis_capture)
            write_state(
                team_path,
                "synthesis-ready",
                synthesis_artifact=str(synthesis_capture),
                synthesis_artifact_sha256=sha256_bytes(synthesis_raw),
                synthesis_output_sha256=synthesis["output_sha256"],
            )
            try:
                wake_root(team_path, team, "synthesis-ready", deadline)
                return 0
            except Exception as error:
                write_state(
                    team_path,
                    "synthesis-ready",
                    synthesis_artifact=str(synthesis_capture),
                    synthesis_artifact_sha256=sha256_bytes(synthesis_raw),
                    synthesis_output_sha256=synthesis["output_sha256"],
                    wake_error=str(error) or error.__class__.__name__,
                )
                print(f"wait-coworker-team: synthesis ready but root wake failed: {error}", file=sys.stderr)
                return 1
        time.sleep(delay)
        delay = min(max_ms / 1000, delay * 2)


def collect(team_path: pathlib.Path) -> int:
    team, _, _ = load_team(team_path)
    state, _ = load_json(team_path.parent / "state.json")
    if state.get("schema") != STATE_SCHEMA:
        fail("invalid team state schema")
    if state.get("phase") == "failed":
        print(f"wait-coworker-team: relay failed: {state.get('error', 'unknown failure')}", file=sys.stderr)
        return 3
    if state.get("phase") != "synthesis-ready":
        fail(f"Tech Lead synthesis is not ready; phase={state.get('phase')}")
    artifact_value = state.get("synthesis_artifact")
    if not isinstance(artifact_value, str):
        fail("team state omitted synthesis artifact")
    artifact_path = pathlib.Path(artifact_value).resolve()
    if artifact_path.parent != (team_path.parent / "artifacts").resolve():
        fail("synthesis artifact escaped the team directory")
    artifact, raw = load_json(artifact_path)
    if sha256_bytes(raw) != state.get("synthesis_artifact_sha256"):
        fail("synthesis artifact hash differs from ready state")
    if artifact.get("schema") != CAPTURE_SCHEMA or artifact.get("task_role") != "tech-lead":
        fail("invalid Tech Lead synthesis artifact")
    output = artifact.get("output")
    if not isinstance(output, str) or sha256_bytes(output.encode()) != state.get("synthesis_output_sha256"):
        fail("Tech Lead synthesis output hash differs from ready state")
    if team.get("team_name") is None:
        fail("team receipt omitted team name")
    sys.stdout.write(output)
    return 0


def close(team_path: pathlib.Path) -> int:
    team, _, _ = load_team(team_path)
    script_dir = pathlib.Path(__file__).resolve().parent
    targets: list[tuple[str, str, str, str, dict[str, Any], bytes]] = []
    for binding in [team["lead"], *team["specialists"]]:
        _, receipt, raw = resolve_member(team_path, binding)
        targets.append(
            (
                str(receipt["workspace_id"]),
                str(receipt["tab_id"]),
                str(receipt["pane_id"]),
                str(receipt["name"]),
                receipt,
                raw,
            )
        )
    relay_binding = team.get("relay")
    if not isinstance(relay_binding, dict):
        fail("team receipt omitted relay target")
    relay_pane = str(relay_binding.get("pane_id", ""))
    relay_tab = str(relay_binding.get("tab_id", ""))
    relay_workspace = str(relay_binding.get("workspace_id", ""))
    pane = herdr_json(["pane", "get", relay_pane]).get("result", {}).get("pane", {})
    if not isinstance(pane, dict) or any(
        pane.get(key) != expected
        for key, expected in (("workspace_id", relay_workspace), ("tab_id", relay_tab), ("pane_id", relay_pane))
    ):
        fail("live relay pane differs from team receipt")
    for workspace, tab, pane_id, name, receipt, raw in targets:
        live_member(receipt, raw, script_dir)
        agent = herdr_json(["agent", "get", pane_id]).get("result", {}).get("agent", {})
        if not isinstance(agent, dict) or any(
            agent.get(key) != expected
            for key, expected in (
                ("workspace_id", workspace),
                ("tab_id", tab),
                ("pane_id", pane_id),
                ("name", name),
            )
        ):
            fail(f"live coworker differs before teardown: {name}")
    run(["herdr", "tab", "close", relay_tab])
    for _, tab, _, _, _, _ in targets:
        run(["herdr", "tab", "close", tab])
    atomic_json(
        team_path.parent / "teardown.json",
        {"schema": "foundation-integrity-coworker-team-teardown:v1", "closed_at": now()},
    )
    return 0


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in {"relay", "collect", "close"}:
        print("usage: wait-coworker-team.py relay|collect|close TEAM_RECEIPT", file=sys.stderr)
        return 2
    team_path = pathlib.Path(sys.argv[2]).resolve()
    try:
        if sys.argv[1] == "relay":
            try:
                return relay(team_path)
            except Exception as error:
                message = str(error) or error.__class__.__name__
                try:
                    team, _, _ = load_team(team_path)
                    write_state(team_path, "failed", error=message)
                    timeout_ms = int(team.get("timeout_ms", 900000))
                    wake_root(team_path, team, "failed", time.monotonic() + timeout_ms / 1000)
                except Exception as wake_error:
                    print(f"wait-coworker-team: relay failed: {message}; wake failed: {wake_error}", file=sys.stderr)
                return 1
        if sys.argv[1] == "collect":
            return collect(team_path)
        return close(team_path)
    except RelayError as error:
        print(f"wait-coworker-team: {error}", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"wait-coworker-team: unexpected failure: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
