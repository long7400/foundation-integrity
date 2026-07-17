# Coworker pilot receipt

Use this only to decide whether external coworkers add enough counterevidence,
traceability, or recovery value to justify their coordination cost. It is not an
automatic score or acceptance gate.

## Run

- Date, repository revision, and requested outcome:
- Root and fresh coworker session IDs:
- Root pre-launch receipt (profile provenance, pane IDs, PID/start, cwd, argv):
- Exact task packet or its SHA-256:
- Bound launch receipt (profile object/hash; model/effort/access values derived from
  the observed launch argv, not continuously attested runtime state; observed session
  if available; mandatory process PID/start/argv/cwd and IDs):
- Sessions created by this run and therefore eligible for teardown:
- Team receipt, relay pane/tab, specialist artifact hashes, and Tech Lead synthesis
  hash when `wait-coworker-team` was used:

## Evidence

- Baseline result:
- Coworker observations and exact evidence pointers:
- Counterevidence, disagreements, and unknown load-bearing facts:
- Validation lease, revision, cwd, exact command, exit status, and output:
- Strongest alternative:

## Coordination failures

- Prompt submitted once and runtime transition observed: yes/no
- Misrouting, duplicate prompt/work, status-as-truth, or provenance loss:
- Blocked/time-out recovery:
- Root and coworker time or turn count:
- Model-visible root status-check turns while the team was merely working (target 0):
- Root wake count after Tech Lead synthesis or relay failure (target at most 1):

## Root decision

- Accepted, rejected, or cancelled artifacts:
- Incremental value over the baseline:
- Keep, amend, or remove the pilot:
- Rationale and next removal/review point:

Raw output may remain in the live session or a root-selected `$TMPDIR`. If the
decision matters later, promote this concise receipt and stable evidence pointers to
the project's chosen durable owner before teardown. Never claim that pane status,
profile text, telemetry, or this self-authored receipt proves correctness.
