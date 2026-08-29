Implement the approved plan below in this repository. Work only inside the repo and leave everything uncommitted: do not commit, stage, push, or touch any tracker.

Rules:
- Follow the plan exactly. If while implementing you find the plan is wrong (a file does not exist, the root cause is different, the change breaks something the plan did not foresee), STOP — do not improvise a different fix. Report what you found; the plan will be revised.
- Smallest surgical diff: touch only what the plan names. Match the surrounding style. No refactors, no reformatting of untouched code, no new comments except one-line "why" notes for non-obvious constraints.
- Add the regression test from the plan, following the nearest existing test's patterns and fixtures. Run it: it must pass with your change in place.
- Run the project's own test, type, and lint commands for the touched areas and fix what your change broke. Never weaken, skip, or delete an existing test to get green.
- If a check fails twice for reasons you do not understand, stop and report rather than thrashing.

Final message — return exactly this structure:
## Changed files
Each file and what changed, one line each.
## Deviations from the plan
None, or what and why.
## Commands run
Each command and its result — paste the tail of the real output, do not summarize it.
## Open concerns
Anything you are not sure about.
