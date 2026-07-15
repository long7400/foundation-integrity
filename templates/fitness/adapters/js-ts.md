# Adapter — JS / TS (dependency-cruiser)

[dependency-cruiser](https://github.com/sverweij/dependency-cruiser) validates a
JavaScript/TypeScript codebase against **your own** dependency rules and reports
violations. It handles `.js/.ts/.jsx/.tsx/.vue/.svelte`, detects circular
dependencies and orphaned modules, and runs from the CLI so it drops straight into
CI. (dependency-cruiser cruises itself in its own build.)

Enforces tier-1 intents: **dependency direction**, **no cycles**, **layering**.

## Install

```sh
npm i -D dependency-cruiser
npx depcruise --init   # scaffolds .dependency-cruiser.js
```

## Rules that encode the intents

`.dependency-cruiser.js`:

```js
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Tier-1 intent: no new cycles.',
      from: {},
      to: { circular: true },
    },
    {
      name: 'domain-not-import-adapters',
      severity: 'error',
      comment: 'Tier-1 intent: dependency direction — domain must not import adapters.',
      from: { path: '^src/domain' },
      to: { path: '^src/(adapters|infra|web)' },
    },
    {
      name: 'no-orphans',
      severity: 'warn',
      comment: 'Dead modules are a low-grade smell.',
      from: { orphan: true, pathNot: '\\.d\\.ts$' },
      to: {},
    },
  ],
  options: { doNotFollow: { path: 'node_modules' }, tsConfig: { fileName: 'tsconfig.json' } },
};
```

Adjust the `path` globs to your actual layer layout. The point is to make
"dependency direction holds" a rule the build checks, not a convention people
remember.

## Run in CI

```sh
npx depcruise src --config .dependency-cruiser.js
# exits non-zero on any 'error'-severity violation → fails the build
```

Add the same command to the pre-push hook template (`templates/hooks/`) so it also
fires locally before code leaves the machine.
