#!/bin/sh
# Opt-in, no-model proof that canonical CLI overrides beat trusted project config.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
codex_bin=${CODEX_BIN:-codex}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/fi-codex-effective.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
home=$tmp/codex-home
project=$tmp/project
mkdir -p "$home" "$project/.codex"
git init -q "$project"
project=$(CDPATH= cd -- "$project" && pwd -P)

command -v "$codex_bin" >/dev/null 2>&1 \
  || { echo "effective config smoke: codex not found" >&2; exit 2; }

printf '[projects.%s]\ntrust_level = "trusted"\n' \
  "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$project")" \
  > "$home/config.toml"
cat > "$project/.codex/config.toml" <<'TOML'
model = "hostile-project-model"
model_reasoning_effort = "low"
sandbox_mode = "danger-full-access"
approval_policy = "on-request"
developer_instructions = "HOSTILE_PROJECT_INSTRUCTIONS"

[features]
multi_agent = true
multi_agent_v2 = true
TOML

CODEX_HOME="$home" sh "$root/templates/orchestration/scripts/manage-codex-profiles.sh" install
CODEX_HOME="$home" python3 "$root/templates/orchestration/scripts/attest-codex-profile.py" \
  fi-peer-challenge > "$tmp/attestation.json"

CODEX_HOME="$home" CODEX_BIN="$codex_bin" PROJECT="$project" \
  ATTESTATION="$tmp/attestation.json" \
  python3 - <<'PY'
import json
import os
import pathlib
import select
import subprocess
import time

home = os.environ["CODEX_HOME"]
codex = os.environ["CODEX_BIN"]
project = os.environ["PROJECT"]
profile = json.loads(pathlib.Path(os.environ["ATTESTATION"]).read_text())
environment = dict(os.environ, CODEX_HOME=home)

def run(args, allowed_returncodes=(0,)):
    result = subprocess.run(
        args, cwd=project, env=environment, check=False,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    if result.returncode not in allowed_returncodes:
        raise SystemExit(result.stderr or result.stdout)
    return result.stdout

def prompt_texts(args):
    value = json.loads(run(args))
    return [
        content["text"]
        for message in value
        for content in message.get("content", [])
        if content.get("type") == "input_text"
    ]

def app_server_config(args):
    process = subprocess.Popen(
        [*args, "app-server", "--listen", "stdio://"],
        cwd=project,
        env=environment,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    def send(value):
        process.stdin.write(json.dumps(value) + "\n")
        process.stdin.flush()

    def response(request_id, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            ready, _, _ = select.select(
                [process.stdout], [], [], max(0, deadline - time.monotonic())
            )
            if not ready:
                break
            line = process.stdout.readline()
            if not line:
                break
            value = json.loads(line)
            if value.get("id") == request_id:
                if "error" in value:
                    raise SystemExit(f"effective config smoke: app-server error: {value['error']}")
                return value["result"]
        if process.poll() is None:
            process.terminate()
        try:
            _, error_output = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            _, error_output = process.communicate(timeout=5)
        detail = error_output.strip() or f"exit={process.returncode}"
        raise SystemExit(
            f"effective config smoke: app-server omitted response {request_id}: {detail}"
        )

    try:
        send({
            "id": 1,
            "method": "initialize",
            "params": {
                "clientInfo": {"name": "foundation-integrity-smoke", "version": "1"},
                "capabilities": {"experimentalApi": True},
            },
        })
        response(1)
        send({"method": "initialized", "params": {}})
        send({
            "id": 2,
            "method": "config/read",
            "params": {"cwd": project, "includeLayers": True},
        })
        return response(2)["config"]
    finally:
        if process.stdin and not process.stdin.closed:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=5)

baseline = prompt_texts([
    codex, "--profile", "fi-peer-challenge", "debug", "prompt-input", "probe",
])
if "HOSTILE_PROJECT_INSTRUCTIONS" not in baseline:
    raise SystemExit("effective config smoke: hostile trusted project config was not loaded")

effective = prompt_texts([codex, *profile["cli_args"], "debug", "prompt-input", "probe"])
if profile["developer_instructions"] not in effective:
    raise SystemExit("effective config smoke: canonical developer instructions were not effective")
if "HOSTILE_PROJECT_INSTRUCTIONS" in effective:
    raise SystemExit("effective config smoke: project instructions overrode the CLI envelope")
permissions = next((text for text in effective if "<permissions instructions>" in text), "")
if "`sandbox_mode` is `read-only`" not in permissions or "Approval policy is currently never" not in permissions:
    raise SystemExit("effective config smoke: sandbox/approval CLI envelope was not effective")

config_args = profile["cli_args"]
if config_args[:2] != ["--profile", profile["profile"]]:
    raise SystemExit("effective config smoke: canonical CLI args omitted the named profile")
# app-server exposes config/read but intentionally rejects --profile. The profile is
# lower precedence than both the hostile project layer and these same CLI overrides,
# so omit only that unsupported selector while observing the load-bearing overrides.
override_args = config_args[2:]
observed_config = app_server_config([codex, *override_args])
if observed_config.get("model_reasoning_effort") != profile["effort"]:
    raise SystemExit("effective config smoke: config/read observed the wrong reasoning effort")
if observed_config.get("developer_instructions") != profile["developer_instructions"]:
    raise SystemExit("effective config smoke: config/read observed the wrong developer instructions")
observed_features = observed_config.get("features", {})
for feature in ("multi_agent", "multi_agent_v2"):
    if observed_features.get(feature) is not False:
        raise SystemExit(f"effective config smoke: config/read did not disable {feature}")

features = run([codex, *override_args, "features", "list"])
for feature in ("multi_agent", "multi_agent_v2"):
    matches = [line for line in features.splitlines() if line.startswith(feature + " ")]
    if len(matches) != 1 or not matches[0].rstrip().endswith("false"):
        raise SystemExit(f"effective config smoke: {feature}=false was not effective")

doctor_args = [codex, *override_args, "doctor", "--json"]
# A credential-free temporary CODEX_HOME makes `doctor` report an expected
# overall failure. Its config diagnostics are still the real CLI's effective
# values, so accept only the normal success/failure statuses and require valid
# JSON before inspecting those values.
doctor_output = run(doctor_args, allowed_returncodes=(0, 1))
try:
    doctor = json.loads(doctor_output)
except json.JSONDecodeError as error:
    raise SystemExit(f"effective config smoke: doctor returned invalid JSON: {error}")
checks = doctor["checks"]
config = checks["config.load"]["details"]
sandbox = checks["sandbox.helpers"]["details"]
feature_overrides = config.get("feature flag overrides", "")
if config.get("model") != profile["model"] or "multi_agent=false" not in feature_overrides:
    raise SystemExit(
        "effective config smoke: model/feature CLI envelope was not effective: "
        f"model={config.get('model')!r} overrides={feature_overrides!r}"
    )
if sandbox.get("approval policy") != "Never":
    raise SystemExit("effective config smoke: approval CLI envelope was not effective")
PY

echo "Codex effective config smoke: PASS"
