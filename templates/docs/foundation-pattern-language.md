# Foundation pattern language

These names are optional mnemonics for recurring foundation failures. They help a human and an agent refer to the same shape quickly; they are not findings, evidence, scores, or keyword rules.

## Brake — `foundation.missing_safety_primitive`

The system is accelerating capability before the owning foundation supplies the safety, lifecycle, rollback, or failure-handling primitive that makes the capability governable.

Examples include adding more operations before there is authoritative cancellation, shipping durable writes before rollback/recovery is defined, or scaling concurrency before ownership and ordering are explicit.

Required investigation:

- Which primitive is missing?
- Which owner should supply it?
- Which failure model makes it necessary?
- What executable scenario would prove the primitive exists?
- Would building the feature now freeze unsafe behavior into an API, schema, or durable state?

A feature without every conceivable safety mechanism is not automatically Brake. The missing primitive must be load-bearing for the requested outcome and failure model.

## Balloon — `foundation.workaround_amplification`

Semantics that belong in the foundation are pushed upward into features or adapters, so each new capability needs more state, locks, wrappers, retries, translations, synchronized writes, or exceptions to keep the weak base aloft.

Investigation triggers:

- a wrapper owns state or control flow rather than translating one true boundary;
- the same invariant is checked by several callers;
- lifecycle, retry, or locking appears outside the authoritative owner;
- change coupling and blast radius grow with each feature;
- tests mainly preserve a workaround;
- a temporary seam survives repeated removal conditions.

A single adapter at a real external boundary is not Balloon. A lock placed at the correct owner is not Balloon. Async, sync, actors, mutexes, wrappers, and retries are mechanisms; none is guilty by keyword.

## Runtime camouflage — `foundation.boundary_camouflage`

This is a subtype of ownership/boundary mismatch: a runtime or framework supplies ordering, lifetime, error, or state semantics that the domain foundation never made explicit.

For a deterministic core, a useful probe is whether the core can be driven and replayed without the runtime while the adapter owns I/O and scheduling. That is not a universal demand for sync or sans-I/O: when asynchronous ordering is itself a domain semantic, an async-first owner such as a structured actor/mailbox can be the sound foundation.

## Evidence record

Use the semantic code as an optional observation field, then attach:

- the foundation claim and authoritative owner;
- required primitive and failure model;
- exact locations and existing mismatch signals;
- primary evidence and reproduction procedure;
- a disconfirming probe with `survived`, `broke`, or `inconclusive` result;
- the relevant fitness check and baseline;
- route/removal implication.

Example:

```text
observation: foundation.workaround_amplification
alias: Balloon
derived_from: wrapper-around-wrapper, cross-layer-leakage, change-coupling
claim: protocol state transitions have one authoritative owner
probe: replay transitions without the async adapter
result: inconclusive
```

`unknown`, `not_run`, and `inconclusive` are not green. Never use a Balloon/Brake score. If the name does not change which claim, counterexample, or check should be examined, remove the name and keep the generic mismatch signals.

## Hook and receipt boundary

The pack's v2 review receipt binds revision, changed-content digest, and evidence references, but still does not decide pattern semantics, probe quality, or fitness results. Balloon and Brake therefore remain optional semantic annotations, not machine-attested findings. Never infer a pattern from keywords.

Until such a schema exists, attach the executable evidence to the ordinary receipt or ADR and state `semantic-only` when no honest machine check exists. Do not claim that a hook verified the alias.
