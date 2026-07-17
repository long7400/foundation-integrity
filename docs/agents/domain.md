# Domain-document layout

This repository uses a single context by default:

- `CONTEXT.md` — the shared domain language and current system map, created only when
  there is durable vocabulary or a model decision to record.
- `docs/adr/` — local architectural working decisions; `0000-template.md` is the
  tracked reusable shape, while numbered personal history is ignored by default.
- `docs/research/` — ignored, project-local research notes. Do not treat this as a
  canonical evidence store or push its contents.
- `docs/foundation/receipts/` — ignored machine-bound review records; keep only
  `.gitkeep` tracked. Promote accepted decision-lossless conclusions into
  `CONTEXT.md`, an explicitly shared ADR, or another durable project owner.
- `.foundation/` — ignored runtime, research-process, planning, and orchestration
  artifacts.

Introduce a `CONTEXT-MAP.md` and per-area contexts only when the repository gains real
monorepo or ownership boundaries. Do not create context files merely to satisfy a
workflow template.
