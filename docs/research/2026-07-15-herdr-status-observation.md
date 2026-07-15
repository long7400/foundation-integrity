# Herdr status observation — 2026-07-15

- **Observation window:** 2026-07-15, Asia/Ho_Chi_Minh; receipt written at `2026-07-15T21:25:02+07:00`.
- **Runtime:** `herdr 0.7.3`.
- **Scope:** sanitized liveness/status evidence from the read-only coworker review; pane and session identifiers are intentionally omitted because they are continuity pointers, not proof.
- **Repository snapshot:** `1fc2da4b1095975be9671cae084c7f0b24bd2f1d`, cwd `/Users/long7400/project/foundation-integrity`.
- **Archived output:** [`artifacts/2026-07-15-herdr-status-excerpt.txt`](./artifacts/2026-07-15-herdr-status-excerpt.txt) preserves exact selected field values, commands, and exit statuses with continuity identifiers removed. Its SHA-256 is recorded below.
- **Source comparison:** Herdr commit [`d0111c9f9022e0ec26d8f03236a91b026b567d45`](https://github.com/ogulcancelik/herdr/commit/d0111c9f9022e0ec26d8f03236a91b026b567d45).

## Commands

```sh
herdr api snapshot
herdr pane get <pane-id>
herdr wait agent-status <pane-id> --status working --timeout 30000
herdr wait agent-status <pane-id> --status done --timeout 60000
herdr pane read <pane-id> --source recent-unwrapped --lines 140
```

## Sanitized observations

1. Before a task was submitted, newly opened coworker panes appeared as `idle`. Therefore `idle` alone did not mean that assigned work had completed.
2. After an open review task was submitted, the bounded wait observed a `working` transition.
3. The terminal later rendered the review's final verdict and returned to its input prompt, while `herdr pane get` still reported `agent_status: working`; bounded waits for `done` timed out.
4. Reading the pane transcript exposed the completed artifact even though the attention state had not converged.

Archived sanitized output excerpt:

```text
artifact: docs/research/artifacts/2026-07-15-herdr-status-excerpt.txt
sha256: 8a11f5ccc34f7487e92a2113ccbe077437428ab5346b2045652c0edff0a278bd
```

## Verdict and uncertainty

Transport status is useful for attention and bounded monitoring, but it is not authoritative task state, artifact validity, acceptance, or release evidence. The source defines `idle`/`done` attention semantics; this runtime observation additionally shows that detection may lag rendered completion.

This was not a controlled timing experiment, so it does not estimate status latency or prove every transition behaves the same way. The pilot therefore requires pane/artifact inspection plus the root-owned current-state record instead of status-as-truth.
