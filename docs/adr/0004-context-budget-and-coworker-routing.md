# ADR-0004: Retain the 24-skill distribution and budget active context

- **Status:** accepted
- **Date:** 2026-07-16
- **Foundation route:** Foundation-first
- **Classification:** FOUNDATION_BLOCKED for the deletion decision and old Codex routing; FOUNDATION_SUSPECT for downstream context activation
- **Outcome:** PROCEED with restoration, measured active-surface budgets, and corrected routing

## Requested outcome

Preserve the two reasons this pack exists—falsify weak foundations before feature
work, and support one-root independent external coworkers—while keeping downstream
context proportional. Correct the Codex capability order without treating repository
file count or installed skill-body bytes as prompt context.

The shipped distribution remains 24 skills: three standalone first-party skills and
a commit-pinned 21-skill companion. Changing that installation contract requires an
explicit product decision, not a context-cleanup shortcut.

## Foundation claims and evidence

### Distribution ownership

- Base revision `1fbc3a42fdb61fd75accc8339155cce9b255d683`, both manifests,
  both runtime projections, README/install documentation, provenance, notices, and
  repository contracts define a 24-skill distribution.
- The 21 companion sources and their projection/provenance surfaces were restored.
  `third_party/mattpocock-skills/promoted-files.sha256` passes.
- The three first-party skills remain standalone. The companion is not a source of
  foundation-gate or coworker authority.

### Stored bytes versus active context

- The current Codex manual documents progressive disclosure: the initial skill list
  contains discovery metadata; the full `SKILL.md` loads only when selected. The
  initial list is separately budgeted and may shorten descriptions or omit entries
  when crowded. It also documents `codex debug prompt-input` as the exact
  model-visible prompt renderer.
  - Skills: <https://learn.chatgpt.com/docs/build-skills>
  - Prompt renderer: <https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-debug-prompt-input>
- A downstream Codex fixture rendered with `codex debug prompt-input` showed:
  - 24 `SKILL.md` bodies occupied 128,930 bytes on disk;
  - nine companion skills were present as initial discovery entries, totaling 2,603
    bytes including the project skill-root line;
  - the fifteen explicit-only skills did not appear in the initial catalog;
  - an unrelated probe with an 852,173-byte body exposed its short description but
    not its body sentinel;
  - copying the full `templates/` tree without adopting it did not inject template
    contents; and
  - copying `templates/claude-md-block.md` to consumer `AGENTS.md` added that block to
    the first request, increasing the rendered user-message surface from 550 to
    2,812 bytes in that fixture.
- `claude --plugin-dir . plugin details foundation-integrity` reports 24 skills,
  zero agents/hooks/MCP/LSP components, approximately 1,118 always-on discovery
  tokens, and full bodies charged on invocation. This is a runtime estimate, not an
  exact serialized request trace.
- Ordinary docs, ADRs, templates, provenance files, and repository source are inert
  until a runtime, skill, tool, or user explicitly reads or adopts them.

### Performance evidence

Primary research does not justify a universal “more tokens always makes the model
worse” rule:

- *Lost in the Middle* finds strong position effects in long-context retrieval and
  multi-document QA: <https://doi.org/10.1162/tacl_a_00638>.
- *Large Language Models Can Be Easily Distracted by Irrelevant Context* isolates
  accuracy loss from irrelevant statements: <https://arxiv.org/abs/2302.00093>.
- RULER shows that simple needle retrieval overstates effective long-context ability:
  <https://arxiv.org/abs/2404.06654>.
- LongBench reports task- and model-dependent long-context behavior rather than
  universal collapse: <https://aclanthology.org/2024.acl-long.172/>.
- RepoCoder and Repoformer provide counterevidence to indiscriminate deletion:
  relevant iterative retrieval can help, while selective retrieval avoids harmful
  or unnecessary context:
  <https://aclanthology.org/2023.emnlp-main.826/> and
  <https://arxiv.org/abs/2403.10059>.

These studies are not direct coding-agent context-budget thresholds. They support
measuring relevance, conflict, position, and activation—not using repository size as
a proxy.

## Decision

1. Retain the 24-skill distribution and all canonical/projection/provenance surfaces.
2. Budget only active surfaces controlled by this pack:
   - the reusable consumer instruction block remains below 3,000 bytes;
   - aggregate skill discovery descriptions remain below 5,000 bytes;
   - full bodies, docs, and templates are not treated as always-on context;
   - setup copies or merges only explicitly selected instruction/template surfaces.
3. Keep first-party foundation skills explicit-only and load their bodies when the
   always-loaded gate or user request requires them.
4. Preserve progressive disclosure. Do not duplicate skill procedures into
   `AGENTS.md`, role prompts, or orchestration manuals.
5. Keep orchestration opt-in. Ordinary tasks do not load its manuals. When explicitly
   requested, one root loads the policy, protocol, and active runtime adapter.
6. Use only `root`, `peer`, and `implementer` as authority roles. Work class is
   separate:
   - Codex root/control: `gpt-5.6-sol`, `xhigh`;
   - challenge/ambiguous: `gpt-5.6-sol`, `medium`;
   - scout/mechanical: `gpt-5.6-luna`, `max`.
7. Keep ADR Markdown as durable tracked evidence once accepted. `docs/adr/` needs no
   `.gitkeep` while tracked ADR files exist. Raw `docs/research/` and `.foundation/`
   artifacts remain ignored working evidence.

## Canonical invariant

The pack ships 24 skills, but installation payload is not equivalent to prompt
context. Runtimes may expose bounded discovery metadata; skill bodies load on
invocation; consumer instructions load only when adopted; ordinary templates and
repository files remain inert until read. Optimize and test those lifecycle seams
without deleting requested capability.

## Strongest alternative

Split the companion into a separately installed plugin. This would reduce discovery
metadata for users who choose only the three-skill core, but it changes the requested
one-install distribution and introduces dependency/version coordination. The measured
current cost—approximately 1,118 Claude discovery tokens and a bounded Codex catalog—
does not by itself justify that contract change. Do not implement the split without
explicit user acceptance and comparative task-quality evidence.

## Blast radius, coupling, and reversibility

- No application API, schema, migration, or durable domain data changes.
- Companion restoration returns source, projections, manifests, provenance, notices,
  and documentation to one owner. Removing only one surface would recreate parity and
  licensing debt.
- Description and consumer-instruction budgets are reversible project policy; they do
  not alter full skill capability.
- Old Codex profile names are removed rather than aliased, preventing silent reuse of
  the inverted mapping. Existing live sessions retain their launch envelope; future
  sessions use the new profiles.
- Orchestration remains an opt-in, removable seam whose value must continue to beat a
  single-root baseline.

## Fitness checks

- exactly 24 canonical skills and matching Claude/Codex projections;
- companion allowlist, license, notice, patch ledger, and SHA-256 verification;
- manifest/projection parity;
- consumer instruction block below 3,000 bytes and aggregate discovery descriptions
  below 5,000 bytes;
- first-party explicit-invocation policy remains intact;
- exact role/model/work-class matrix and no old live profile aliases;
- run contracts accept only root/peer/implementer and require bounded writer scopes;
- optional templates are not described or installed as automatic consumer context;
- accepted ADR Markdown is tracked; ignored research/runtime artifacts are not the
  sole durable evidence.

## Unknowns

- Papers do not establish a universal safe token threshold for agentic coding.
- Codex may shorten or omit discovery entries when the complete installed catalog
  reaches its budget; task-quality impact needs a representative multi-task benchmark.
- Claude's projected token figure is an estimate and may differ from exact serialized
  requests.
- The first non-interactive token-count experiment was non-monotonic across fixtures;
  exact `prompt-input` inspection is stronger evidence than raw one-shot usage deltas.
- Resume remains disallowed for accepted coworker work until the complete effective
  profile/instruction/permission envelope is attested.
