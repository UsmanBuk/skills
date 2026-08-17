---
name: gauntlet
description: Post-hoc verification of code changes — run the full check stack (tests, types, lint, changed-line coverage, real execution; mutation testing for high-stakes changes) against already-written code and produce an evidence report with pasted numbers. Use when the user says "test it", "verify this", "run the gauntlet", "prove it works", or asks whether a change is safe — and invoke it proactively after finishing any substantial coding task (new feature, multi-file change, bug fix touching core logic), even if the user didn't explicitly ask for verification. Skip it for trivial edits (typos, comments, config values) unless asked.
---

# Gauntlet: verify after writing

The working model here is: the code was written freely — by an agent, by the
user, by anyone — and now it has to earn trust. Confidence comes from one
artifact: an **evidence report** showing the change survived a stack of
executable checks, with real numbers from real runs. The reader of that report
should not need to open a source file to know what was verified and what
wasn't.

This only works if the report is honest. A check you didn't run is not a pass.
A number you remember from an earlier run is not a number. A layer that can't
fail is not a layer. Every rule below exists to protect that honesty, because
the report is worthless the first time it overstates.

## The pass

```
SCOPE → BASELINE → CLAIMS → LAYERS → EVIDENCE
```

### 1. SCOPE — what is under test

Identify the change set precisely: `git diff` (staged + unstaged) plus
untracked files, or the commit range the user names. Record the source state —
commit SHA plus a dirty-tree marker, so the report says exactly what was
verified. Everything downstream (changed-line coverage, mutation scope,
capability diff) keys off this set; get it right first.

### 2. BASELINE — what was already broken

Before judging the change, run the test suite once on the current tree and
record any pre-existing failures verbatim. The gauntlet then holds the line at
**zero NEW failures**. Don't fix unrelated pre-existing failures — that's
scope creep; surface them in the report instead. Without a baseline, an old
failure gets blamed on the new change (or worse, a new failure gets excused as
"probably old").

### 3. CLAIMS — what the change says it does

Read the diff and write down, in a few lines, the concrete behaviors the
change claims to deliver — specific inputs and outputs, not "improves
handling". Then map each claim to the test that verifies it. This is the map
the evidence report is built on, and it is where gaps become visible: a claim
with no covering test is a finding, not a footnote. Don't silently write the
missing test and move on — flag it, and add the test only if it's clearly in
scope of what the user asked for.

### 4. LAYERS — the check stack

Run every applicable layer. Prefer the project's own commands (check
package.json / pyproject.toml / Makefile / CI config first); defaults per
ecosystem are in `references/tooling.md`. Scale to the tier (below), but never
skip a layer silently — a skipped layer appears in the report with its reason.

| Layer | What it catches | Pass condition |
|---|---|---|
| Full test suite | regressions | zero NEW failures vs. baseline |
| Static types | whole bug classes | zero new errors |
| Lint + format | latent bugs, drift | zero new warnings |
| Changed-line coverage | untested new code | every changed/added line executed by a test. The check must **exit nonzero when the threshold is missed** (`diff-cover --fail-under`, `--cov-fail-under`, equivalent) — a layer that prints a percentage and exits 0 is a report, not a gate |
| Real execution | "passes tests, doesn't run" | run the actual app/CLI/endpoint once on a realistic input, not only the test harness |
| Suite health | flaky/order-dependent tests | randomized test order; rerun suspected flakes. Every number in the report rests on the suite being deterministic |
| Deps & secrets | vulnerable deps, leaked credentials | only when the dependency set changed: audit it; always: scan the diff for secrets, and eyeball the capability diff — did the change start using network / subprocess / filesystem / env it didn't before? |
| Mutation (high-stakes or on request) | tests that assert nothing | plant realistic bugs in the changed code, one at a time; the suite must kill every one. Prefer a real mutation tool scoped to changed files; manual procedure in `references/tooling.md` |
| Property-based (high-stakes) | edge cases nobody imagined | invariant tests (round-trip, idempotence, bounds) for parsing/math/serialization logic |

Checker honesty: off-the-shelf tools (pytest, tsc, ruff…) have earned their
failure behavior; home-grown checks — grep gates, custom scripts — have not.
For those: **fail closed** (a crash or unreadable input is a layer failure,
never a pass — no `|| true`, no `2>/dev/null`), and **prove the check can
fail** once with a known-bad input before trusting its pass.

### 5. EVIDENCE — the report

Write the report to a file and give its **absolute path**. Structure:

```
# Gauntlet report — <change description>
Source state: <SHA / dirty marker>   Tier: <1|2|3>   Date
## Claims → tests        (each claim, its covering test, or GAP)
## Layers                (per layer: exact command, pasted output numbers, pass/fail)
## Skipped               (layer + reason)
## Honest notes          (pre-existing failures, flakes seen, anything resolved along the way)
## Verdict               (pass / fail / pass-with-gaps, in one sentence)
```

Numbers must come from **one final fresh run after the last code edit** — a
mid-task run is stale the moment another edit lands. "All 47 tests pass,
changed-line coverage 100% (31/31)" is a result; "tests look good" is not.
In conversation, give the verdict and the notable findings in prose — the file
holds the detail.

## Anti-gaming rules (absolute)

1. **Never weaken a test to make it pass** — no broadened assertions, added
   skips, raised tolerances, deleted tests. A test that seems wrong is a
   finding to surface, not an obstacle to remove.
2. **Never report a layer you didn't run.** "Skipped: no mutation tool here"
   preserves trust; an invented result destroys all of it.
3. **Never chase the coverage number.** Coverage detects untested code; a test
   added only to touch lines, asserting nothing, is gaming — and mutation
   testing exists to catch exactly that, including yours.
4. **A failing layer blocks "done".** If genuinely blocked, the verbatim
   failure IS the outcome — report it as such.
5. **Fixing counts, hiding doesn't.** A gauntlet you fixed your way through is
   as good as one you passed first try; record what failed and how it was
   resolved. The only failure is a check quietly weakened.

## Calibration

Say which tier you chose and why:

- **Tier 1 — trivial** (typo, comment, config value): full suite + lint.
  State why the change needs no dedicated test.
- **Tier 2 — normal** (feature, bug fix, refactor): all default layers.
  A bug fix must include a test that reproduces the bug — if none exists,
  that's a claims-map gap to flag.
- **Tier 3 — high stakes** (money, auth, data loss, concurrency, public API,
  migrations): default layers + mutation + property-based tests, and start
  with a short failure model — list the ways this specific change can hurt
  (race, partial write, hostile input, failed rollback…) and add a check that
  can actually catch each one. Finish with an adversarial pass: one explicit
  attempt to break the implementation with hostile inputs. Modes deliberately
  not covered go in the report as known limits.

## Missing tooling

If the project has no test runner, linter, or type checker, propose the
minimal standard toolchain for the language (see `references/tooling.md`)
before running — a gauntlet can't run on bare ground, and installing tools
changes the user's environment, so it needs their OK (prefer project-local
installs: venv, node_modules, container — never system-level). If tooling is declined,
fall back to manual layers and record the reduced confidence honestly.

---

*Gauntlet-layer design adapted from [AmazingAng/old-coder](https://github.com/AmazingAng/old-coder) (MIT), itself inspired by Robert C. Martin's agent-era testing strategy. This skill keeps the verification stack and evidence discipline but drops the spec-approval/TDD loop: code is written first, verified after.*
