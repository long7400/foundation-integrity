# Codex installation

## Choose one surface

### One-command repo setup

Run from the target repository. The default is the lightweight core payload:

```bash
curl -fsSL "https://raw.githubusercontent.com/long7400/foundation-integrity/main/scripts/install.sh?$(date +%s)" \
  | bash -s -- --codex
```

Add `--with-fitness` for measurement templates or `--full-opt` for fitness, hooks,
and inert orchestration. Preview with `--dry-run`; use `--directory <repo>` when not
running inside the target and `--ref <tag-or-commit>` to choose the payload snapshot.
The bootstrap installs the checked 24-skill Codex projection and project policy but
does not mutate global Codex configuration or activate orchestration.

### Plugin install

Use this when you want the versioned bundle and marketplace updates:

```bash
codex plugin marketplace add long7400/foundation-integrity
codex plugin add foundation-integrity@foundation-integrity
```

The plugin manifest is `.codex-plugin/plugin.json`; it exposes the canonical plugin
`skills/` root recursively. Codex installs the plugin into its managed cache and
records enablement in Codex configuration rather than copying the skills into the
target repository.

The Foundation Integrity skills are explicit-only. First invocation:

```text
Use $foundation-audit to audit the foundation before design.
```

### Standalone repo skills

Use this when the repository should own the skills directly. Copy the checked
`.agents/skills/` projection into the target repository at the same path:

```text
<repo>/.agents/skills/<skill-name>/SKILL.md
<repo>/.agents/skills/<skill-name>/agents/openai.yaml
```

Do not use `.claude/skills/` as Codex's repo skill root. The Codex projection contains
the same 24 skill names plus its optional presentation/dependency metadata.

## Bundled versus active state

There is no Foundation Integrity or Matt setup command required for skill discovery.
The distribution contains starter issue/domain/triage conventions under
`docs/agents/` plus shared operating-rule and hook/fitness templates, but installation
does not copy or activate those files in the consumer repository.

The three Foundation Integrity skills work without tracker configuration. Companion
tracker flows expect project-specific `docs/agents/` files and report a gap when they
are absent. For local-checkout adoption, preview and run the same underlying adopter
explicitly:

```bash
sh templates/setup/full-opt.sh --runtime codex --core --dry-run <repo>
sh templates/setup/full-opt.sh --runtime codex --core <repo>
sh templates/setup/full-opt.sh --runtime codex --full-opt <repo>
```

Core installs the 24 managed pack skills in the Codex projection, merges the
instruction and ignore blocks, copies/customizes exactly four `docs/agents/` files,
and copies compact docs/ADR plus setup helpers. Fitness, hooks, and orchestration are
optional components. The warn-only pre-commit hook is wired only when hooks are
selected and conflict-free. Blocking pre-push is an explicit `--with-pre-push`
option; runtime hooks, user profiles, and orchestration remain inactive samples. The
adoption lock at `.foundation-integrity/adoption.tsv` records exact content and file
modes and permits later updates only for unchanged managed files.

Pre-existing identical non-skill files and hooks remain external rather than becoming
silent deletion authority. The target lock serializes cooperating installer runs;
apply-time revalidation narrows concurrent-edit races but does not make shell copying
transactional against arbitrary external writers.

If the repository was first adopted as Claude-only with `CLAUDE.md` as the instruction
owner, adding Codex requires a deliberate migration to `AGENTS.md`. The installer
refuses to create a second owner or automatically delete the old policy block.

Use `--no-pre-commit` to avoid newly wiring the hook. On an upgrade, that flag retains
an unchanged pre-commit already owned by the adoption lock; it is not an uninstall
operation.

## Ignore behavior

The package ships a root `.gitignore` and
`templates/gitignore/foundation-integrity.gitignore`. Codex's plugin manager installs
the bundle into its managed cache; it does not edit the consumer repository's root
`.gitignore` or create `docs/research/` in the consumer repository. A standalone repo
install copies only `.agents/skills/`; it also does not create that directory. Merge
the marked ignore block explicitly so `.foundation/`, `docs/research/`, and `tmp/`
remain local when tools create them later.

The standalone projection is the skill surface, not a hidden full-project installer.
Use `full-opt` when the optional project-owned measurement and orchestration assets
are wanted; it reports its effects and refuses to overwrite differing files.

Source: `https://learn.chatgpt.com/docs/customization/overview#skills` and
`https://developers.openai.com/codex/plugins/build`.
