# Tier 2 — Git-only fitness signals

Signals computed from `git log` metadata alone. No compiler, no parser, no
language-specific tooling — so they run in **any** repo, including one whose stack
has no architecture-rule tool, or a repo with no code yet (they just find nothing
to flag). This is the tier that works when nobody reads the code: the machine reads
the *history* and tells you where the structure is straining.

These signals are **cumulative and statistical** — a single commit means nothing; a
pattern across dozens means something. So they belong in `foundation-health` (a
periodic, separate-from-feature-work pass), not in a per-edit hook. Treat every
number below as an **investigation trigger**, never proof.

> Why history works: logical / change coupling "exploits the release history of a
> software system to find change patterns among modules" — files that always change
> together are coupled whether or not the code says so. It needs "only commit
> metadata … no parsing, type-checking … needed"
> ([Coupling — logical coupling](https://en.wikipedia.org/wiki/Coupling_(computer_programming))).

## The signals

### 1. Change coupling across module boundaries

Two files in *different* modules that keep changing in the same commit are secretly
one module — a hidden dependency the structure doesn't express. This is the
machine-visible fingerprint of "bent logic / wrapper spanning a seam."

```sh
# File PAIRS that co-changed most often in the last 300 commits. Groups files by
# commit, emits every within-commit pair, counts them. Commits touching >50 files are
# skipped (bulk reformats would swamp the signal).
git log --pretty=format:'@%H' --name-only -n 300 \
  | awk '
      /^@/ { if (n>0 && n<=50) for(i=1;i<n;i++) for(j=i+1;j<=n;j++) print f[i]" :: "f[j];
             n=0; next }
      NF   { f[++n]=$0 }
      END  { if (n>0 && n<=50) for(i=1;i<n;i++) for(j=i+1;j<=n;j++) print f[i]" :: "f[j] }' \
  | sort | uniq -c | sort -rn | head -20
```

The signal that matters: a high-co-change **pair whose two files live in different
top-level modules**. Same-module co-change is normal; cross-boundary co-change is the
smell — two modules that always move together are secretly one. Filter the output to
pairs whose paths start with different module roots.

### 2. Churn hotspots

Files changed, then changed again, and again, in a short window = design not settled.

```sh
# Most-frequently-touched files in the last 90 days.
git log --since="90 days ago" --pretty=format: --name-only \
  | sed '/^$/d' | sort | uniq -c | sort -rn | head -20
```

Migrations, schemas, and core-domain files near the top of this list are the
loudest — those are exactly the places a frozen mistake becomes durable-data debt.

### 3. Blast radius per commit

How many files a typical commit touching a given module drags along. A module whose
commits routinely touch 15+ files across the tree has poor encapsulation.

```sh
# Average files-per-commit trend, last 200 commits.
git log -n 200 --pretty=format:%H --name-only \
  | awk '/^[0-9a-f]{40}$/{if(n)print n; n=0; next} NF{n++} END{if(n)print n}' \
  | awk '{s+=$1; c++} END{if(c)printf "avg files/commit: %.1f over %d commits\n", s/c, c}'
```

### 4. Workaround-marker density

The vocabulary of accreting debt. Rising counts of these in commit subjects or in
the tree are normalized-deviance made countable.

```sh
# Commits whose subject signals a patch-over-patch.
git log --oneline -n 500 | grep -iE 'workaround|hack|temp|fixme|revert|band.?aid' | wc -l
# Same markers sitting in the current tree.
git grep -iE 'TODO|FIXME|HACK|XXX|WORKAROUND' | wc -l
```

## Reading the signals as OOD-drift proxy

You can't measure a model's perplexity on the codebase from inside a normal repo
(that needs logprob/model access most runtimes don't expose). So don't claim to
detect "the agent getting dumber" directly. What you *can* do is **trend** the signals
above over time — rising cross-boundary coupling, rising churn on the same hotspots,
rising workaround-marker density, rising blast radius. That upward trend is the
portable, honest proxy for "the codebase is drifting away from clean, idiomatic
structure" — the same drift that pushes it out-of-distribution for the model. Trend,
not snapshot: one reading is noise; the slope is the signal.

## What NOT to conclude

- A hot file isn't automatically bad — it may just be genuinely central. The trigger
  is hot **and** cross-coupled **and** rising.
- Don't auto-fix from these. They point `foundation-health` at where to *look*; the
  repair goes through `foundation-audit` like any other change.
- Don't install these as blocking CI on their own — a noisy statistical signal that
  blocks merges gets disabled, and a disabled check is worse than none.
