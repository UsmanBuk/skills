# Model lanes: how each CLI is called, and why

All three are called through `scripts/lane.sh`. This file explains what the script
encodes so you can debug a failed lane or swap a model. Invocation details were verified
on 2026-08-29 with codex-cli 0.151.0, Claude Code 2.1.251, kimi-code 0.33.0.

## Codex — `codex exec`

```
codex exec -C <repo> --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -o <out> - < <prompt>
```

- **Model and effort come from `~/.codex/config.toml`** (`model`, `model_reasoning_effort`).
  Leave `-m` unset so upgrading the model is a one-line config change, not a skill edit.
- **Prompt on stdin (`-`).** A prompt passed as an argv string is capped at 128 KiB on
  Linux, and a review prompt carrying a diff gets there fast. `-` tells Codex to read
  instructions from stdin.
- **`-o <file>` is the final message only.** Stdout is the full transcript (commands,
  reasoning summaries) — lane.sh sends it to `<out>.err` so it is there when something
  goes wrong but never lands in your context.
- **`--dangerously-bypass-approvals-and-sandbox`** because the implement and apply lanes
  must edit files and run tests non-interactively. Read-only lanes are protected by
  `--readonly` in lane.sh (tree fingerprint before/after) rather than by the sandbox.
  Do not use `codex review` or `--sandbox read-only` here — the former can't take a custom
  prompt alongside `--uncommitted`, and the latter has hung on hardened kernels.
- **Fresh session every call.** The review lane must not be the session that implemented.
- Typical time: 3–10 min at high effort for plan/review, longer for implement. Don't
  assume it hung: check `ps` for CPU on the `codex` process before killing it.

Failure signatures (in `<out>.err`):
- `You've hit your usage limit … try again at <date>` — quota. lane.sh prints a one-line
  warning. Stop and ask the user: wait, or fall back to the orchestrator implementing.
- Empty `<out>` with rc 0 — lane.sh converts to rc 2. Usually a prompt that ended with a
  question rather than an instruction; the model "answered" by asking.
- `not inside a trusted directory` — add the repo to `[projects]` in config.toml or run
  with `--skip-git-repo-check` (already passed).

## Claude Fable 5 — `claude -p`

```
cd <repo> && claude -p --model claude-fable-5 --output-format json --no-session-persistence < <prompt>
```

- **JSON output so the model can be verified.** lane.sh accepts the result only when
  `subtype == "success"`, `is_error == false`, and `modelUsage` names `claude-fable-5`
  (as key or `canonicalModel`). A run that quietly resolved to another model is rejected
  (rc 2). The plain-text `result` is written to `<out>`.
- **Run from the repo** so Read/Grep/Glob work — read-only tools need no permission
  flags in print mode. Bash is not granted; the brief carries the diff, so the reviewer
  doesn't need it.
- `--no-session-persistence` keeps these one-shot calls out of the user's session list.
- Override the model with `BUGFIX_CLAUDE_MODEL` (the verification adapts).
- Typical time: 1–5 min.

Failure signatures:
- Output that only announces a plan ("I'll review this patch, starting with…") is an
  incomplete turn, not a review. Rerun once with the same prompt; report if it repeats.
- `subtype: error_max_turns` / `is_error: true` — check `<out>.json` for the message.
- Auth: `claude auth status` (report state only, never tokens).

## Kimi K3 — `kimi -p`

```
cd <repo> && kimi -m kimi-code/k3 -p "$(cat <prompt>)"
```

- **`-p` is the one-shot mode and already auto-approves tools** — it refuses `-y`. The
  older `--print` / `--quiet` / `--final-message-only` flags no longer exist.
- **Prompt must be argv** (no stdin mode), so lane.sh refuses prompts over ~120 KB with
  a clear message. Trim the diff (drop generated files, lockfiles) or split the review.
- **Model alias** `kimi-code/k3` is defined in `~/.kimi-code/config.toml` (`[models]`
  table; 1M context, effort defaults to high). Override with `BUGFIX_KIMI_MODEL`.
- Output begins with short "• …" thinking lines and ends with `To resume this session:
  kimi -r <id>`; lane.sh strips the footer and any ANSI.
- Typical time: 1–5 min.

Failure signatures:
- A login URL or `kimi login` in the output — OAuth expired. It must be refreshed
  interactively (`kimi login`); lane.sh warns. Don't drop the lane silently.
- `Cannot combine --prompt with --yolo` — someone added `-y`; remove it.

## Swapping or adding a lane

- Change a model: `BUGFIX_CLAUDE_MODEL`, `BUGFIX_KIMI_MODEL`, or `~/.codex/config.toml`.
- Change a lane's brief: edit `prompts/<phase>-<lane>.md`.
- Add a reviewer: add a `run_<name>()` to lane.sh following the pattern (write `<out>`,
  send noise to `<out>.err`, return the CLI's rc), a `prompts/review-<name>.md`, and a
  row in SKILL.md Phase 7.
- Timeout: `BUGFIX_TIMEOUT` seconds (default 1800). It is a ceiling, not a target.
