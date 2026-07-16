# Triage label vocabulary

The companion workflow uses these default tracker-label meanings. The strings are
GitHub-compatible defaults, but do not create or rely on them until
`docs/agents/issue-tracker.md` names a configured tracker:

| Label | Meaning |
| --- | --- |
| `needs-triage` | Incoming issue has not been classified. |
| `needs-info` | The decision owner needs more evidence or a reproduction. |
| `ready-for-agent` | Scope, owner, and proof surface are clear enough for bounded implementation. |
| `ready-for-human` | Evidence or a decision requires human judgment. |
| `wontfix` | The issue is intentionally not being pursued, with rationale recorded. |

Changing a label string requires updating the mapping and the tracker workflow
together; do not create duplicate vocabularies for the same state.
