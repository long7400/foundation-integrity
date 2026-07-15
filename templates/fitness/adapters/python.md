# Adapter — Python (import-linter)

[import-linter](https://github.com/seddonym/import-linter) lets you "impose
constraints on the imports between your Python modules" and enforces them as an
automated check in CI. You declare architectural **contracts** (layers, forbidden
imports, independence) in a config file and the linter fails when the real import
graph violates them.

Enforces tier-1 intents: **dependency direction** (layered contract), **layering**,
and **forbidden imports** between modules that should stay independent.

## Install

```sh
pip install import-linter   # provides the `lint-imports` command
```

## Contracts that encode the intents

`.importlinter` (INI) or `setup.cfg`:

```ini
[importlinter]
root_package = myapp

[importlinter:contract:layers]
name = Layered architecture (dependency direction)
type = layers
layers =
    myapp.web
    myapp.service
    myapp.domain
# Higher layers may import lower ones; a lower layer importing a higher one fails.
# Tier-1 intent: dependency direction + layering.

[importlinter:contract:feature-independence]
name = Features stay independent
type = independence
modules =
    myapp.billing
    myapp.catalog
# Neither feature may import the other's internals.
# Tier-1 intent: no cross-feature reach-in.
```

## Run in CI

```sh
lint-imports        # exits non-zero on any broken contract → fails the build
```

Add the same command to the pre-push hook template so it also runs locally.
