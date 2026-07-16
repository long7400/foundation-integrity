# Adapter — Go (go-arch-lint)

`go-arch-lint` enforces architectural boundaries in Go by validating actual import
dependencies against rules declared in `.go-arch-lint.yml`. You map packages to
named components and state which components may depend on which. A violation exits
non-zero, so the same rule can run locally and in CI.

Enforces tier-1 intents: **dependency direction**, **layering / component
boundaries**.

## Install

```sh
go install github.com/fe3dback/go-arch-lint@latest
```

## Rules that encode the intents

`.go-arch-lint.yml`:

```yaml
version: 3
workdir: .

components:
  handler:    { in: internal/handler/** }
  service:    { in: internal/service/** }
  repository: { in: internal/repository/** }
  domain:     { in: internal/domain/** }

deps:
  handler:
    mayDependOn: [service, domain]
  service:
    mayDependOn: [repository, domain]
  repository:
    mayDependOn: [domain]
  domain:
    mayDependOn: []      # domain depends on nothing — dependency direction bottoms out here.

# A handler importing repository directly, or domain importing anything, fails.
```

## Run in CI

```sh
go-arch-lint check      # exit 0 = clean, exit 1 = violation → fails the build
```

Add the same command to the pre-push hook template so it also runs locally.
