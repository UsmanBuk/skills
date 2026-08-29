You are planning a bug fix. This phase is read-only: explore the repository as much as you need, but do not modify any files. Return the plan as your final message.

Work from the ticket and context below. Verify the stated root cause yourself against the code — do not take it on trust. If you find a different root cause, say so and show the evidence. Then produce:

# Plan
## Root cause
file:line, the mechanism, and the evidence that proves it (a traced code path or a reproduced failure, not a guess).
## Fix
The smallest change that addresses the root cause. Every file and the change to each. No refactors, no speculative abstractions, no drive-by cleanup, no new dependencies unless the fix is impossible without them.
## Call sites and blast radius
Every caller or consumer of what changes, and why each is safe or what it needs.
## Regression test
The test to add: what it asserts, where it lives (follow the nearest existing test's patterns and fixtures), and why it fails on the current code and passes after. If no test is possible at reasonable cost, say so and why.
## Verification
The exact commands that prove the fix: the reproduction, the tests, types and lint.
## Risks and alternatives
What could go wrong. The one alternative you rejected and why.
## Assumptions
Anything in the ticket you had to interpret.

Be concrete: file paths, function names, line numbers. If the ticket cannot honestly be fixed as described (ambiguous, needs a product decision, the bug lives elsewhere), say that at the top instead of planning around it.
