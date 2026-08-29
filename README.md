# skills

Agent skills I've written and use across Claude Code, Codex CLI, and other
agents that follow the `skills/<name>/SKILL.md` convention.

## Install

All skills, into every agent the CLI detects:

```bash
npx skills add UsmanBuk/skills --all
```

One skill:

```bash
npx skills add UsmanBuk/skills --skill gauntlet
npx skills add UsmanBuk/skills --skill bugfix
```

Or copy a skill folder directly into your agent's skills directory
(`~/.claude/skills/`, `~/.codex/skills/`, `~/.agents/skills/`).

Install counts show up on [skills.sh/UsmanBuk/skills](https://skills.sh/UsmanBuk/skills)
— the `skills` CLI reports anonymous installs there (opt out with `DO_NOT_TRACK=1`).

## Skills

### [gauntlet](skills/gauntlet/)

Post-hoc verification of AI-written code. My workflow is: give the agent the
task, let it write freely, **then** make the change earn trust — no
spec-approval ceremony before code, no enforced TDD loop. The skill runs the
check stack (tests, types, lint, changed-line coverage, real execution;
mutation testing for high-stakes changes) against the finished diff and
produces an evidence report with pasted numbers, where a check that didn't run
never counts as a pass.

The verification-layer design is adapted from
[AmazingAng/old-coder](https://github.com/AmazingAng/old-coder) (MIT), itself
inspired by Robert C. Martin's agent-era testing strategy. old-coder gates
work behind human spec approval *before* code exists; gauntlet keeps its
gauntlet-and-evidence discipline but runs entirely after the fact.

### [bugfix](skills/bugfix/)

One ticket → one verified fix, with an independent model at each place a bug fix
usually goes wrong. Pulls the ticket (Jira, Asana, GitHub issue, or a paste) with
every comment, gathers context and **reproduces first**; Codex writes the plan;
Claude Fable 5 and Kimi K3 — fresh headless processes, not the orchestrator — try
to break the plan; Codex implements; `simplify` runs; a fresh Codex, Fable 5, and
Kimi K3 review the diff from three different lenses; only findings verified
against the code are applied; then the fix is proven with a before/after
reproduction, a regression test shown to fail on the pre-fix code, and the full
[gauntlet](skills/gauntlet/). Ends with an uncommitted diff and a report — commit,
PR, and ticket updates stay with you. `scripts/lane.sh` encodes the three CLIs'
headless quirks and fails closed (empty output, wrong model, or a "read-only" lane
that wrote to the tree all count as failures).

## Syncing to local agents

`sync.sh` copies every skill in this repo into the local skill folders for
Claude Code, Codex, and the cross-agent `~/.agents` directory:

```bash
./sync.sh
```

Edit here → sync → commit → push. The repo is the source of truth; the
dotfolders are deploy targets.

## Skills I use but didn't write

- [anthropics/skills](https://github.com/anthropics/skills) — skill-creator, frontend-design
- [AmazingAng/old-coder](https://github.com/AmazingAng/old-coder) — the spec-first original
- [obra/superpowers](https://github.com/obra/superpowers) — systematic-debugging, whose "reproduce before you fix" law bugfix leans on
- [vercel-labs/skills](https://github.com/vercel-labs/skills) — find-skills / the `npx skills` installer

## Found one useful? Something wrong?

A star tells me it landed. [Discussions](https://github.com/UsmanBuk/skills/discussions)
is the place for "this worked / this didn't / here's what I changed" — real-world runs
are what improve the prompts. Bugs and gaps go in
[Issues](https://github.com/UsmanBuk/skills/issues).

## License

MIT — see [LICENSE](LICENSE). The gauntlet skill includes material adapted
from old-coder, © AmazingAng, also MIT.
