# skills

Agent skills I've written and use across Claude Code, Codex CLI, and other
agents that follow the `skills/<name>/SKILL.md` convention.

## Install

```bash
npx skills add https://github.com/UsmanBuk/skills
```

Or copy a skill folder directly into your agent's skills directory
(`~/.claude/skills/`, `~/.codex/skills/`, `~/.agents/skills/`).

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
- [vercel-labs/skills](https://github.com/vercel-labs/skills) — find-skills / the `npx skills` installer

## License

MIT — see [LICENSE](LICENSE). The gauntlet skill includes material adapted
from old-coder, © AmazingAng, also MIT.
