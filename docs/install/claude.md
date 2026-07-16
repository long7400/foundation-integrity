# Claude Code installation

## Choose one surface

### One-command repo setup

Run from the target repository. The default is the lightweight core payload:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --claude
```

Add `--with-fitness` for measurement templates or `--full-opt` for fitness, hooks,
and inert orchestration. Preview with `--dry-run`; use `--directory <repo>` when not
running inside the target and `--ref <tag-or-commit>` to choose the payload snapshot.
The bootstrap installs the checked 24-skill Claude projection and project policy but
does not mutate global Claude settings or activate orchestration.

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

No Foundation Integrity or Matt setup command is required for skill discovery. The
distribution contains starter issue/domain/triage conventions under `docs/agents/`
plus operating-rule and hook/fitness templates, but installation does not copy or
activate those files in the consumer repository.

The three Foundation Integrity skills work without tracker configuration. Companion
tracker flows expect project-specific `docs/agents/` files and report a gap when they
are absent. For local-checkout adoption, preview and run the same underlying adopter
explicitly:

```bash
sh templates/setup/full-opt.sh --runtime claude --core --dry-run <repo>
sh templates/setup/full-opt.sh --runtime claude --core <repo>
sh templates/setup/full-opt.sh --runtime claude --full-opt <repo>
```

Core installs the 24 managed pack skills in the Claude projection, merges the
instruction and ignore blocks, copies/customizes exactly four `docs/agents/` files,
and copies compact docs/ADR plus setup helpers. Fitness, hooks, and orchestration are
optional components. The warn-only pre-commit hook is wired only when hooks are
selected and conflict-free. Blocking pre-push is an explicit `--with-pre-push`
option; runtime hooks, user launch envelopes, and orchestration remain inactive
samples. The adoption lock at `.foundation-integrity/adoption.tsv` records exact
content and file modes and permits later updates only for unchanged managed files.

Pre-existing identical non-skill files and hooks remain external rather than becoming
silent deletion authority. The target lock serializes cooperating installer runs;
apply-time revalidation narrows concurrent-edit races but does not make shell copying
transactional against arbitrary external writers.

A fresh Claude-only adoption normally chooses `CLAUDE.md`. If Codex is added later,
its required owner is `AGENTS.md`; migrate that policy deliberately. The installer
refuses to create a second owner or automatically delete the old managed block.

Use `--no-pre-commit` to avoid newly wiring the hook. On an upgrade, that flag retains
an unchanged pre-commit already owned by the adoption lock; it is not an uninstall
operation.

## Ignore behavior

The package ships a root `.gitignore` and
`templates/gitignore/foundation-integrity.gitignore`. Claude's plugin manager installs
the bundle into its managed location; it does not edit the consumer repository's root
`.gitignore` or create `docs/research/` in the consumer repository. A standalone
project install copies only `.claude/skills/`; it also does not create that directory.
Merge the marked ignore block explicitly so `.foundation/`, `docs/research/`, and
`tmp/` remain local when tools create them later.

The standalone projection is the skill surface, not a hidden full-project installer.
Use `full-opt` when the optional project-owned measurement and orchestration assets
are wanted; it reports its effects and refuses to overwrite differing files.

Source: `https://code.claude.com/docs/en/skills` and
`https://code.claude.com/docs/en/plugins`.
