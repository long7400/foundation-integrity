#!/usr/bin/env sh
# foundation-surface-guard.sh
#
# Fires on an OBSERVABLE fact: a foundation-surface file changed with no VALID receipt
# in the change set that NAMES that exact file. Two modes trade off portability vs
# strength — pick per how much you can trust the actors:
#
#   advisory (default, FI_REVIEW_MODE=advisory)
#     A receipt is a text artifact an agent can author. A valid receipt proves a
#     decision was RECORDED and STRUCTURED — not that an independent review happened.
#     This buys visibility + a versioned audit trail; it is not proof. Enough against
#     a completion-biased agent (skipping becomes deliberate and auditable), not
#     against an adversarial one.
#
#   attested (opt-in, FI_REVIEW_MODE=attested)
#     Clearing a surface change additionally requires that the pushed tip is a commit
#     signed by a key on a trusted-reviewer allowlist that lives OUTSIDE the worktree
#     (FI_TRUSTED_REVIEWERS), and that the receipt's `reviewer:` equals the identity
#     mapped from that key. This resists a single agent that can edit files but does
#     not hold the reviewer's signing key. It proves an isolated key was used — NOT
#     that the reviewer thought hard. Authoritative only when a protected CI /
#     branch-protection rule re-runs this check; a local hook stays bypassable.
#     Signature verification needs committed history, so it only engages in range
#     mode (pre-push / CI); in worktree mode it degrades to advisory + a deferral note.
#
# Receipt format: the v2 block in docs/foundation/review-receipt.md. Receipt files are
# matched under **/adr/*.md and docs/foundation/receipts/*.md.
#
# Modes of evaluation:
#   worktree (default) — staged + unstaged + untracked vs HEAD. Pre-commit / mid-session.
#   range   (FI_RANGE=base..head) — the exact commit range. Pre-push / CI.
#
# Exit codes:  0 pass · 1 warn (default) · 2 block (FI_BLOCK=1 or attested)
#
# Env: FI_BLOCK, FI_RANGE, FI_REVIEW_MODE, FI_TRUSTED_REVIEWERS, FI_SURFACE_FILE

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
surface_file=${FI_SURFACE_FILE:-"$here/../foundation-surface.txt"}
[ -f "$surface_file" ] || surface_file="$here/foundation-surface.txt"
mode=${FI_REVIEW_MODE:-advisory}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

fail_closed() {
  message=$1
  printf '%s\n' "foundation-surface-guard: $message" >&2
  if [ "${FI_BLOCK:-0}" = "1" ] || [ "$mode" = attested ]; then
    exit 2
  fi
  exit 1
}

[ -f "$surface_file" ] || fail_closed "surface policy is missing: $surface_file"

range=${FI_RANGE:-}
head_ref=HEAD
base_ref=HEAD
if [ -n "$range" ]; then
  head_ref=${range##*..}
  base_ref=${range%%..*}
  [ -n "$head_ref" ] || head_ref=HEAD
  [ -n "$base_ref" ] || base_ref=HEAD
fi

tmpd=$(mktemp -d 2>/dev/null) || fail_closed "cannot create a temporary workspace; refusing to clear the surface check"
trap 'rm -rf "$tmpd"' EXIT
R_PATHS="$tmpd/paths"
R_EVIDENCE="$tmpd/evidence"

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    fail_closed "no SHA-256 implementation is available for receipt binding"
  fi
}

# --- Read a receipt's content in the active mode. ---
materialize() { # $1 = repo-relative path -> stdout
  if [ -n "$range" ]; then
    git show "$head_ref:$1" 2>/dev/null || true
  else
    { [ -f "$1" ] && cat -- "$1"; } 2>/dev/null || true
  fi
}

# --- Parse + validate a materialized receipt file. ---
# Sets R_REVIEWER and writes covered paths to $R_PATHS. Returns 0 iff the receipt is
# well-formed AND its verdict/classification clear the guard.
parse_receipt() { # $1 = file
  R_REVIEWER=""
  : > "$R_PATHS"
  : > "$R_EVIDENCE"
  cr=$(printf '\r')
  in_block=0; closed=0; bad=0; n_open=0
  c_class=""; c_route=""; c_rev=""; c_verd=""; c_inv=""; c_outcome=""
  c_revision=""; c_digest=""; n_class=0; n_route=0; n_rev=0; n_verd=0; n_inv=0
  n_outcome=0; n_revision=0; n_digest=0; n_evidence=0; n_path=0

  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%"$cr"}                     # tolerate CRLF receipts
    if [ "$in_block" = 0 ]; then
      # The opener must be a real HTML comment opener carrying the marker (after
      # optional leading whitespace) — NOT any line that merely mentions the marker
      # string. Count openers so multiple blocks can be rejected as ambiguous.
      lead=${line%%[![:space:]]*}; t=${line#"$lead"}
      case "$t" in
        "<!--"*foundation-integrity-receipt:v2*) in_block=1; n_open=$((n_open+1)) ;;
      esac
      continue
    fi
    case "$line" in *"-->"*) closed=1; in_block=0; continue ;; esac
    # strip leading whitespace (spaces + tabs), portably. A leading space *in a
    # filename* is therefore not nameable — rename the file (see review-receipt.md).
    lead=${line%%[![:space:]]*}; s=${line#"$lead"}
    case "$s" in *:*) : ;; *) continue ;; esac
    k=${s%%:*}
    v=${s#*:}; lead=${v%%[![:space:]]*}; v=${v#"$lead"}
    case "$k" in
      classification)       c_class=$v; n_class=$((n_class+1)) ;;
      route)                c_route=$v; n_route=$((n_route+1)) ;;
      reviewer)             c_rev=$v;   n_rev=$((n_rev+1)) ;;
      verdict)              c_verd=$v;  n_verd=$((n_verd+1)) ;;
      canonical-invariant)  c_inv=$v;   n_inv=$((n_inv+1)) ;;
      outcome)              c_outcome=$v; n_outcome=$((n_outcome+1)) ;;
      revision)             c_revision=$v; n_revision=$((n_revision+1)) ;;
      change-digest)        c_digest=$v; n_digest=$((n_digest+1)) ;;
      evidence-ref)
        case "$v" in
          commit:*|run:*|url:*) n_evidence=$((n_evidence+1)) ;;
          path:*)
            evidence_path=${v#path:}
            case "$evidence_path" in
              ""|/*|*..*|*//*|./*) bad=1 ;;
              *) printf '%s\n' "$evidence_path" >> "$R_EVIDENCE"; n_evidence=$((n_evidence+1)) ;;
            esac ;;
          *) bad=1 ;;
        esac ;;
      surface-path)
        case "$v" in
          ""|/*|*..*) bad=1 ;;
          *) printf '%s\n' "$v" >> "$R_PATHS"; n_path=$((n_path+1)) ;;
        esac ;;
    esac
  done < "$1"

  [ "$n_open" = 1 ] || return 1          # exactly one block; zero or multiple = reject
  [ "$closed" = 1 ] || return 1
  [ "$bad" = 0 ] || return 1
  [ "$n_class" = 1 ] && [ "$n_route" = 1 ] && [ "$n_rev" = 1 ] \
    && [ "$n_verd" = 1 ] && [ "$n_inv" = 1 ] && [ "$n_outcome" = 1 ] \
    && [ "$n_revision" = 1 ] && [ "$n_digest" = 1 ] || return 1
  [ "$n_path" -ge 1 ] && [ "$n_evidence" -ge 1 ] || return 1
  [ -n "$c_inv" ] && [ -n "$c_rev" ] && [ -n "$c_outcome" ] || return 1
  case "$c_class" in FOUNDATION_OK|FOUNDATION_SUSPECT|FOUNDATION_BLOCKED) ;; *) return 1 ;; esac
  case "$c_route" in Feature-first|Bounded-compatibility|Foundation-first) ;; *) return 1 ;; esac
  case "$c_verd" in upholds|amends|overturns) ;; *) return 1 ;; esac
  case "$c_outcome" in PROCEED|RESEARCH_ONLY|NO_GO) ;; *) return 1 ;; esac
  [ "$c_revision" = "$expected_revision" ] || return 1
  case "$c_digest" in
    ''|*[!0-9A-Fa-f]*) return 1 ;;
  esac
  [ "${#c_digest}" = 64 ] || return 1
  [ "$c_digest" = "$expected_change_digest" ] || return 1
  while IFS= read -r evidence_path; do
    [ -n "$evidence_path" ] || continue
    if [ -n "$range" ]; then
      git cat-file -e "$head_ref:$evidence_path" 2>/dev/null || return 1
    else
      [ -f "$evidence_path" ] || return 1
    fi
  done < "$R_EVIDENCE"
  # Clearing rules: only upholds/amends + PROCEED clear; BLOCKED/SUSPECT/RESEARCH_ONLY/NO_GO never.
  case "$c_verd" in upholds|amends) ;; *) return 1 ;; esac
  [ "$c_outcome" = PROCEED ] || return 1
  [ "$c_class" = FOUNDATION_BLOCKED ] && return 1
  { [ "$c_class" = FOUNDATION_SUSPECT ] && [ "$c_route" = Feature-first ]; } && return 1
  R_REVIEWER=$c_rev
  return 0
}

# --- Surface hits + candidate receipt files in the active mode. ---
set --
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  set -- "$@" ":(glob)$line"
done < "$surface_file"
[ "$#" -gt 0 ] || exit 0

if [ -n "$range" ]; then
  git diff --no-renames --name-only "$range" -- "$@" 2>/dev/null | sort -u > "$tmpd/hits"
  git diff --no-renames --name-only "$range" 2>/dev/null | sort -u > "$tmpd/all"
else
  { git diff --name-only HEAD -- "$@" 2>/dev/null || true
    git diff --name-only --cached -- "$@" 2>/dev/null || true
    git ls-files --others --exclude-standard -- "$@" 2>/dev/null || true
  } | sort -u > "$tmpd/hits"
  { git diff --name-only HEAD 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
    # Numbered ADRs are intentionally ignored for personal projects, but a local
    # advisory check may still use one as the decision artifact.
    if [ -d docs/adr ]; then find docs/adr -type f -name '*.md' -print; fi
  } | sort -u > "$tmpd/all"
fi
[ -s "$tmpd/hits" ] || exit 0
grep -iE '((^|/)adr/.*\.md$)|(docs/foundation/receipts/.*\.md$)' "$tmpd/all" > "$tmpd/receipts" 2>/dev/null || true

# Bind each receipt to the exact revision and changed-content manifest. Receipt/ADR
# files are excluded from the manifest to avoid a self-referential digest; their
# evidence refs still have to be explicit and machine-parseable.
 # In range mode the receipt itself is part of the pushed tip, so binding it to the
 # tip hash would be self-referential. Bind revision to the exact left boundary and
 # bind all changed content to the digest below; worktree mode binds HEAD directly.
expected_revision=$(git rev-parse "$base_ref" 2>/dev/null || true)
[ -n "$expected_revision" ] || fail_closed "cannot resolve the checked revision"
{
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      */adr/*.md|docs/foundation/receipts/*.md) continue ;;
    esac
    if [ -n "$range" ]; then
      oid=$(git rev-parse "$head_ref:$f" 2>/dev/null || printf '%s' DELETED)
    elif [ -e "$f" ]; then
      oid=$(git hash-object -- "$f" 2>/dev/null || printf '%s' UNREADABLE)
    else
      oid=DELETED
    fi
    printf '%s\t%s\n' "$f" "$oid"
  done < "$tmpd/all"
} | sort | tee "$tmpd/change-manifest" >/dev/null
expected_change_digest=$(cat "$tmpd/change-manifest" | sha256_stream)
[ -n "$expected_change_digest" ] || fail_closed "cannot compute the changed-content digest"

# --- Attested mode: resolve the trusted signer of the pushed tip (range mode only). ---
attested_active=0
signer=""
note=""
if [ "$mode" = attested ]; then
  if [ -z "$range" ]; then
    note="attested mode: signature check deferred to push/CI (worktree has no signed tip); using advisory rules here."
  else
    attested_active=1
    if git verify-commit "$head_ref" >/dev/null 2>&1; then
      fp=$(git show -s --format=%GF "$head_ref" 2>/dev/null || true)
      if [ -n "$fp" ] && [ -n "${FI_TRUSTED_REVIEWERS:-}" ] && [ -f "${FI_TRUSTED_REVIEWERS:-/nonexistent}" ]; then
        signer=$(awk -F '\t' -v fp="$fp" \
          'toupper($1)==toupper(fp){print $2; exit}' "$FI_TRUSTED_REVIEWERS" 2>/dev/null || true)
      fi
    fi
    [ -n "$signer" ] || note="attested mode: pushed tip is not signed by a trusted reviewer (FI_TRUSTED_REVIEWERS) — nothing can clear; fail-closed."
  fi
fi

# --- Coverage: each surface hit needs a valid receipt naming its exact path. ---
: > "$tmpd/uncovered"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  covered=0
  if [ -s "$tmpd/receipts" ]; then
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      materialize "$r" > "$tmpd/rcpt"
      parse_receipt "$tmpd/rcpt" || continue
      pm=0
      while IFS= read -r p; do [ "$p" = "$f" ] && { pm=1; break; }; done < "$R_PATHS"
      [ "$pm" = 1 ] || continue
      if [ "$attested_active" = 1 ]; then
        [ -n "$signer" ] || continue
        [ "$R_REVIEWER" = "$signer" ] || continue
      fi
      covered=1; break
    done < "$tmpd/receipts"
  fi
  [ "$covered" = 1 ] || printf '%s\n' "$f" >> "$tmpd/uncovered"
done < "$tmpd/hits"

[ -s "$tmpd/uncovered" ] || { [ -n "$note" ] && printf '%s\n' "$note" >&2; exit 0; }

printf '%s\n' "foundation-surface change without a valid decision naming it (mode: $mode):" >&2
sed 's/^/    /' "$tmpd/uncovered" >&2
[ -n "$note" ] && printf '\n%s\n' "$note" >&2
cat >&2 <<'EOF'

Each surface file above changed but no valid ADR/receipt in this change set names it.
  1. Run foundation-audit on the claim the change load-bears on.
  2. If a foundation surface is touched, run adversarial-foundation-review in a
     SEPARATE session (ideally a different model). Record its verdict.
  3. Write a v2 receipt (docs/foundation/receipts/) or ADR naming the exact paths above.
     See docs/foundation/review-receipt.md.
In attested mode the receipt's reviewer must match a signed, trusted attestation.
This makes skipping the review a visible, auditable act; advisory mode is not proof
a review ran. Set FI_BLOCK=1 for a hard stop.
EOF

[ "${FI_BLOCK:-0}" = "1" ] && exit 2
exit 1
