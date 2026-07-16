#!/bin/sh
# Lint the declared shape and runtime/profile binding of a coworker run.
set -eu

contract=${1:-}
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
matrix=${2:-"$script_dir/../role-model-matrix.tsv"}
if [ -z "$contract" ] || [ ! -f "$contract" ] || [ ! -f "$matrix" ]; then
  echo "usage: $0 <run-contract.tsv> [role-model-matrix.tsv]" >&2
  exit 2
fi

sh "$script_dir/check-role-model-matrix.sh" "$matrix" || exit 1

awk -F '\t' '
FNR == NR {
  if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) next
  key = $1 SUBSEP $2
  matrix_role[key] = $3
  matrix_work_class[key] = $4
  matrix_access[key] = $7
  matrix_claim[key] = $8
  next
}

BEGIN {
  header = 0
  roots = 0
  locks = 0
  bad = 0
}

function fail(msg) {
  print "orchestration contract: " msg > "/dev/stderr"
  bad = 1
}

function safe_repo_path(path) {
  return path != "" && path != "." && path !~ /^\// && path !~ /^~\// && \
    path !~ /^\.\// && path !~ /\/$/ && path !~ /\/\// && \
    path !~ /(^|\/)\.(\/|$)/ && path !~ /(^|\/)\.\.(\/|$)/ && \
    path !~ /[*?\[\]]/
}

function role_matches_profile(actor_role, profile_role) {
  return actor_role == profile_role
}

function access_matches_role(runtime, actor_role, access) {
  if (actor_role == "root") return (runtime == "codex" && access == "workspace-write") || (runtime == "claude" && access == "manual")
  if (actor_role == "implementer") return (runtime == "codex" && access == "workspace-write") || (runtime == "claude" && access == "acceptEdits")
  return (runtime == "codex" && access == "read-only") || (runtime == "claude" && access == "dontAsk")
}

/^# foundation-integrity-orchestration:v2$/ {
  header++
  next
}

/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

$1 == "setting" {
  if (NF != 3) fail("setting record must have 3 tab-separated fields at line " FNR)
  if ($2 == "" || $3 == "") fail("setting key and value must be non-empty at line " FNR)
  if (seen_setting[$2]++) fail("duplicate setting " $2 " at line " FNR)
  settings[$2] = $3
  next
}

$1 == "actor" {
  if (NF != 6) {
    fail("actor record must have 6 tab-separated fields at line " FNR)
    next
  }
  id = $2
  role = $3
  scope = $4
  write_scope = $5
  artifact = $6
  if (id == "" || seen_actor[id]++) fail("actor id is empty or duplicated at line " FNR)
  actors[id] = role
  if (role !~ /^(root|peer|implementer)$/) fail("unknown role " role " at line " FNR)
  if (artifact == "" || artifact == "-") fail("every actor needs an artifact path at line " FNR)
  if (!safe_repo_path(artifact)) fail("artifact path must be canonical and repo-relative at line " FNR)
  if (seen_artifact[artifact]++) fail("duplicate artifact path " artifact)
  if (role == "root") {
    roots++
    root_artifact = artifact
    if (scope != "control") fail("root scope must be control")
  } else if (scope == "" || scope == "control") {
    fail("non-root actor needs a bounded non-control task scope at line " FNR)
  }
  if (role == "implementer") {
    if (write_scope == "" || write_scope == "-") fail("implementer needs an explicit write scope at line " FNR)
  } else if (write_scope != "-") {
    fail("only implementer may hold a write scope at line " FNR)
  }
  if (write_scope != "-") {
    if (seen_write[write_scope]++) fail("duplicate exact write scope " write_scope)
    if (write_scope ~ /^path:/) {
      path_scope = substr(write_scope, 6)
      if (!safe_repo_path(path_scope)) {
        fail("path write scope must be canonical, bounded, and repo-relative at line " FNR)
      } else {
        for (existing in path_scopes) {
          if (path_scope == existing || index(path_scope, existing "/") == 1 || index(existing, path_scope "/") == 1) {
            fail("overlapping path write scopes " path_scope " and " existing)
          }
        }
        path_scopes[path_scope] = id
      }
    } else if (write_scope !~ /^worktree:[A-Za-z0-9._-]+$/) {
      fail("write scope must use path:<repo-relative-path> or worktree:<id> at line " FNR)
    }
  }
  next
}

$1 == "profile" {
  if (NF != 3) {
    fail("profile record must have 3 tab-separated fields at line " FNR)
    next
  }
  if ($2 == "" || $3 == "") fail("profile actor and id must be non-empty at line " FNR)
  if (seen_profile[$2]++) fail("duplicate profile binding for actor " $2)
  profiles[$2] = $3
  next
}

$1 == "lock" {
  if (NF != 3 || $2 != "canonical-validation") {
    fail("lock record must be: lock<TAB>canonical-validation<TAB>actor")
    next
  }
  locks++
  lock_owner = $3
  next
}

{ fail("unknown record type at line " FNR ": " $1) }

END {
  if (header != 1) fail("expected exactly one v2 header")
  runtime = settings["runtime"]
  if (runtime !~ /^(codex|claude)$/) fail("runtime must be codex or claude")
  if (settings["role_model_matrix"] != "templates/orchestration/role-model-matrix.tsv") fail("role_model_matrix must name the canonical repo path")
  if (settings["native_subagents"] != "disabled") fail("native_subagents must be disabled for this pilot")
  if (settings["transport_status"] != "attention-only") fail("transport_status must be attention-only")
  if (settings["current_state_source"] != "root-artifact") fail("current_state_source must be root-artifact")
  if (!safe_repo_path(settings["current_state_path"])) fail("current_state_path must be canonical and repo-relative")
  if (roots != 1) fail("expected exactly one root actor")
  if (settings["current_state_path"] != root_artifact) fail("current_state_path must equal the root actor artifact")
  if (settings["session_policy"] != "fresh-only") fail("session_policy must be fresh-only until full envelope resume validation exists")
  if (settings["monitor_authority"] != "root") fail("monitor_authority must remain root")
  if (settings["artifact_provenance"] != "content-digest") fail("artifact_provenance must require content digests")
  if (!safe_repo_path(settings["controller_lock_path"])) fail("controller_lock_path must be canonical and repo-relative")

  for (actor in actors) {
    if (!(actor in profiles)) {
      fail("missing profile binding for actor " actor)
      continue
    }
    profile = profiles[actor]
    key = runtime SUBSEP profile
    if (!(key in matrix_role)) {
      fail("profile " profile " is not approved for runtime " runtime)
      continue
    }
    if (!role_matches_profile(actors[actor], matrix_role[key])) fail("actor " actor " role " actors[actor] " is incompatible with profile role " matrix_role[key])
    if (!access_matches_role(runtime, actors[actor], matrix_access[key])) fail("actor " actor " access does not match its role and runtime")
  }
  for (actor in profiles) if (!(actor in actors)) fail("profile binding names unknown actor " actor)

  for (path_scope in path_scopes) {
    for (artifact_path in seen_artifact) {
      if (artifact_path == path_scope || index(artifact_path, path_scope "/") == 1 || index(path_scope, artifact_path "/") == 1) {
        fail("implementer path scope must not overlap a canonical artifact path: " path_scope " vs " artifact_path)
      }
    }
  }
  if (locks != 1) fail("expected exactly one canonical-validation lock")
  if (lock_owner != "root") fail("validation lock owner must be root")
  exit bad
}
' "$matrix" "$contract"
