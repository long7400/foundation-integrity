# Codex installation

## Choose one surface

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
are absent. For full repository adoption, copy/customize `docs/agents/` and
`templates/`, merge `templates/claude-md-block.md` into the canonical instruction
owner, and wire only the hooks/fitness adapters the project chooses.

## Ignore behavior

The package ships a root `.gitignore` and
`templates/gitignore/foundation-integrity.gitignore`. Codex's plugin manager installs
the bundle into its managed cache; it does not edit the consumer repository's root
`.gitignore` or create `docs/research/` in the consumer repository. A standalone repo
install copies only `.agents/skills/`; it also does not create that directory. Merge
the marked ignore block explicitly so `.foundation/`, `docs/research/`, and `tmp/`
remain local when tools create them later.

The standalone projection is the skill surface, not a hidden full-project installer.
Template references use distribution/repository-root paths; copy `templates/` into
the target root if those optional measurement and setup surfaces are wanted.

Source: `https://learn.chatgpt.com/docs/customization/overview#skills` and
`https://developers.openai.com/codex/plugins/build`.
