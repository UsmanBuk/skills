Apply the confirmed review findings below to the working tree. Each listed finding was verified against the code by the orchestrator; findings that were rejected are not listed and must not be "fixed". Leave everything uncommitted.

Rules — the same as the implementation:
- Smallest change per finding, matching the surrounding style, nothing outside the listed findings.
- If a finding turns out to be wrong once you are in the code, do not apply it — explain why in your report.
- Re-run the regression test and the project's checks for the touched areas after applying. Never weaken a test to get green.

Final message — return exactly this structure:
## Applied
finding → change made, file:line
## Not applied
finding → reason
## Commands run
Each command and the pasted tail of its real output.
