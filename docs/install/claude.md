# Claude Code installation

## Choose one surface

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
are absent. For full repository adoption, copy/customize `docs/agents/` and
`templates/`, merge `templates/claude-md-block.md` into the canonical instruction
owner, and wire only the hooks/fitness adapters the project chooses.

## Ignore behavior

The package ships a root `.gitignore` and
`templates/gitignore/foundation-integrity.gitignore`. Claude's plugin manager installs
the bundle into its managed location; it does not edit the consumer repository's root
`.gitignore` or create `docs/research/` in the consumer repository. A standalone
project install copies only `.claude/skills/`; it also does not create that directory.
Merge the marked ignore block explicitly so `.foundation/`, `docs/research/`, and
`tmp/` remain local when tools create them later.

The standalone projection is the skill surface, not a hidden full-project installer.
Template references use distribution/repository-root paths; copy `templates/` into
the target root if those optional measurement and setup surfaces are wanted.

Source: `https://code.claude.com/docs/en/skills` and
`https://code.claude.com/docs/en/plugins`.
