# Gauntlet tooling by ecosystem

Prefer whatever the project already uses (check package.json / pyproject.toml /
Makefile / CI config first). These are the defaults when nothing exists.
Adapted from AmazingAng/old-coder (MIT), trimmed and adjusted.

## Python

| Layer | Tool | Command |
|---|---|---|
| Tests | pytest | `pytest -q` |
| Types | mypy | `mypy <pkg>` (or pyright) |
| Lint + format | ruff | `ruff check . && ruff format --check .` |
| Changed-line coverage | coverage.py + diff-cover | `pytest --cov=<pkg> --cov-branch --cov-report=xml`, then `diff-cover coverage.xml --compare-branch=<base> --fail-under=100` — the fail-under flag is what makes it a gate rather than a report |
| Suite health | pytest-randomly | just install it; order randomizes per run |
| Mutation | mutmut (3+) | `[tool.mutmut] source_paths = ["src/"]` in pyproject.toml, then `mutmut run` — scope to changed modules with `mutmut run "my_module*"`; survivors = weak tests |
| Property-based | hypothesis | `@given(...)` strategies for invariants |
| Dep audit | pip-audit | `pip-audit` when the dependency set changed |

## JavaScript / TypeScript

| Layer | Tool | Command |
|---|---|---|
| Tests | vitest / jest | `npx vitest run` / `npx jest` |
| Types | tsc | `npx tsc --noEmit` (or `tsc -b` for project refs) |
| Lint | eslint / oxlint | `npx eslint .` / `npx oxlint` |
| Changed-line coverage | vitest/jest coverage | `npx vitest run --coverage`; check touched files' lines, not the global % |
| Mutation | Stryker | `npx stryker run` with `mutate: [<changed files>]` — full-project runs are slow |
| Property-based | fast-check | `fc.assert(fc.property(...))` |
| Dep audit | npm audit | `npm audit` when the dependency set changed |

## Other ecosystems (quick defaults)

- **Go**: `go test ./... -race` · `go build ./...` · `go vet ./... && staticcheck ./...` · coverage via `-coverprofile` · mutation: manual · properties: `rapid`
- **Rust**: `cargo test` · `cargo check` · `cargo clippy -- -D warnings` · `cargo llvm-cov --branch` · `cargo mutants --file <changed>` · `proptest`
- **SQL**: no portable runner — use the project's framework (`dbt test`), `sqlfluff parse/lint --dialect <d>`, and validate changed statements against a disposable instance of the production engine; mutation is manual (alter predicates/joins/aggregates)
- Anything else: find the ecosystem's standard test runner, compiler/type check, and linter; mutation falls back to the manual procedure below.

## Secrets & capability checks (any ecosystem)

- Secrets: `gitleaks detect --no-git -s <changed files>` if available; otherwise grep the diff for key/token/password patterns — and treat a grep gate as a home-grown checker (fail closed, prove it can fail).
- Capability diff: read the diff asking one question — did the change start using network, subprocess, filesystem, or env access it didn't have before? An agent-added capability nobody asked for is a red flag worth a line in the report.

## Manual mutation procedure (no tool available)

Reach for the project's real mutation tool first — a tool generates mutants
from the syntax tree and cannot report a mutant it did not run. Use this only
when no tool exists for the language.

Script it rather than hand-editing, and persist the script (e.g.
`tools/mutants.py`): hold the original source, apply each mutant by unique
string replacement, run the suite, restore. The known sharp edge: a hand-rolled
runner must **prove it executed each mutant** (old-coder's own demo found two
mutants sharing a stale bytecode cache, reporting kills for code that never
ran). That defect class can only inflate the score, so it never shows up red —
guard against it (touch mtimes, clear caches) and say in the report which
check proves execution.

1. Pick the new/changed implementation code.
2. One at a time, introduce 3–5 plausible bugs, biased toward the logic that
   matters most: flip a comparison (`<` → `<=`), off-by-one a bound, delete a
   branch or early return, swap `and`/`or`, replace a return value with a
   constant.
3. Run the suite after each mutant. Every mutant must make at least one test
   fail; a survivor means a missing or vacuous assertion — flag it (add the
   killing test only if in scope).
4. Restore, verify with `git diff` that only intended changes remain, run the
   suite once more to confirm green.
5. Report as "manual mutation: N/N killed".

## Tier 3 extended menu

Picked per failure mode, not run wholesale:

| Failure mode | Check |
|---|---|
| Races / concurrency | `go test -race`, ThreadSanitizer, threading stress + rerun (py) |
| Hostile input / parsing | fuzzing, property tests with adversarial generators |
| Failed rollback / migrations | rehearse up **and** down against a disposable DB |
| Public API breakage | griffe (py) / api-extractor (ts) / cargo-semver-checks |
| Latency budget stated | pytest-benchmark / hyperfine / criterion |
| Silent production failure | assert critical paths emit logs/metrics |
| UI regressions | axe-core, Playwright screenshot diff, Lighthouse |
| Multi-version support claims | tox / nox / CI matrix — one version green is not evidence for the others |
