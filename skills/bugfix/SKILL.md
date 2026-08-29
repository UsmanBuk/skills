---
name: bugfix
description: Ticket-to-verified-fix pipeline for one bug. Pulls the ticket (Jira, Asana, GitHub issue, or a pasted report) with every comment and attachment, gathers code context and reproduces the bug, has Codex write the plan, has Claude Fable 5 and Kimi K3 independently attack that plan, has Codex implement, runs simplify, runs a three-model review (fresh Codex + Fable 5 + Kimi K3), applies only findings verified against the code, then proves the fix with a before/after reproduction, a regression test shown to fail on the pre-fix code, and the full gauntlet. Use whenever the user says "fix this ticket", "work DATA-1234 / ID-5678 / #42", "bugfix", "run the bugfix pipeline", pastes a bug report and wants it fixed end to end, or asks for Codex/Kimi/Claude to plan, implement, or review a bug fix together — even if they name only one of the models. Not for feature work, not for reviewing an existing diff on its own, and not for a quick one-pass fix the user wants done by hand.
---

# bugfix: one ticket → one verified fix

A bug fix goes wrong in three predictable places: the diagnosis is a plausible story
rather than a proven cause; the fix solves a neighbouring problem instead of the reported
one; and "verified" means the suite went green rather than the bug went away. This
pipeline puts an independent model at each of those points and refuses to move on until
the artifact for the phase exists.

**Roles.** You (the orchestrating agent) gather context, reproduce, compose the briefs,
reconcile disagreements, triage findings, and verify. **Codex** plans and implements.
**Claude Fable 5** and **Kimi K3** — run as separate headless processes, *not* you —
critique the plan and review the diff. Every lane runs in a fresh session with nothing
but its brief: independence is the point. You have spent an hour with the theory by the
time review happens, which makes you the least independent reviewer available — so never
substitute your own read for a lane that failed; fix the lane or say it didn't run.

## Setup

```bash
SKILL_DIR=<directory containing this SKILL.md>          # has scripts/, prompts/, references/
REPO=<absolute path of the git repo being fixed>
WORK=<dir outside the repo>/bugfix/<ticket-slug>        # the harness scratchpad if it offers one, else /tmp
mkdir -p "$WORK/repro"
"$SKILL_DIR/scripts/lane.sh" --check "$REPO"             # probes codex / fable / kimi with a one-word prompt
```

Two helpers do all model calls — read `references/lanes.md` for what they encode:

- `scripts/lane.sh <codex|fable|kimi> <prompt> <out> <repo> [--readonly]` — one headless
  call; writes `<out>`, `<out>.err`, `<out>.rc`. Exit 0 only when there is real output
  from the expected model. `--readonly` fingerprints the tree before and after and fails
  (rc 3) if the lane wrote anything — use it on every lane that isn't implementing.
- `scripts/compose.sh <template> <out> NAME=file …` — template + labelled sections, in
  files, so a big diff never meets shell quoting or argv limits.

Fable and Kimi lanes are meant to run **in parallel**: issue both Bash calls in one
message with `run_in_background: true`, then wait for the completion notifications.

## The contract

- **One ticket per run.** Scope drift is how a bug fix becomes a refactor.
- **Working tree is clean before you start**, or the user has named the pre-existing
  changes to ignore. Otherwise a review lane cannot tell the fix from the noise. If the
  user wants their checkout untouched, do the run in `git worktree add` on a fresh branch.
- **Every phase leaves a file in `$WORK`** (listed per phase). A phase with no artifact
  did not happen. Resuming a run means continuing from the last artifact.
- **Nothing outward without an explicit go**: no commit, push, PR, ticket comment, board
  move, or production write. The run ends with an uncommitted, verified diff and a report;
  offer the next steps, don't take them. Production data is read-only, and only when the
  bug needs it — say so before connecting.
- **Two strikes.** A phase that fails twice (can't reproduce, tests won't pass, Codex
  stops twice, panel still objects after one apply round) ends the run with a report of
  what was tried. Stopping honestly is a successful outcome; thrashing is not.
- **Lane failure is loud.** A lane with rc ≠ 0 is reported as "did not run", never
  quietly replaced by your own opinion. The one substitution allowed: if Codex is
  unavailable (usage limit, auth), stop and ask whether to wait or to have you implement
  with Fable 5 and Kimi still consulting and reviewing.
- **Keep raw lane output out of the conversation.** Read the files, extract, summarise.

## Phases

| # | Phase | Who | Artifact |
|---|---|---|---|
| 1 | Intake | you | `ticket.md` |
| 2 | Context & reproduce | you | `context.md`, `repro/before-*` |
| 3 | Plan | Codex | `plan.md` |
| 4 | Consult | Fable 5 ∥ Kimi K3 → you reconcile | `consult-fable.md`, `consult-kimi.md`, `plan-final.md` |
| 5 | Implement | Codex | `implement.md`, `diff-1.patch` |
| 6 | Simplify | `simplify` skill | `diff-2.patch` |
| 7 | Review | Codex (fresh) ∥ Fable 5 ∥ Kimi K3 | `review-*.md` |
| 8 | Triage & apply | you verify → Codex applies | `triage.md`, `confirmed.md`, `apply.md`, `diff-3.patch` |
| 9 | Verify | you + `gauntlet` skill | `repro/after-*`, `test-proof.md`, evidence report |
| 10 | Report | you | `report.md` |

### 1. Intake → `ticket.md`

Pull the **complete** ticket before forming any theory: title, description, custom
fields, every comment (follow pagination — the last comment often changes the ask),
linked tickets, attachments. Per-tracker mechanics are in `references/trackers.md`.
Look at screenshots (the Read tool renders images). If an attachment carries context you
cannot open — a restricted spreadsheet, a private doc — stop and ask the user for it
rather than working around it; attached context is part of the ask.

Write `ticket.md`: the verbatim ticket and decisive comments, then your own restatement —
expected vs actual, the reporter's exact scenario, and every assumption you are making
about what "fixed" means. Then decide honestly whether this is a well-scoped code bug.
Stop with a clear report (the specific questions that would unblock it) if the ask is
ambiguous or contradictory, needs a product decision, needs credentials you don't have,
or depends on someone else's unmerged work.

### 2. Context & reproduce → `context.md`, `repro/`

Read the code before anyone plans. Use an Explore agent for the sweep if available.
`context.md` holds: the project's own test/type/lint commands (from package.json,
pyproject, Makefile, CI); affected files with line refs; the execution path from the
reporter's action to the wrong outcome; blast radius (callers, shared components, data
already written by the buggy path); existing tests covering the area; and your root-cause
hypothesis with the evidence for it. Note adjacent problems you spot as *secondary
findings* — they go in the report, not in the fix.

Then **reproduce**. Never fix what you haven't seen broken: a failing test, a script, a
curl, a browser run — whatever demonstrates the reported behaviour. The reproduction must
demonstrably fail on the current code. Save the steps and the failing evidence (output,
screenshot) to `repro/before-*`. Two honest attempts without a reproduction → stop and
report what you tried; a bug fixed blind is how regressions ship.

### 3. Plan → `plan.md` (Codex, read-only)

```bash
"$SKILL_DIR/scripts/compose.sh" "$SKILL_DIR/prompts/plan-codex.md" "$WORK/prompt-plan.txt" \
  TICKET="$WORK/ticket.md" CONTEXT="$WORK/context.md"
"$SKILL_DIR/scripts/lane.sh" codex "$WORK/prompt-plan.txt" "$WORK/plan.md" "$REPO" --readonly
```

Codex is told to verify the root cause itself rather than trust `context.md`. Read the
plan. If it disagrees with your hypothesis, that is information, not an error — go back
to the code and settle it with evidence before consulting. If the plan says the ticket
can't honestly be fixed as described, take that seriously: it usually means Phase 1
missed something.

### 4. Consult → `consult-*.md`, `plan-final.md` (Fable 5 ∥ Kimi K3)

```bash
"$SKILL_DIR/scripts/compose.sh" "$SKILL_DIR/prompts/consult.md" "$WORK/prompt-consult.txt" \
  TICKET="$WORK/ticket.md" CONTEXT="$WORK/context.md" PLAN="$WORK/plan.md"
# two Bash calls, one message, both run_in_background:
"$SKILL_DIR/scripts/lane.sh" fable "$WORK/prompt-consult.txt" "$WORK/consult-fable.md" "$REPO" --readonly
"$SKILL_DIR/scripts/lane.sh" kimi  "$WORK/prompt-consult.txt" "$WORK/consult-kimi.md"  "$REPO" --readonly
```

Both are asked to break the plan: wrong root cause, fix that doesn't reach the reporter's
scenario, callers it regresses, missing data repair, a test that wouldn't fail pre-fix.
Reconcile in `plan-final.md`: the plan as it will be built, plus an **objection ledger** —
every objection from either model marked *accepted* (and how the plan changed) or
*rejected* (and the evidence why). Structural objections go back to Codex for a re-plan
with the objections appended; small ones you fold in yourself.

When the models disagree with each other, or with Codex, on the root cause, don't average
them and don't pick the one that agrees with you — go back to the code or the
reproduction and settle it. If it still won't settle, stop and put both positions to the
user. A lone diagnosis that looks airtight is exactly the kind that ships a wrong fix;
two outside models with no stake in the theory are the cheapest way to catch it.

### 5. Implement → `implement.md`, `diff-1.patch` (Codex, writes)

```bash
"$SKILL_DIR/scripts/compose.sh" "$SKILL_DIR/prompts/implement-codex.md" "$WORK/prompt-implement.txt" \
  TICKET="$WORK/ticket.md" CONTEXT="$WORK/context.md" PLAN="$WORK/plan-final.md"
"$SKILL_DIR/scripts/lane.sh" codex "$WORK/prompt-implement.txt" "$WORK/implement.md" "$REPO"
```

Codex is told to stop rather than improvise if the plan turns out wrong mid-build; if it
stopped, revise the plan (back to 3 or 4) — do not patch around it. When it finishes,
capture the diff and check it yourself against `plan-final.md`:

```bash
{ git -C "$REPO" diff HEAD
  for f in $(git -C "$REPO" ls-files --others --exclude-standard); do
    printf '\n--- NEW FILE: %s ---\n' "$f"; head -c 100000 "$REPO/$f"; done
} > "$WORK/diff-1.patch"
```

Every changed hunk should trace to a line in the plan. Hunks that don't are scope creep —
ask Codex to remove them (or remove them yourself if trivial) before anything else sees
the diff. Confirm the regression test exists and passes.

### 6. Simplify → `diff-2.patch`

Invoke the `simplify` skill on the uncommitted changes (in a Codex host, run the Codex
`$simplify` skill instead). It looks for reuse, needless branches, and inefficiency
introduced by the diff, applies behaviour-preserving cleanups, and re-runs checks. Re-run
the regression test afterwards and capture `diff-2.patch` the same way as above. This is
the diff the reviewers see — cleaner code gets fewer noise findings and more real ones.

### 7. Review → `review-codex.md`, `review-fable.md`, `review-kimi.md` (all three ∥)

Each reviewer gets a different lens, so the panel walks the diff three ways instead of
three times: **Fable 5** — logic and correctness, callers, whether the test is
load-bearing; **Codex** (a fresh session, not the one that implemented) — solution fit
against the verbatim ticket, plus security of the touched code; **Kimi K3** — edge
inputs, partial failure, data already written by the bug, tenancy leaks, perf.

```bash
for lane in codex fable kimi; do
  "$SKILL_DIR/scripts/compose.sh" "$SKILL_DIR/prompts/review-$lane.md" "$WORK/prompt-review-$lane.txt" \
    TICKET="$WORK/ticket.md" PLAN="$WORK/plan-final.md" DIFF="$WORK/diff-2.patch"
done
# three Bash calls, one message, all run_in_background:
"$SKILL_DIR/scripts/lane.sh" codex "$WORK/prompt-review-codex.txt" "$WORK/review-codex.md" "$REPO" --readonly
"$SKILL_DIR/scripts/lane.sh" fable "$WORK/prompt-review-fable.txt" "$WORK/review-fable.md" "$REPO" --readonly
"$SKILL_DIR/scripts/lane.sh" kimi  "$WORK/prompt-review-kimi.txt"  "$WORK/review-kimi.md"  "$REPO" --readonly
```

A review that only announces it is about to start ("I'll review this, beginning with…")
is not a review; rerun that lane once with the same prompt before reporting it failed.
If lane.sh refuses the Kimi prompt for size, trim generated files and lockfiles out of
the diff rather than dropping the lane.

### 8. Triage & apply → `triage.md`, `confirmed.md`, `apply.md`, `diff-3.patch`

Reviewer output is input, not ground truth. Deduplicate the findings (the same bug in
three wordings is one finding; two reviewers flagging the same line is high signal), then
verify each one **against the code**: open the file, trace the scenario. Record every
finding in `triage.md` as one of:

- **confirmed** — the failing scenario is real; goes to Codex to apply
- **rejected** — with the specific reason (already handled at line X, scenario unreachable
  because Y, a style opinion rather than a defect)
- **out of scope** — real but not this ticket; goes in the report as a secondary finding

Copy only the confirmed findings — each with file:line, the failing scenario, and what
should change — into `confirmed.md`; that is all Codex sees. A reviewer's suggestion
applied unverified is how a review round *adds* a bug:

```bash
"$SKILL_DIR/scripts/compose.sh" "$SKILL_DIR/prompts/apply-codex.md" "$WORK/prompt-apply.txt" \
  FINDINGS="$WORK/confirmed.md" PLAN="$WORK/plan-final.md"
"$SKILL_DIR/scripts/lane.sh" codex "$WORK/prompt-apply.txt" "$WORK/apply.md" "$REPO"
```

(One-line fixes you can apply yourself; say so in `triage.md`.) Capture `diff-3.patch`
and re-run the regression test. If applying the findings introduced new logic rather than
tightening existing lines, run the panel once more on `diff-3.patch`; a second round
that still yields confirmed blockers is a strike — stop and report rather than looping.

### 9. Verify → `repro/after-*`, `test-proof.md`, evidence report

Prove the bug is gone with the same lens you used to see it, then prove the fix is
protected, then run the full check stack.

1. **Reproduction, again.** Re-run the exact Phase-2 reproduction against the fixed code;
   it must now pass. Save the evidence as `repro/after-*` beside the before.
2. **The regression test fails without the fix.** A test that passes either way protects
   nothing. Stash only the source changes, keep the test, run it, restore:

   ```bash
   SRC=<changed source files, not the test files>        # from the diff
   git -C "$REPO" stash push -u -- $SRC                  # -u also stashes new untracked source files
   <test command for the new test>                        # must FAIL — record the output
   git -C "$REPO" stash pop
   <test command for the new test>                        # must PASS — record the output
   ```

   Paste both results into `test-proof.md`. If it passes without the fix, the test is not
   load-bearing: fix the test, or record "no test" as an explicit decision with the reason.
3. **Gauntlet.** Invoke the `gauntlet` skill on the change set: baseline, full suite with
   zero new failures, types, lint, changed-line coverage with a real gate, real execution,
   and mutation testing if the fix touches money, auth, data integrity, or concurrency.
   Its evidence report — with pasted numbers, and skipped layers named — is the
   verification artifact; link its path from `report.md`.

Never weaken or skip a test to reach green, and never re-run only the subset that passed.

### 10. Report → `report.md`

Write `report.md` and give its path, then summarise in chat. Structure:

```
# <ticket id> — <title>
## Root cause            one paragraph, file:line, with the evidence
## What changed          files and why, one line each; link diff-3.patch
## Plan review           Fable 5 / Kimi K3 verdicts; objections accepted and rejected (counts + the important ones)
## Code review           per reviewer: verdict, confirmed / rejected / out-of-scope counts; what was applied
## Verification          before/after reproduction paths; test-proof result; gauntlet evidence path and headline numbers
## Lanes that did not run   and why (or "all lanes ran")
## Secondary findings    adjacent problems noticed, not fixed
## Next steps            what the user should double-check; offer commit / PR / ticket update — not done
```

Plain sentences a teammate could read; no severity badges, no AI scaffolding. Every
number in it comes from a file in `$WORK`, never from memory.

## Files

```
bugfix/
├── SKILL.md
├── scripts/lane.sh          headless call to codex | fable | kimi, fail-closed, --readonly guard
├── scripts/compose.sh       template + labelled sections → prompt file
├── prompts/                 one brief per phase and lane (edit these to tune a lane)
└── references/
    ├── lanes.md             CLI invocations, quirks, failure signatures, how to swap a model
    └── trackers.md          pulling a complete ticket from Jira, Asana, GitHub, or a paste
```
