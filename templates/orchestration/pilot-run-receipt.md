# Coworker pilot run receipt

Use one copy per run. This is a comparison and lifecycle record, not an automatic score or promotion gate.

Keep raw current-state, worker, transcript, baseline, and pilot artifacts under ignored
runtime/research storage while the run is active. After the root decision, promote the
accepted decision-lossless receipt (verdict, rationale, decisive evidence hashes,
strongest alternative, and next removal point) into `docs/foundation/receipts/` or an
ADR. Never leave durable acceptance represented only by ignored `.foundation/` state.

Fill the machine-bound block and run `scripts/check-pilot-run-receipt.sh <run-contract.tsv> <pilot-run-receipt.md> <role-model-matrix.tsv>`. The validator binds the contract/matrix, root current state, exact worker artifact, transcript, and baseline/pilot result artifacts by SHA-256. It also requires fresh-session policy and a passed write-isolation smoke. It still does not validate reasoning quality or the root's decision.

```markdown
<!-- foundation-integrity-coworker-pilot:v2
run-id: <stable-run-id>
contract-sha256: <sha256-of-run-contract.tsv>
role-model-matrix-sha256: <sha256-of-role-model-matrix.tsv>
runtime: <must-equal-contract-runtime>
current-state-path: <must-equal-contract-current_state_path>
current-state-revision: <git-revision-or-artifact-hash>
current-state-sha256: <sha256-of-current-state-path>
worker-artifact-path: <repo-relative-preserved-worker-output>
worker-artifact-sha256: <sha256-of-worker-artifact>
transcript-path: <repo-relative-transport-transcript-or-excerpt>
transcript-sha256: <sha256-of-transcript>
write-isolation: pass
session-policy: fresh-only
baseline-artifact-path: <repo-relative-simple-baseline-result>
baseline-artifact-sha256: <sha256-of-baseline-artifact>
pilot-artifact-path: <repo-relative-coworker-result>
pilot-artifact-sha256: <sha256-of-pilot-artifact>
incremental-value: <material-counterevidence|traceability|recovery|none>
coordination-cost: <bounded-time-or-turn-count>
decision: keep|amend|remove|inconclusive
-->
```

## Identity

- Run ID (same as bound block):
- Date:
- Repository/worktree and revision:
- Root current-state artifact (same as bound block and contract `current_state_path`):
- Root current-state revision/hash (same as bound block):
- Preserved worker artifact and SHA-256 (same as bound block):
- Transport transcript/excerpt and SHA-256 (same as bound block):
- Run-contract artifact:
- Role/model matrix artifact and hash (same as bound block):
- Runtime and actor/profile bindings:
- Effective launch argv and role-prompt hashes:
- Maintainer-chosen review window:

## Baseline

- Simplest permitted baseline:
- Baseline result/artifact and SHA-256 (same as bound block):
- Why this is a fair comparison:

## Coworker result

- Task packets:
- Worker/reviewer artifacts:
- Pilot result artifact and SHA-256 (same as bound block):
- Validation evidence, command, cwd, revision, and exit status:
- Incremental counterevidence, traceability, or recovery value over baseline:
- Findings duplicated from baseline:

## Coordination and failure evidence

- Root coordination time or turn count:
- Worker time or turn count:
- Misrouted messages, provenance loss, duplicate work, or status-as-truth incidents:
- Resume attempted: yes/no
- Resume launch envelope revalidated: rejected/not-run
- Fresh session IDs or rejected resume IDs (must satisfy `fresh-only`):
- Implementer write-isolation smoke: pass (required before any write-capable role):
- Effective model/effort/tool/permission observations:
- Unknown load-bearing facts:

## Root decision

- Artifacts accepted/rejected/cancelled:
- Did this run justify its coordination cost? yes/no/inconclusive
- Keep, amend, or remove the pilot:
- Rationale and strongest alternative:
- Next review/removal decision point:

`not-run` and `inconclusive` are not evidence of a preserved launch envelope. Resume is not accepted by the current pilot. The receipt informs an explicit maintainer decision; it never promotes the pilot automatically.
