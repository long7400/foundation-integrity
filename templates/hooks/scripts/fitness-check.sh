#!/usr/bin/env sh
# fitness-check.sh
#
# The machine-measured half of the gate. It doesn't judge whether the design is sound
# — it proves no *structural* rule was broken, with no agent good-faith required.
#
# Runs two things:
#   Tier 2 (delta) — cheap, git-only, always runs: were new workaround markers
#                    (HACK/FIXME/XXX/WORKAROUND) added in this change? A rising count
#                    is the per-change slice of normalized-deviance. Cumulative trend
#                    analysis lives in foundation-health, not here.
#   Tier 3 (adapter) — the wired per-stack architecture tool, detected by its config
#                    file. Fast tools run always; ArchUnit (a test-suite rule) runs
#                    only in full mode (pre-push / CI), and is NOT reported as "ran"
#                    when skipped — no false green.
#
# Runtime-neutral: git hook, Claude hook, or Codex hook all call this.
#
# Exit codes:  0 pass · 1 warn (default) · 2 block (FI_BLOCK=1)
#
# Env:
#   FI_BLOCK=1   turn a violation into a hard block (use on pre-push / CI)
#   FI_FULL=1    run slow checks too (ArchUnit test suite). Set on pre-push / CI.
#   FI_RANGE=A..B  make the tier-2 delta read this commit range instead of the
#                  working tree (pre-push: the worktree is clean, so the pushed
#                  commits are the only place added markers are visible).
#   FI_DELTA_ONLY=1    run only the tier-2 delta (pre-push calls this per pushed ref).
#   FI_ADAPTERS_ONLY=1 run only the tier-3 adapters (pre-push calls this once, after
#                      the per-ref loop, since adapters read the working tree not ranges).

set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root"

status=0
ran=""
warn=""
do_delta=1; do_adapters=1
[ "${FI_ADAPTERS_ONLY:-0}" = "1" ] && do_delta=0
[ "${FI_DELTA_ONLY:-0}" = "1" ] && do_adapters=0

# --- Tier 2 (delta): new workaround markers on added lines in this change. ---
# Cheap and always safe to run. Reads FI_RANGE if set, else the working-tree diff.
if [ "$do_delta" = 1 ]; then
  if [ -n "${FI_RANGE:-}" ]; then
    delta_diff=$(git diff -U0 "$FI_RANGE" 2>/dev/null || true)
  else
    delta_diff=$(
      { git diff --cached -U0 2>/dev/null || true
        git diff -U0 HEAD 2>/dev/null || true
      }
    )
  fi
  added_markers=$(
    printf '%s\n' "$delta_diff" | grep -E '^\+' | grep -vE '^\+\+\+' \
      | grep -icE 'HACK|FIXME|XXX|WORKAROUND|BANDAID|BAND-AID' || true
  )
  ran="$ran tier2-delta"
  if [ "${added_markers:-0}" -gt 0 ]; then
    warn="$warn
  tier2: $added_markers new workaround marker(s) added${FI_RANGE:+ in $FI_RANGE}."
  fi
fi

# --- Tier 3: per-stack architecture adapter, detected by its config file. ---
if [ "$do_adapters" = 1 ]; then

if [ -f .dependency-cruiser.js ] || [ -f .dependency-cruiser.json ] || [ -f .dependency-cruiser.cjs ]; then
  ran="$ran dependency-cruiser"
  npx --no-install depcruise src >/dev/null 2>&1 || npx --no-install depcruise src || status=1
fi

if [ -f .go-arch-lint.yml ] || [ -f .go-arch-lint.yaml ]; then
  ran="$ran go-arch-lint"
  go-arch-lint check || status=1
fi

if [ -f .importlinter ] || grep -qs 'importlinter' setup.cfg pyproject.toml 2>/dev/null; then
  ran="$ran import-linter"
  lint-imports || status=1
fi

# ArchUnit rules live in the JVM test suite. Running them means running (a slice of)
# the tests — too slow for an edit hook, right for pre-push / CI. In full mode we
# actually run them; otherwise we skip and say so honestly (never a silent green).
if grep -qs 'archunit' pom.xml build.gradle build.gradle.kts 2>/dev/null; then
  if [ "${FI_FULL:-0}" = "1" ]; then
    ran="$ran archunit"
    if [ -f pom.xml ]; then
      mvn -q -Dtest='*Arch*,*Architecture*' test || status=1
    elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
      ./gradlew test --tests '*Arch*' --tests '*Architecture*' || status=1
    fi
  else
    warn="$warn
  archunit: rules present but deferred to full mode (FI_FULL=1 / CI) — not checked here."
  fi
fi

fi  # do_adapters

if [ "$status" -ne 0 ]; then
  printf '%s\n' "fitness-check: a structural rule was violated (ran:$ran)." >&2
  printf '%s\n' "A dependency-direction, cycle, or layering rule broke — the mechanical" >&2
  printf '%s\n' "fingerprint of a wrapper/bent-logic patch. Fix the structure; don't wrap it." >&2
  [ -n "$warn" ] && printf '%s\n' "$warn" >&2
  [ "${FI_BLOCK:-0}" = "1" ] && exit 2
  exit 1
fi

# No hard violation. Surface soft warnings (markers, deferred archunit) without failing.
if [ -n "$warn" ]; then
  printf '%s\n' "fitness-check: passed with notes (ran:$ran):" >&2
  printf '%s\n' "$warn" >&2
fi

exit 0
