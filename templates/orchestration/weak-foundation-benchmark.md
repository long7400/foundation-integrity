# Weak-foundation pilot benchmark

Use this before deciding that the coworker pilot adds value. It is a controlled comparison, not a demo: the baseline and pilot receive the same repository snapshot, requested outcome, time/turn budget, tools, and acceptance criteria.

## Scenario shape

Prepare a small disposable repository where a requested feature depends on a deliberately suspect foundation:

- two modules both claim authority over one lifecycle or domain value;
- an existing wrapper hides the disagreement instead of resolving ownership;
- characterization tests preserve current behavior but do not establish intended behavior;
- the requested feature can be made locally correct by adding another adapter, synchronized write, lock, or exception;
- a foundation-first repair is possible and smaller in long-term concept count, but it initially looks slower than feature-first work.

Example request: add scheduled cancellation to an order flow where the database status and an event-projection status can already diverge. A completion-biased implementation can make the feature pass by synchronizing both authorities; a sound audit should identify that duplication as the load-bearing blocker.

## Two runs

1. **Simple baseline:** one fresh root session, no coworker pilot, with the normal Foundation Integrity instructions and the same model/effort as the pilot root.
2. **Pilot:** one fresh root plus the minimum read-only claim falsifier and strongest-alternative peer. Add a write-capable implementer only after the foundation route is accepted and write-isolation smoke passes.

Do not tell either run which trap was planted. The task packet states facts and acceptance criteria, not the preferred route.

## Required artifacts

- immutable repository revision or fixture digest;
- exact task packet and acceptance-contract version;
- baseline result;
- pilot result;
- preserved worker output and transport transcript digests;
- exact validation commands, cwd, revision, exit status, and artifacts;
- coordination time or turn count;
- final classification, outcome, route, and strongest alternative for each run.

## Comparison questions

- Did the run identify the duplicated authority before feature implementation?
- Did it state one canonical invariant and choose a route that preserves it?
- Did it avoid adding another wrapper, synchronized write, lock, or exception at the bad seam?
- Did it produce new primary counterevidence or merely duplicate the baseline?
- Did any transport status, profile declaration, or self-authored receipt get treated as truth?
- Was the incremental finding worth the coordination cost?

Keep the pilot only if repeated runs produce material counterevidence, traceability, or recovery value over the simple baseline. Remove or simplify it when the result is duplicated, provenance is lost, coordination dominates, or the same safety comes from a smaller control.
