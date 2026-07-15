# Domain-document layout

This repository uses a single context by default:

- `CONTEXT.md` — the shared domain language and current system map, created only when
  there is durable vocabulary or a model decision to record.
- `docs/adr/` — architectural decisions and their evidence.
- `docs/research/` — ignored, project-local research notes. Do not treat this as a
  canonical evidence store or push its contents. Promote accepted conclusions into
  an ADR, `docs/foundation/receipts/`, `CONTEXT.md`, or another explicitly durable
  project document.
- `docs/foundation/receipts/` and accepted evidence paths — machine-bound review
  records; keep them trackable. `.foundation/` is reserved for ignored runtime,
  research-process, planning, and orchestration artifacts.

Introduce a `CONTEXT-MAP.md` and per-area contexts only when the repository gains real
monorepo or ownership boundaries. Do not create context files merely to satisfy a
workflow template.
