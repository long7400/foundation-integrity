# Review receipt

A receipt records that a foundation decision was made for a specific change. The
surface-guard hook clears a changed surface file only when a receipt (or ADR) **in the
same change set carries a valid v2 receipt block that names that file's exact path**.
That binding is the point: it makes skipping the review a deliberate, auditable act
instead of a free pass earned by touching any unrelated ADR.

## Honest scope — read this first

There are two modes, and they promise different things:

- **advisory (default).** The receipt is a **text artifact an agent can author**. A
  valid receipt proves a decision was *recorded and structured*, **not** that an
  independent review happened or that its verdict is honest. What advisory mode buys is
  *visibility and a versioned audit trail* a human or a different-model check can later
  inspect — not proof. The guard still binds the receipt to the exact revision and
  changed-content digest, so a receipt copied from another change cannot clear this one.
- **attested (opt-in, `FI_REVIEW_MODE=attested`).** Clearing a surface change
  additionally requires a **cryptographically signed attestation commit** from a key on
  a trusted-reviewer allowlist that lives *outside* the working tree. This resists a
  single agent that can edit files but does not hold the reviewer's signing key. It
  still does not prove the reviewer *thought hard* — only that an isolated key was used.
  It is authoritative only when a protected CI/branch-protection rule re-runs the
  verification; a local hook remains bypassable. See "Residual limits" in
  `templates/docs/why-foundation-integrity.md`.

## The v2 receipt block

Put a receipt in `docs/foundation/receipts/<short-name>.md`, or embed the same block in a
full ADR under `docs/adr/`. The machine-read part is the delimited block below; write
whatever prose you like around it.

```markdown
# Review receipt — <short title>

<!-- foundation-integrity-receipt:v2
classification: FOUNDATION_OK
route: Feature-first
reviewer: human:alice
verdict: upholds
outcome: PROCEED
revision: <exact git revision checked by the guard>
change-digest: <SHA-256 changed-content manifest, excluding receipt/ADR files>
evidence-ref: commit:<exact commit, diff, or decision record>
evidence-ref: path:<repo-relative runtime observation or test artifact>
canonical-invariant: Orders have exactly one authoritative status lifecycle.
surface-path: db/migrations/0007_orders.sql
surface-path: src/api/orders.ts
-->
```

### Fields (all required; order-free; inside the delimiters only)

| Field | Rule |
| --- | --- |
| `classification` | one of `FOUNDATION_OK`, `FOUNDATION_SUSPECT`, `FOUNDATION_BLOCKED` |
| `route` | one of `Feature-first`, `Bounded-compatibility`, `Foundation-first` |
| `reviewer` | non-empty; convention `human:<name>` / `model:<name>` / `harness:<id>` |
| `verdict` | one of `upholds`, `amends`, `overturns` |
| `outcome` | one of `PROCEED`, `RESEARCH_ONLY`, `NO_GO`; only `PROCEED` can clear a surface |
| `revision` | exact left-boundary revision checked by the guard (HEAD in worktree mode; the range base in push/CI mode) |
| `change-digest` | 64-hex SHA-256 of the changed-content manifest; receipt/ADR files are excluded |
| `evidence-ref` | one or more machine-readable refs: `commit:`, `path:`, `run:`, or `url:`; `path:` refs must exist at the checked revision |
| `canonical-invariant` | non-empty single sentence — the one invariant the change preserves |
| `surface-path` | one line **per** covered path; exact repo-relative path as git reports it |

Exactly one of each scalar field (`classification`, `route`, `reviewer`, `verdict`,
`outcome`, `revision`, `change-digest`, `canonical-invariant`); one or more
`evidence-ref` and `surface-path` lines.

### What clears the guard

A surface file is cleared only if a receipt block in the change set:

- is **well-formed** (delimiters closed, all scalar fields present exactly once, enums valid), AND
- binds to the exact checked revision and changed-content digest, and names at least one
  machine-readable evidence reference, AND
- has a **clearing verdict** — `upholds` or `amends`. `overturns` never clears (the
  reviewer rejected the decision). `outcome: RESEARCH_ONLY` or `NO_GO`,
  `classification: FOUNDATION_BLOCKED`, or `FOUNDATION_SUSPECT` combined with
  `route: Feature-first`, never clears, AND
- lists that file's **exact path** in a `surface-path` line (exact string match — `foo`
  never matches `foo-old`; spaces are preserved).

Paths containing a newline are rejected (portable shell can't handle them losslessly) —
rename the file. Absolute paths and paths containing `..` are rejected.

In **attested** mode all of the above still applies, and additionally the `reviewer`
must equal the identity mapped from the signing key of the attestation commit (see
`foundation-surface-guard.sh` header and the why-doc). A self-authored
`reviewer: human:me` does not satisfy attested mode without the matching signature.
