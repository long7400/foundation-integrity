# Claude Code installation

## Choose one surface

### One-command repo setup

Run from the target repository. Full-opt is the only supported payload:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude
```

`--full-opt` is accepted for clarity but already selected by default. Preview with
`--dry-run`; use `--directory <repo>` when not
running inside the target and `--ref <tag-or-commit>` to choose the payload snapshot.
The bootstrap installs the checked 24-skill Claude projection and selected project
assets but does not edit instruction owners, mutate global Claude settings, or
activate orchestration.

### Plugin install

Use this when you want the versioned bundle, namespaced commands, and marketplace
updates:

```text
/plugin marketplace add long7400/foundation-integrity
/plugin install foundation-integrity@foundation-integrity
```

Claude plugins load skills from the plugin root's standard `skills/` directory. The
commands are namespaced by the plugin name. Project, local, and user installation
scopes are selected by the Claude plugin installer; the installed bundle is managed by
Claude rather than copied into the repository's `.claude/skills/` directory.

First invocation:

```text
/foundation-integrity:foundation-audit Audit the foundation before design.
```

### Standalone project skills

Use this when the repository should own unnamespaced project skills directly. Copy the
checked `.claude/skills/` projection into the target repository at the same path:

```text
<repo>/.claude/skills/<skill-name>/SKILL.md
```

The projection intentionally omits Codex-only `agents/openai.yaml` metadata. Do not
copy `.agents/skills/` into Claude's project configuration.

Standalone invocation is unnamespaced:

```text
/foundation-audit Audit the foundation before design.
```

## Bundled versus active state

No Foundation Integrity or Matt setup command is required for skill discovery.
Plugin or manual skill-only installation does not adopt repository files. The
one-command project adopter does, using final project-owned paths rather than a
downstream `templates/` directory.

The three Foundation Integrity skills work without tracker configuration. Companion
tracker flows expect project-specific `docs/agents/` files and report a gap when they
are absent. For local-checkout adoption, preview and run the same underlying adopter
explicitly:

```bash
sh templates/setup/full-opt.sh --runtime claude --full-opt --dry-run <repo>
sh templates/setup/full-opt.sh --runtime claude --full-opt <repo>
```

Full-opt installs the 24 managed pack skills in the Claude projection, creates a short
consumer-neutral `AGENTS.md` only when `AGENTS.md` is absent, preserves existing
`AGENTS.md` and `CLAUDE.md`, merges the ignore block, copies/customizes exactly four
`docs/agents/` files, installs three `docs/foundation/` references, and installs
`docs/adr/0000-template.md`, fitness guidance, and inert orchestration. Hooks install
managed scripts under `.claude/hooks/scripts/`, a real `.claude/settings.json`, and the
warn-only pre-commit when conflict-free. Blocking pre-push is an explicit
`--with-pre-push` option. Orchestration policy remains inert under
`.orchestration/foundation/`; user launch envelopes are not installed. The adoption
lock at `.foundation-integrity/adoption.tsv` records exact
content and file modes and permits later updates only for unchanged managed files.

When upgrading a v2 adoption, owned legacy template files are retired but empty
legacy parent directories may remain: the v2 ledger cannot prove directory ownership.
If a new v3 destination already exists with identical content but is absent from the
v2 ledger, the upgrade stops for explicit reconciliation instead of guessing whether
it was left by an interrupted run or owned by the project.
The legacy instruction files are preserved byte-for-byte and their ownership is
transferred to the project. Before any migration mutation, the v2 adoption lock
records the exact operation plan and binds the exact pending journal under
`.foundation/`; an unbound journal has no ownership authority. The journal is cleared
only after the v3 ledger is committed.

Pre-existing identical non-skill files and hooks remain external rather than becoming
silent deletion authority. The target lock serializes cooperating installer runs;
apply-time revalidation narrows concurrent-edit races but does not make shell copying
transactional against arbitrary external writers.

Instruction ownership remains a project decision. The installer creates only its
short generic `AGENTS.md` bootstrap when the target has none; it never merges,
replaces, or claims an existing `AGENTS.md` or `CLAUDE.md`, including when another
runtime is added later.

Use `--no-pre-commit` to avoid newly wiring the hook. On an upgrade, that flag retains
an unchanged pre-commit already owned by the adoption lock; it is not an uninstall
operation.

## Ignore behavior

The package ships a root `.gitignore` and
`templates/gitignore/foundation-integrity.gitignore`. Claude's plugin manager installs
the bundle into its managed location; it does not edit the consumer repository's root
`.gitignore` or create `docs/research/` in the consumer repository. A standalone
project install copies only `.claude/skills/`; it also does not create that directory.
Merge the marked ignore block explicitly so `.foundation/`, `.orchestration/`,
`.codex/`, `.agents/`, `docs/research/`, `tmp/`, and numbered personal ADR history
remain local when tools create them later.
In a full-opt consumer those ignored directories are intentional local payload;
`.foundation-integrity/adoption.tsv` remains outside the ignore block and binds the
installed revision, content hashes, and modes for later conflict-safe upgrades.

The standalone projection is the skill surface, not a hidden full-project installer.
Use the project adopter when the full measurement, hook, and orchestration payload is
wanted; it reports its effects and refuses to overwrite differing files.

Source: `https://code.claude.com/docs/en/skills` and
`https://code.claude.com/docs/en/plugins`.
